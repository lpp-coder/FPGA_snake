module beep(
    input      sys_clk,
	input      sys_rst_n,
	
    input      enb,                                    //嗡鸣器倒计时使能
    output reg beep_en                                 //嗡鸣器使能
    );

reg [31:0] delay_cnt;

always @(posedge sys_clk or negedge sys_rst_n) begin 
    if (!sys_rst_n) begin 
        delay_cnt <= 32'd0;
    end
    else begin
        if(enb)                                        //一旦倒计时使能
            delay_cnt <= 32'd100000000;                  //给延时计数器重新装载初始值（计数时间为1s）
        else  begin                                   //在按键状态稳定时，计数器递减，开始1ms倒计时
                 if(delay_cnt > 32'd0)
                     delay_cnt <= delay_cnt - 1'b1;
                 else
                     delay_cnt <= delay_cnt;
        end				 
    end   
end

always @(posedge sys_clk or negedge sys_rst_n) begin 
    if (!sys_rst_n) begin 
        beep_en <= 1'b0;          
    end
    else begin
	    if(enb)
		    beep_en <= 1'b1;
		else
        if(delay_cnt == 32'd1) begin   //当计数器递减到1时，说明状态维持了1s
            beep_en <= 1'b0;          
        end
        else begin
            beep_en <= beep_en; 
        end  
    end   
end

endmodule 
