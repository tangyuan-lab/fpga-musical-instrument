`default_nettype none
// 一块官方8路低有效LED模块编码16键；频率指完整亮灭周期。
// 不将ADC原有八脚用作第二组LED。self_test=1..8逐灯核对方向，0退出。
module led8_guide #(parameter integer CLK_HZ=50_000_000)(
    input wire clk,rst_n,
    input wire [15:0] guide_keys,
    input wire [3:0] self_test,
    output reg [7:0] led_n
);
    localparam integer SLOW_HALF=CLK_HZ/4, FAST_HALF=CLK_HZ/12;
    reg [31:0] slow_count,fast_count;reg slow_on,fast_on;
    integer i;
    always @(posedge clk)begin
        if(!rst_n)begin slow_count<=0;fast_count<=0;slow_on<=1;fast_on<=1;end
        else begin
            if(slow_count>=SLOW_HALF-1)begin slow_count<=0;slow_on<=!slow_on;end
            else slow_count<=slow_count+1'b1;
            if(fast_count>=FAST_HALF-1)begin fast_count<=0;fast_on<=!fast_on;end
            else fast_count<=fast_count+1'b1;
        end
    end
    always @*begin
        led_n=8'hff;
        for(i=0;i<8;i=i+1)begin
            if(self_test!=0)led_n[i]=self_test!=i+1;
            else case({guide_keys[i+8],guide_keys[i]})
                2'b01:led_n[i]=0;
                2'b10:led_n[i]=!slow_on;
                2'b11:led_n[i]=!fast_on;
                default:led_n[i]=1;
            endcase
        end
    end
endmodule
`default_nettype wire
