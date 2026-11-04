`default_nettype none
// Same-sample peak control before 16-bit saturation, no look-ahead RAM.
// Serial divide and shared multiply fit comfortably inside one 48 kHz period.
// Gain drops immediately to the safe ratio, recovers linearly in Q15 steps.
module pcm_peak_limiter(
    input wire clk,rst_n,clear,valid_in,enabled,
    input wire signed [18:0] sample_in,
    input wire [1:0] release_preset,
    output reg signed [15:0] sample_out,
    output reg valid_out,clipped,limited,
    output reg [15:0] gain_q15,
    output reg [18:0] peak_in,peak_out
);
    localparam [18:0] CEILING=19'd30000;
    reg [2:0] state;reg [4:0] count;
    reg signed [18:0] held;
    reg [18:0] denominator;
    reg [29:0] numerator,quotient;
    reg [19:0] remainder;
    reg [15:0] candidate,applied;
    reg signed [35:0] product;
    wire [18:0] magnitude=sample_in[18]?-sample_in:sample_in;
    wire [19:0] next_remainder={remainder[18:0],numerator[29]};
    wire subtract=next_remainder>={1'b0,denominator};
    wire [29:0] next_quotient={quotient[28:0],subtract};
    wire [4:0] recovery_step=release_preset==0?5'd14:release_preset==1?5'd7:release_preset==2?5'd3:5'd1;
    wire [16:0] recovered={1'b0,gain_q15}+{12'd0,recovery_step};
    wire signed [35:0] scaled=product>>>15;
    always @(posedge clk)begin
        valid_out<=0;clipped<=0;limited<=0;
        if(!rst_n||clear)begin
            state<=0;count<=0;held<=0;denominator<=0;numerator<=0;quotient<=0;remainder<=0;
            candidate<=32768;applied<=32768;gain_q15<=32768;product<=0;sample_out<=0;valid_out<=0;
            clipped<=0;limited<=0;peak_in<=0;peak_out<=0;
        end else case(state)
            0:if(valid_in)begin
                held<=sample_in;peak_in<=magnitude;
                if(!enabled)begin
                    gain_q15<=32768;
                    sample_out<=sample_in>32767?16'sd32767:sample_in< -32768?16'sh8000:sample_in[15:0];
                    peak_out<=sample_in>32767?19'd32767:sample_in< -32768?19'd32768:magnitude;
                    clipped<=sample_in>32767||sample_in< -32768;valid_out<=1;
                end else begin
                    candidate<=recovered>32768?16'd32768:recovered[15:0];
                    if(magnitude>CEILING)begin
                        denominator<=magnitude;numerator<=30'(CEILING<<15);quotient<=0;remainder<=0;count<=29;state<=1;
                    end else begin applied<=recovered>32768?16'd32768:recovered[15:0];state<=2;end
                end
            end
            1:begin
                remainder<=subtract?next_remainder-{1'b0,denominator}:next_remainder;
                numerator<={numerator[28:0],1'b0};quotient<=next_quotient;
                if(count==0)begin applied<=next_quotient<candidate?next_quotient[15:0]:candidate;state<=2;end
                else count<=count-1'b1;
            end
            2:begin product<=held*$signed({1'b0,applied});gain_q15<=applied;state<=3;end
            3:begin
                sample_out<=scaled>32767?16'sd32767:scaled< -32768?16'sh8000:scaled[15:0];
                peak_out<=scaled<0?19'(-scaled):19'(scaled);
                clipped<=scaled>32767||scaled< -32768;limited<=applied<32768;valid_out<=1;state<=0;
            end
            default:state<=0;
        endcase
    end
endmodule
`default_nettype wire
