`default_nettype none
// 将屏幕短命令及分字节参数转为op/value/aux；只驱动命令队列的一个写口。
// clear与急停同沿清暂存，返回数据不会被后续部分参数覆盖。
module screen_command_adapter(input wire clk,rst_n,clear,valid,
    input wire [7:0] op,value,output wire request_valid,output wire [72:0] request);
    reg [31:0] staged_value,staged_aux;
    assign request_valid=valid&&(op<8'h40||(op>=8'h40&&op<=8'h62)||op>=8'h80);
    assign request=op>=8'hc0 ? {1'b0,8'(op-8'hc0),staged_aux,staged_value}:
        op>=8'h80 ? {1'b0,8'(op-8'h80),32'd0,24'd0,value}:
        op<8'h40 ? {1'b1,op,32'd0,24'd0,value}:{1'b0,8'(op-8'h40),staged_aux,staged_value};
    always @(posedge clk)begin
        if(!rst_n||clear)begin staged_value<=0;staged_aux<=0;end
        else begin
            if(valid&&op>=8'h70&&op<=8'h73)staged_value[(op-8'h70)*8+:8]<=value;
            if(valid&&op>=8'h74&&op<=8'h77)staged_aux[(op-8'h74)*8+:8]<=value;
        end
    end
endmodule
`default_nettype wire
