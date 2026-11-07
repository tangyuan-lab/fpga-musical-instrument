`default_nettype none
// Two source sends share one time-multiplexed multiplier; dry mix is untouched.
// Q7 targets 0..128; move one code per sample (full-scale fade 128 samples).
module pcm_source_sends(
    input wire clk,rst_n,clear,sample_tick,
    input wire signed [22:0] raw_mix,raw_live,raw_song,
    input wire [7:0] live_target,song_target,
    output reg [7:0] live_gain,song_gain,
    output reg signed [15:0] pcm,
    output reg valid,clipped
);
    reg [2:0] state;
    reg signed [22:0] live_hold,song_hold,other_hold,operand;
    reg [7:0] gain;
    reg signed [31:0] product,accumulator;
    wire signed [31:0] total=accumulator+product;
    wire signed [31:0] scaled=total>>>12;
    always @(posedge clk)begin
        valid<=0;clipped<=0;
        if(!rst_n||clear)begin
            state<=0;live_gain<=128;song_gain<=128;pcm<=0;valid<=0;clipped<=0;
            live_hold<=0;song_hold<=0;other_hold<=0;operand<=0;gain<=0;product<=0;accumulator<=0;
        end else begin
            product<=operand*$signed({1'b0,gain});
            case(state)
                0:if(sample_tick)begin
                    live_hold<=raw_live;song_hold<=raw_song;other_hold<=raw_mix-raw_live-raw_song;
                    live_gain<=live_gain<live_target?live_gain+1'b1:live_gain>live_target?live_gain-1'b1:live_gain;
                    song_gain<=song_gain<song_target?song_gain+1'b1:song_gain>song_target?song_gain-1'b1:song_gain;
                    state<=1;
                end
                1:begin operand<=live_hold;gain<=live_gain;state<=2;end
                2:begin operand<=song_hold;gain<=song_gain;state<=3;end
                3:begin accumulator<=product;operand<=other_hold;gain<=128;state<=4;end
                4:begin accumulator<=total;state<=5;end
                5:begin
                    pcm<=scaled>32767?16'sd32767:scaled< -32768?16'sh8000:scaled[15:0];
                    clipped<=scaled>32767||scaled< -32768;valid<=1;state<=0;
                end
                default:state<=0;
            endcase
        end
    end
endmodule
`default_nettype wire
