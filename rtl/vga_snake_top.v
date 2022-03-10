module vga_snake_top(
	 input           sys_clk,				   //系统时钟
	 input           sys_rst_n,				//系统复位信号
	 //按键输入
	 input           key_up,
	 input           key_down,
	 input           key_left,
	 input           key_right,
	 //红外输入
	 input           remote_in,
	 //vga接口
	 output          vga_hs,				   //行同步信号
	 output          vga_vs,				   //场同步信号
	 output  [15:0]  vga_rgb,					//红绿蓝三原色输入
	 //数码管接口
	 output  [ 5:0]  seg_sel,        // 数码管位选，最左侧数码管为最高位
     output  [ 7:0]  seg_led,         // 数码管段选 
    //嗡鸣器
     output          beep_en	
	);

wire         vga_clk_w;                   //PLL分频得到25Mhz时钟
wire         locked_w;                    //PLL输出稳定信号
wire         rst_n_w;                     //内部复位信号
wire [15:0]  pixel_data_w;                //像素点数据
wire [ 9:0]  pixel_xpos_w;                //像素点横坐标
wire [ 9:0]  pixel_ypos_w;                //像素点纵坐标    
 
wire        repeat_en;                   //重复码有效信号
wire        data_en;                     //数据有效信号
wire [7:0]  data;                        //红外控制码 

wire [19:0] score;
wire        en;
wire        sign;
wire [5:0]  point;

wire        key_l;
wire        key_r;
wire        key_u;
wire        key_d;

wire        ky_right;
wire        ky_left;
wire        ky_up;
wire        ky_down;

wire        beep_clk;
//*****************************************************
//**                    main code
//***************************************************** 

//待PLL输出稳定之后，停止复位
assign rst_n_w = sys_rst_n && locked_w;
   
vga_pll	u_vga_pll(                      //时钟分频模块
	.inclk0         (sys_clk),    
	.areset         (~sys_rst_n),
    
	.c0             (vga_clk_w),          //VGA时钟 25M
	.locked         (locked_w)
	); 

vga_driver u_vga_driver(
    .vga_clk        (vga_clk_w),    
    .sys_rst_n      (rst_n_w),    

    .vga_hs         (vga_hs),       
    .vga_vs         (vga_vs),       
    .vga_rgb        (vga_rgb),      
    
    .pixel_data     (pixel_data_w), 
    .pixel_xpos     (pixel_xpos_w), 
    .pixel_ypos     (pixel_ypos_w)
    ); 
    
vga_display u_vga_display(
    .vga_clk        (vga_clk_w),
    .sys_rst_n      (rst_n_w),
	 
    .key_down       (key_d),
	.kf_down        (kf_down),
	.key_up         (key_u),
	.kf_up          (kf_up),
	.key_left       (key_l),
	.kf_left        (kf_left),
	.key_right      (key_r),
	.kf_right       (kf_right),
	 
	.con_flag       (data),
	
	.score          (score),
	.point          (point),
	.en             (en),
	.sign           (sign),
	
	.beep_clk       (beep_clk),
	
    .pixel_xpos     (pixel_xpos_w),
    .pixel_ypos     (pixel_ypos_w),
    .pixel_data     (pixel_data_w)
    );

remote_rcv u_remote_rcv(
    .sys_clk         (sys_clk),
	.sys_rst_n       (sys_rst_n),
	 
	.remote_in       (remote_in),
	.repeat_en       (repeat_en),
	.data_en         (data_en),
	.data            (data)
    );	 

seg_led u_seg_led(
    .clk         (sys_clk),
	.rst_n       (sys_rst_n),
	
	.data            (score),
	.en              (en),
	.point           (point),
	.sign            (sign),
	
	.seg_led         (seg_led),
	.seg_sel         (seg_sel)
    );

beep u_beep(
    .sys_clk         (vga_clk_w),
	.sys_rst_n       (sys_rst_n),
	
	.enb             (beep_clk),
	.beep_en         (beep_en)
	);
	
key_debounce u_left(
    .sys_clk         (vga_clk_w),
	.sys_rst_n       (sys_rst_n),
	
	.key             (key_left),
	.key_value       (key_l),
	.key_flag        (kf_left)
);

key_debounce u_right(
    .sys_clk         (vga_clk_w),
	.sys_rst_n       (sys_rst_n),
	
	.key             (key_right),
	.key_value       (key_r),
	.key_flag        (kf_right)
);	

key_debounce u_up(
    .sys_clk         (vga_clk_w),
	.sys_rst_n       (sys_rst_n),
	
	.key             (key_up),
	.key_value       (key_u),
	.key_flag        (kf_up)
);

key_debounce u_down(
    .sys_clk         (vga_clk_w),
	.sys_rst_n       (sys_rst_n),
	
	.key             (key_down),
	.key_value       (key_d),
	.key_flag        (kf_down)
);

endmodule 