// Scalar Gaussian/chirp generator arithmetic. No waveform or measured IR ROM.
// State: phase, phase increment, log2 envelope and its first difference.
// Each accepted operation generates one sample and the next packet state.
module gaussian_packet_datapath (
    input wire clk, rst_n, in_valid,
    input wire [15:0] in_tag,
    input wire [31:0] phase, step,
    input wire signed [31:0] step_delta,
    input wire signed [47:0] log_env, log_delta,
    input wire signed [39:0] log_accel,
    input wire [23:0] peak_q20,
    output reg out_valid,
    output reg [15:0] out_tag,
    output reg signed [31:0] sample_q20,
    output reg [159:0] next_state
);
    reg signed [15:0] cosine [0:4095];
    reg [16:0] exp2_fraction [0:1023];
    initial begin
        $readmemh("src/excitation_v3/cosine_4096x16.mem", cosine);
        $readmemh("src/excitation_v3/exp2_1024x17.mem", exp2_fraction);
    end
    reg v0,v1,v2;
    reg [15:0] tag0,tag1,tag2;
    reg signed [15:0] sine0,sine1,sine2;
    reg [16:0] exponential0;
    reg [23:0] peak0,envelope2;
    reg [40:0] gain1;
    reg [5:0] shift0,shift1;
    reg [159:0] state0,state1,state2;
    wire signed [7:0] integer_log = log_env[47:40];
    wire [31:0] phase_next=phase+step;
    wire [31:0] step_next=step+step_delta;
    wire signed [47:0] log_next=log_env+log_delta;
    wire signed [47:0] delta_next=log_delta+{{8{log_accel[39]}},log_accel};
    wire signed [40:0] product = sine2 * $signed({1'b0,envelope2});
    always @(posedge clk) begin
        if (!rst_n) begin
            v0<=0;v1<=0;v2<=0;out_valid<=0;
            sample_q20<=0;out_tag<=0;next_state<=0;
        end else begin
            v0<=in_valid;v1<=v0;v2<=v1;out_valid<=v2;
            if (in_valid) begin
                sine0<=cosine[phase[31:20]];
                exponential0<=exp2_fraction[log_env[39:30]];
                peak0<=peak_q20;
                shift0<=integer_log>=0 ? 0 : (integer_log<=-63 ? 63 : -integer_log);
                tag0<=in_tag;
                state0<={phase_next,step_next,log_next,delta_next};
            end
            if (v0) begin
                gain1<=peak0*exponential0;
                sine1<=sine0;shift1<=shift0;tag1<=tag0;state1<=state0;
            end
            if (v1) begin
                envelope2<=(gain1>>16)>>shift1;
                sine2<=sine1;tag2<=tag1;state2<=state1;
            end
            if (v2) begin
                sample_q20<=product>>>15;
                out_tag<=tag2;next_state<=state2;
            end
        end
    end
endmodule
