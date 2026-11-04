`default_nettype none
// 双延时线合唱：三角波 LFO 调制读地址，干湿混合；两条线相位相反，声音更宽。
module audio_chorus #(parameter SEPARATE_SEND=0)(
    input wire clk,rst_n,sample_tick,clear,
    input wire signed [15:0] dry,
    input wire signed [15:0] send_in,
    input wire [7:0] mix,depth,rate,
    output reg signed [15:0] out,
    output reg clipped,valid,
    output reg signed [15:0] wet_component
);
    reg signed [15:0] ram0[0:1023];
    reg signed [15:0] ram1[0:1023];
    reg [9:0] wp;
    reg [23:0] ph0,ph1;
    reg [1:0] state;
    reg signed [15:0] tap0,tap1,hold;
    reg signed [15:0] send_hold;
    reg [9:0] addr0,addr1;
    reg [10:0] valid_samples;
    reg [7:0] frame_mix;
    reg tap_valid0,tap_valid1;
    wire [14:0] tria=ph0[23]?~ph0[22:8]:ph0[22:8];
    wire [14:0] trib=ph1[23]?~ph1[22:8]:ph1[22:8];
    wire [15:0] mod0=tria[14:7]*depth;wire [15:0] mod1=trib[14:7]*depth;
    // 255×255/128最大508，需要9位；截成8位会在深度>128时回绕并跳读。
    // 延迟392..900采样，完整落在1024采样环形缓冲内。
    wire [8:0] off0=mod0[15:7];wire [8:0] off1=mod1[15:7];
    wire [9:0] delay0=10'd900-{1'b0,off0};
    wire [9:0] delay1=10'd900-{1'b0,off1};
    // 两个16位采样先符号扩展；混合量转换为正的9位有符号数。
    // 17x9乘积用26位保存，算术右移8位保持负半波。
    wire signed [16:0] tap_sum=$signed({tap0[15],tap0})+$signed({tap1[15],tap1});
    wire signed [25:0] wet_product=tap_sum*$signed({1'b0,frame_mix});
    wire signed [31:0] wet_scaled=$signed({{6{wet_product[25]}},wet_product})>>>8;
    wire signed [31:0] mixed={{16{hold[15]}},hold}+wet_scaled;
    function automatic signed [15:0] clamp16(input signed [31:0] v);
        clamp16=v>32767?16'sd32767:v<(-32768)?16'sh8000:v[15:0];
    endfunction
    always @(posedge clk) begin
        valid<=0;clipped<=0;
        if(!rst_n||clear)begin
            wp<=0;ph0<=0;ph1<=24'h800000;state<=0;out<=0;tap0<=0;tap1<=0;hold<=0;addr0<=0;addr1<=0;
            valid_samples<=0;frame_mix<=0;tap_valid0<=0;tap_valid1<=0;
            send_hold<=0;clipped<=0;valid<=0;wet_component<=0;
        end else case(state)
            0:if(sample_tick)begin
                hold<=dry;
                send_hold<=SEPARATE_SEND?send_in:dry;
                frame_mix<=mix;
                tap_valid0<=valid_samples>={1'b0,delay0};
                tap_valid1<=valid_samples>={1'b0,delay1};
                ph0<=ph0+{16'd0,rate}+24'd400;
                ph1<=ph1+{16'd0,rate}+24'd400;
                addr0<=wp-10'd900+{1'd0,off0};
                addr1<=wp-10'd900+{1'd0,off1};
                state<=1;
            end
            1:begin
                tap0<=tap_valid0 ? ram0[addr0]:16'sd0;
                tap1<=tap_valid1 ? ram1[addr1]:16'sd0;state<=2;
            end
            2:begin
                ram0[wp]<=send_hold;ram1[wp]<=send_hold;
                out<=frame_mix==0 ? hold:clamp16(mixed);
                wet_component<=frame_mix==0 ? 16'sd0:clamp16(wet_scaled);
                valid<=1;clipped<=frame_mix!=0&&(mixed>32767||mixed< -32768);
                if(valid_samples<1024)valid_samples<=valid_samples+1'b1;
                wp<=wp+1'b1;state<=0;
            end
            default:state<=0;
        endcase
    end
endmodule
`default_nettype wire
