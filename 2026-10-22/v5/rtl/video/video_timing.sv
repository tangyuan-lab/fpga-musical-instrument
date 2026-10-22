`default_nettype none
// 1024x600：水平 1024+160+20+140=1344，垂直 600+12+3+20=635。
// 像素时钟 51.25 MHz，对应约 60.06 Hz；同步信号低有效。
module video_timing(input wire clk,rst_n,
    output reg [10:0] x,output reg [9:0] y,
    output wire de,hs_n,vs_n,frame_start
);
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin x<=0; y<=0; end
        else if(x==1343) begin x<=0; y<=(y==634)?10'd0:y+1'b1; end
        else x<=x+1'b1;
    end
    assign de=(x<1024 && y<600);
    assign hs_n=!(x>=1184 && x<1204);
    assign vs_n=!(y>=612 && y<615);
    assign frame_start=(x==0 && y==0);
endmodule
`default_nettype wire
