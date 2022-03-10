module vga_display(
    input                vga_clk,               //VGA驱动时钟
    input                sys_rst_n,             //复位信号
	 //按键输入
	input                 key_up,
	input                 kf_up,
	input                 key_down,
	input                 kf_down,
	input                 key_left,
	input                 kf_left,
	input                 key_right,
	input                 kf_right,
	//红外输入
	input      [ 7:0]     con_flag,             //红外控制信号
    //坐标输入
    input      [ 9:0]     pixel_xpos,           //像素点横坐标
    input      [ 9:0]     pixel_ypos,           //像素点纵坐标
    //数码信号输入
	output     reg        en,                   //数码管使能
	output     reg [ 5:0] point,                //小数点
	output     reg        sign,                 //数值正负
    output     reg [19:0] score,                //得分	
	//嗡鸣器输出
	output     reg        beep_clk,             // 嗡鸣器开始倒计时  
    //像素点输出	 
    output     reg [15:0] pixel_data            //像素点数据	
    );
//parameter define    
parameter  H_DISP      = 10'd640;                //分辨率——行
parameter  V_DISP      = 10'd480;                //分辨率——列
//snake_state
parameter  STATE_LEFT  = 3'b000;                 //蛇头向左运动的状态
parameter  STATE_RIGHT = 3'b001;                 //
parameter  STATE_DOWN  = 3'b010;                 //
parameter  STATE_UP    = 3'b011;                 //
parameter  STATE_DIE   = 3'b100;                 //
parameter  STATE_START = 3'b101;
//con_flag code 
parameter  TURN_LEFT   = 8'h44;
parameter  TURN_RIGHT  = 8'h43;
parameter  TURN_UP     = 8'h46;
parameter  TURN_DOWN   = 8'h15;

parameter  MAX_LEN     = 6;                       //蛇的最大长度

localparam SIDE_W      = 10'd20;                  //边框宽度
localparam BLOCK_W     = 10'd20;                  //方块宽度
localparam BLUE        = 16'b00000_000000_11111;  //边框颜色 蓝色
localparam WHITE       = 16'b11111_111111_11111;  //背景颜色 白色
localparam BLACK       = 16'b00000_000000_00000;  //方块颜色 黑色

//reg define
reg [ 2:0] cur_state;
reg [ 2:0] next_state;

reg [ 9:0] block_x[MAX_LEN-1:0];                   //蛇所有节点的x坐标，block_x[0]为蛇头x坐标
reg [ 9:0] block_y[MAX_LEN-1:0];                   //蛇所有节点的y坐标，block_y[0]为蛇头y坐标
reg [ 9:0] food_x;                                 //食物的x坐标
reg [ 9:0] food_y;                                 //食物的y坐标
reg [ 9:0] temp_food_x;                            //临时食物x坐标
reg [ 9:0] temp_food_y;                            //临时食物y坐标

reg [32:0] div_cnt;                                //时钟分频计数器
reg [ 9:0] cur_len;                                //蛇的当前长度

reg        hit_w;                                  //撞墙信号
reg        hit_self;                               //撞自己信号
reg        eated;                                  //吃到食物信号
reg        eated_f;
reg        eated_s;
reg        die;                                    //死亡信号
integer i;                                         //循环计数值

//wire define   
wire move_en;                                      //蛇移动使能信号，频率为100hz
wire pos_eated;
//*****************************************************
//**                    main code
//*****************************************************

//10ms产生一个脉冲信号,确定蛇的移动速度
assign move_en = (div_cnt == 22'd800000000 - 1'b1) ? 1'b1 : 1'b0;
assign pos_eated = (~eated_s) & eated_f;
//通过对vga驱动时钟计数，实现时钟分频
always @(posedge vga_clk or negedge sys_rst_n) begin         
    if (!sys_rst_n)
        div_cnt <= 22'd0;
    else begin
        if(div_cnt < 22'd800000000 - 1'b1) 
            div_cnt <= div_cnt + 1'b1;
        else
            div_cnt <= 22'd0;                     //计数达ms后清零
    end
end

//根据按键输入，改变移动方向
//状态机
always @ (posedge vga_clk or negedge sys_rst_n) begin
    if(!sys_rst_n)
        cur_state <= STATE_START;
    else
        cur_state <= next_state ;
end

always @(*) begin
    case(cur_state)
	      //next_state = STATE_RIGHT;
		    STATE_START : begin
			    if((key_right == 1'b0 ) || con_flag == TURN_RIGHT)                        //按下右键，水平向右
                    next_state = STATE_RIGHT ;               
                else if((key_left == 1'b0 ) || con_flag == TURN_LEFT)                    //按下左键，水平向左                                               
                    next_state = STATE_LEFT; 
			    else if((key_up == 1'b0 ) || con_flag == TURN_UP)                      //按下右键，水平向右
                    next_state = STATE_UP ;               
                else if((key_down == 1'b0 ) || con_flag == TURN_DOWN)                    //按下左键，水平向左                                               
                    next_state = STATE_DOWN;
			    else 
		            next_state = STATE_START;		
			end
			STATE_LEFT : begin
			    if(hit_w || hit_self)
				     next_state = STATE_DIE;
				else if(key_up == 1'b0 || con_flag == TURN_UP)         //按下up键，进入向上的状态，水平向上
                     next_state = STATE_UP ;               
                else if(key_down == 1'b0 || con_flag == TURN_DOWN)       //按下down键，进入向下的状态，水平向下                                               
                     next_state = STATE_DOWN;               
                else 
				     next_state = STATE_LEFT;
			end
		    STATE_RIGHT : begin
			    if(hit_w || hit_self)
				    next_state = STATE_DIE;
			    else if(key_up == 1'b0 || con_flag == TURN_UP)         //按下up键，水平向右
                    next_state = STATE_UP ;               
                else if(key_down == 1'b0 || con_flag == TURN_DOWN)       //按下down键，水平向左                                               
                    next_state = STATE_DOWN;               
                else 
				    next_state = STATE_RIGHT;
			end
		    STATE_DOWN : begin
			    if(hit_w || hit_self)
				    next_state = STATE_DIE;
				else if(key_right == 1'b0 || con_flag == TURN_RIGHT)      //按下右键，水平向右
                    next_state = STATE_RIGHT ;               
                else if(key_left == 1'b0 || con_flag == TURN_LEFT)       //按下左键，水平向左                                               
                    next_state = STATE_LEFT;               
                else 
				    next_state = STATE_DOWN;
				
		    end
	        STATE_UP : begin
			    if(hit_w || hit_self)
				    next_state = STATE_DIE;
				else if(key_right == 1'b0 || con_flag == TURN_RIGHT)      //按下右键，水平向右
                    next_state = STATE_RIGHT ;               
                else if(key_left == 1'b0 || con_flag == TURN_LEFT)       //按下左键，水平向左                                               
                    next_state = STATE_LEFT;               
                else 
				    next_state = STATE_UP;
	        end
			STATE_DIE : begin
			if(key_right == 1'b0 || con_flag == TURN_RIGHT)                        //按下右键，水平向右
                 next_state = STATE_START;            
            else if(key_left == 1'b0 || con_flag == TURN_LEFT)                    //按下左键，水平向左                                               
                 next_state = STATE_START;
			else if(key_up == 1'b0 || con_flag == TURN_UP)                      //按下右键，水平向右
                 next_state = STATE_START;              
            else if(key_down == 1'b0)                    //按下左键，水平向左                                               
                 next_state = STATE_START;
			else
	             next_state = STATE_DIE;		
			end
			
            default : begin
		        next_state = STATE_START;
            end		  
	 endcase 		
end 

//根据蛇头状态，改变其纵横坐标
always @(posedge vga_clk or negedge sys_rst_n) begin
    if(!sys_rst_n)begin
	     block_x[0] <= 22'd100;                     //蛇初始位置横坐标
         block_y[0] <= 22'd100;                     //蛇块初始位置纵坐标
		 die        <= 0;                           //死亡信号
	end
	else begin
	    if(move_en) begin
			case(cur_state)
				STATE_RIGHT : begin
				    die        <=  1'b0; 
					block_x[0] <= block_x[0] + 9'd20;
				end
				STATE_LEFT : begin
			        die        <=  1'b0; 	
					block_x[0] <= block_x[0] - 9'd20;	 			 
				end
				STATE_UP : begin
					die        <=  1'b0; 	
				    block_y[0] <= block_y[0] - 9'd20;		
				end
			    STATE_DOWN : begin
					 die        <=  1'b0;                       //发出死亡信号
					 block_y[0] <= block_y[0] + 9'd20;
				end
				STATE_DIE : begin
						 block_x[0] <= 22'd100;                     //蛇初始位置横坐标
						 block_y[0] <= 22'd100;                     //蛇块初始位置纵坐标
						 die        <=  1'b1;                       //发出死亡信号 
				end
				default : begin
					block_x[0] <= block_x[0];  
					block_y[0] <= block_y[0];					
				end 				
			endcase
			  //当运动信号使能时，依次更改每一个节点坐标，移动的本质就是重复上一个节点的动作，总的来说就是重复蛇头的动作  
			for(i = 0;i < MAX_LEN - 1;i = i + 1) begin 
					  block_x[i+1] <= block_x[i];  
					  block_y[i+1] <= block_y[i];	
			end			  
		 end
	     else begin 
	         block_x[0] <= block_x[0];  
			 block_y[0] <= block_y[0];	
		 end  
	 end
end 

//打印蛇，给不同的区域绘制不同的颜色
always @(posedge vga_clk or negedge sys_rst_n) begin         
    if (!sys_rst_n) 
        pixel_data <= BLACK;
    else begin
        if((pixel_xpos < SIDE_W) || (pixel_xpos >= H_DISP - SIDE_W)
          || (pixel_ypos < SIDE_W) || (pixel_ypos >= V_DISP - SIDE_W))
            pixel_data <= BLUE;                      //绘制边框为蓝色	
		else if((pixel_xpos >= food_x) && (pixel_xpos < food_x + BLOCK_W)
			     && (pixel_ypos >= food_y) && (pixel_ypos < food_y + BLOCK_W))
		         pixel_data <= BLACK;                //绘制食物方块为黑色
        else if(cur_len == 1) begin                    //绘制一节的蛇
		     if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W)
			     && (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W))
			     pixel_data <= BLACK;                //绘制方块为黑色
		     else
                 pixel_data <= WHITE;                //绘制背景为白色
        end
		else if(cur_len == 2) begin                    //绘制两节的蛇
		      if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W)
			       && (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W))
			       pixel_data <= BLACK;              //绘制方块为黑色
		      else
		      if((pixel_xpos >= block_x[1]) && (pixel_xpos < block_x[1] + BLOCK_W)
			       && (pixel_ypos >= block_y[1]) && (pixel_ypos < block_y[1] + BLOCK_W))
			       pixel_data <= BLACK;              //绘制方块为黑色
		      else
				    pixel_data <= WHITE;             //绘制背景为白色 
		end
		else if(cur_len == 3) begin                    //绘制三节蛇
		    if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W)
			    && (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W))
			    pixel_data <= BLACK;                //绘制方块为黑色
		    else
		    if((pixel_xpos >= block_x[1]) && (pixel_xpos < block_x[1] + BLOCK_W)
			    && (pixel_ypos >= block_y[1]) && (pixel_ypos < block_y[1] + BLOCK_W))
			    pixel_data <= BLACK;                //绘制方块为黑色
		    else
		    if((pixel_xpos >= block_x[2]) && (pixel_xpos < block_x[2] + BLOCK_W)
			    && (pixel_ypos >= block_y[2]) && (pixel_ypos < block_y[2] + BLOCK_W))
			    pixel_data <= BLACK;                //绘制方块为黑色 
			else
		        pixel_data <= WHITE;                //绘制背景为白色 
	    end
        else if(cur_len == 4) begin	                                //绘制最上的4节蛇
		    if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W)
			    && (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W))
			    pixel_data <= BLACK;                //绘制方块为黑色
		    else
		    if((pixel_xpos >= block_x[1]) && (pixel_xpos < block_x[1] + BLOCK_W)
			    && (pixel_ypos >= block_y[1]) && (pixel_ypos < block_y[1] + BLOCK_W))
			    pixel_data <= BLACK;                //绘制方块为黑色
		    else
		    if((pixel_xpos >= block_x[2]) && (pixel_xpos < block_x[2] + BLOCK_W)
			    && (pixel_ypos >= block_y[2]) && (pixel_ypos < block_y[2] + BLOCK_W))
			    pixel_data <= BLACK;                //绘制方块为黑色
		    else 
		    if((pixel_xpos >= block_x[3]) && (pixel_xpos < block_x[3] + BLOCK_W)
			    && (pixel_ypos >= block_y[3]) && (pixel_ypos < block_y[3] + BLOCK_W))
			    pixel_data <= BLACK;                //绘制方块为黑色
		    else
		        pixel_data <= WHITE;                //绘制背景为白色 
	    end
	    else if(cur_len == 5) begin
		    if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W)
			    && (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W))
			    pixel_data <= BLACK;                //绘制方块为黑色
		    else
		    if((pixel_xpos >= block_x[1]) && (pixel_xpos < block_x[1] + BLOCK_W)
			    && (pixel_ypos >= block_y[1]) && (pixel_ypos < block_y[1] + BLOCK_W))
			    pixel_data <= BLACK;                //绘制方块为黑色
		    else
		    if((pixel_xpos >= block_x[2]) && (pixel_xpos < block_x[2] + BLOCK_W)
			    && (pixel_ypos >= block_y[2]) && (pixel_ypos < block_y[2] + BLOCK_W))
			    pixel_data <= BLACK;                //绘制方块为黑色
		    else 
		    if((pixel_xpos >= block_x[3]) && (pixel_xpos < block_x[3] + BLOCK_W)
			    && (pixel_ypos >= block_y[3]) && (pixel_ypos < block_y[3] + BLOCK_W))
			    pixel_data <= BLACK;                //绘制方块为黑色
			else
			if((pixel_xpos >= block_x[4]) && (pixel_xpos < block_x[4] + BLOCK_W)
			    && (pixel_ypos >= block_y[4]) && (pixel_ypos < block_y[4] + BLOCK_W))
				pixel_data <= BLACK;                //绘制方块为黑色
		    else
		        pixel_data <= WHITE;                //绘制背景为白色 
	    end	
		else begin
		    if((pixel_xpos >= block_x[0]) && (pixel_xpos < block_x[0] + BLOCK_W)
			    && (pixel_ypos >= block_y[0]) && (pixel_ypos < block_y[0] + BLOCK_W))
			    pixel_data <= BLACK;                //绘制方块为黑色
		    else
		    if((pixel_xpos >= block_x[1]) && (pixel_xpos < block_x[1] + BLOCK_W)
			    && (pixel_ypos >= block_y[1]) && (pixel_ypos < block_y[1] + BLOCK_W))
			    pixel_data <= BLACK;                //绘制方块为黑色
		    else
		    if((pixel_xpos >= block_x[2]) && (pixel_xpos < block_x[2] + BLOCK_W)
			    && (pixel_ypos >= block_y[2]) && (pixel_ypos < block_y[2] + BLOCK_W))
			    pixel_data <= BLACK;                //绘制方块为黑色
		    else 
		    if((pixel_xpos >= block_x[3]) && (pixel_xpos < block_x[3] + BLOCK_W)
			    && (pixel_ypos >= block_y[3]) && (pixel_ypos < block_y[3] + BLOCK_W))
			    pixel_data <= BLACK;                //绘制方块为黑色
			else
			if((pixel_xpos >= block_x[4]) && (pixel_xpos < block_x[4] + BLOCK_W)
			    && (pixel_ypos >= block_y[4]) && (pixel_ypos < block_y[4] + BLOCK_W))
				pixel_data <= BLACK;                //绘制方块为黑色
			else
			if((pixel_xpos >= block_x[5]) && (pixel_xpos < block_x[5] + BLOCK_W)
			    && (pixel_ypos >= block_y[5]) && (pixel_ypos < block_y[5] + BLOCK_W))
				pixel_data <= BLACK;                //绘制方块为黑色
		    else
		        pixel_data <= WHITE;                //绘制背景为白色 
		end
    end
end

//判断蛇是否撞墙
always @(posedge vga_clk or negedge sys_rst_n) begin         
    if (!sys_rst_n) begin
        hit_w <= 0;                                 //撞墙信号初始化    
    end
    else begin
        if(block_x[0] < SIDE_W - 1'b1)              //撞到左边界时
            hit_w <= 1'b1;               
        else                                        //撞到右边界时
        if(block_x[0] > H_DISP - SIDE_W - BLOCK_W)
            hit_w <= 1'b1;               
        else    
        if(block_y[0] < SIDE_W - 1'b1)             //撞到上边界时
            hit_w <= 1'b1;                
        else                                    
        if(block_y[0] > V_DISP - SIDE_W - BLOCK_W) //撞到下边界时
            hit_w <= 1'b1;               
        else
            hit_w <= 1'b0;
    end
end

//判断蛇是否撞到自己
always @(posedge vga_clk or negedge sys_rst_n) begin         
    if (!sys_rst_n) begin
        hit_self <= 0;                            //撞自己信号初始化    
    end
    else begin
        if(block_x[0]==block_x[1] && block_y[0] == block_y[1])
		    hit_self <= 1'b1;
		else
		if(block_x[0]==block_x[2] && block_y[0] == block_y[2])
		    hit_self <= 1'b1;
		else
		if(block_x[0]==block_x[3] && block_y[0] == block_y[3])
		    hit_self <= 1'b1;
		else
		    hit_self <= 0;	
    end
end

//随机生成食物坐标
//生成食物x坐标
always @(posedge vga_clk or negedge sys_rst_n) begin 
    if(!sys_rst_n) begin
	    food_x <= 200;
	end
	else begin
	    if(eated) begin
		    food_x <= temp_food_x;
		end
		else if(temp_food_x > 560)
		    temp_food_x <= 200;
		else if(temp_food_x < 200)
		    temp_food_x <= 580;
		else 
		    temp_food_x <= temp_food_x + 9'd20;
	end 
end 

//生成了食物y坐标
always @(posedge vga_clk or negedge sys_rst_n) begin 
    if(!sys_rst_n) begin
		food_y <= 200;
	end
	else begin
	    if(eated) begin
			food_y <= temp_food_y;
		end
		else if(temp_food_y > 400)
		    temp_food_y <= 160;
		else if(temp_food_y < 160)
		    temp_food_y <= 400;
		else 
			temp_food_y <= temp_food_y + 9'd20;
	end 
end

//对输入的eated信号延时打拍
always @(posedge vga_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
        eated_f <= 1'b0;
        eated_s <= 1'b0;
    end
    else begin
        eated_f <= eated;
        eated_s <= eated_f;
    end
end 

//判断是否吃到食物
always @(posedge vga_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
	    eated <= 0;
	end
    else 
    if(block_x[0]==food_x && block_y[0]==food_y) begin
		eated <= 1'b1;
	end 
	else
		eated <= 1'b0;		
end

//吃到食物就得分
always @(posedge vga_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
	    score <= 0;
		en    <= 0;
		point <= 6'b000000;
		sign  <= 0;		
	end
    else begin
		en    <= 1;
		point <= 6'b000000;
		sign  <= 0;	
		if(pos_eated)
			score <= score + 9'd20;
		else
		if(die) begin
			score <= 1'b0;
		end
		else
		    score <= score;
	end
end

//蛇的长度
always @(posedge vga_clk or negedge sys_rst_n) begin
    if(!sys_rst_n) begin
	    cur_len  <= 1'b1;
		beep_clk <= 1'b0;
	end
	else begin
		if(pos_eated) begin
			cur_len  <= cur_len + 1'b1;
		    beep_clk <= 1'b1;
		end
		else
		if(die) begin
			cur_len  <= 1'b1;
			beep_clk <= 1'b1;
		end
		else
		    cur_len  <= cur_len;
			beep_clk <= 1'b0;
	end
end

endmodule 