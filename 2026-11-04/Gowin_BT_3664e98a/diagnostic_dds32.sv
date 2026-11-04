`default_nettype none
// 诊断专用32个独立相位，固定32槽流水线，非预录音频。与新钢琴32复音测试分开统计。
// 48kHz下四音为375/750/1500/3000Hz；32DDS为187.5Hz的1..32倍。
module diagnostic_dds32(
    input wire clk,rst_n,sample_tick,clear,
    input wire [2:0] kind,input wire [5:0] solo,
    output reg signed [15:0] left,right,
    output reg [31:0] active,
    output reg deadline_error
);
    reg [31:0] phase[0:31];reg signed [15:0] sine[0:1023];
    initial $readmemh("diagnostic_sine.mem",sine);
    reg [5:0] slot;reg busy;reg [1:0] state;
    reg [31:0] step;reg [4:0] idx;reg [9:0] address;
    reg signed [15:0] sine_l,sine_r;reg signed [23:0] accum_l,accum_r;
    reg [31:0] working_active;
    wire enabled=kind==1||kind==5||kind==6;
    wire voice_on=(kind==6 || (kind==1 && slot<4) || (kind==5 && slot==0)) && (solo==0 || solo==slot+1);
    integer i;
    always @(posedge clk)begin
        if(!rst_n||clear)begin
            for(i=0;i<32;i=i+1)phase[i]<=0;
            left<=0;right<=0;active<=0;working_active<=0;slot<=0;busy<=0;state<=0;accum_l<=0;accum_r<=0;deadline_error<=0;
            idx<=0;address<=0;step<=0;sine_l<=0;sine_r<=0;
        end else begin
            if(sample_tick)begin
                if(busy)deadline_error<=1;
                if(!busy)begin busy<=enabled;slot<=0;state<=0;accum_l<=0;accum_r<=0;working_active<=0;
                    if(!enabled)begin left<=0;right<=0;active<=0;end
                end
            end
            if(busy)case(state)
                0:begin
                    idx<=slot[4:0];address<=phase[slot[4:0]][31:22];
                    step<=kind==1 ? (32'h02000000<<slot[1:0]):kind==5 ? 32'h02000000:(({26'd0,slot}+1)<<24);
                    working_active[slot[4:0]]<=voice_on;state<=1;
                end
                1:begin
                    phase[idx]<=phase[idx]+step;
                    sine_l<=working_active[idx] ? sine[address]:16'sd0;
                    sine_r<=working_active[idx] ? sine[kind==5 ? (address+10'd256):address]:16'sd0;
                    state<=2;
                end
                2:begin accum_l<=accum_l+$signed(sine_l);accum_r<=accum_r+$signed(sine_r);state<=3;end
                3:if(slot==31)begin
                    // 4音/相位测试-12dB，32音-36dB；避免峰值相加造成16位溢出。
                    left<=accum_l >>> (kind==6 ? 6:2);right<=accum_r >>> (kind==6 ? 6:2);active<=working_active;busy<=0;
                end else begin slot<=slot+1'b1;state<=0;end
            endcase
        end
    end
endmodule
`default_nettype wire
