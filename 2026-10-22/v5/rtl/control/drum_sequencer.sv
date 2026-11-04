`default_nettype none
// 四轨16步事件序列，不保存录音。采样域有理数累加避免整除造成 BPM 漂移。
// Fs=50MHz/1024；每采样累加 BPM*4096，达到50MHz*60即前进一个十六分音符。
module drum_sequencer #(
    parameter [31:0] TEMPO_THRESHOLD=32'd3_000_000_000
) (
    input wire clk,rst_n,sample_tick,stop_all,enable,cmd_valid,
    input wire [7:0] cmd_op,cmd_value,
    output reg running,
    output reg [7:0] bpm,
    output reg [3:0] step_index,
    output reg [15:0] triggers,
    output wire [63:0] patterns,
    output wire [15:0] track_sounds
);
    reg [15:0] pattern [0:3];reg [3:0] sound [0:3];reg [31:0] tempo_phase;
    wire [32:0] tempo_next={1'b0,tempo_phase}+{13'd0,bpm,12'd0};
    integer k;
    genvar g;
    generate for(g=0;g<4;g=g+1) begin:g_track
        assign patterns[g*16+:16]=pattern[g];assign track_sounds[g*4+:4]=sound[g];
    end endgenerate
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            running<=0;bpm<=120;step_index<=0;triggers<=0;tempo_phase<=0;
            pattern[0]<=16'h0101;pattern[1]<=16'h1010;pattern[2]<=16'h5555;pattern[3]<=0;
            sound[0]<=0;sound[1]<=1;sound[2]<=2;sound[3]<=7;
        end else begin
            triggers<=0;
            if(stop_all || !enable) begin running<=0;tempo_phase<=0;step_index<=0;end
            else if(cmd_valid && cmd_op==8'h0f && cmd_value<=1) begin
                running<=cmd_value[0];tempo_phase<=0;step_index<=0;
                if(cmd_value==1) for(k=0;k<4;k=k+1) if(pattern[k][0]) triggers[sound[k]]<=1;
            end else if(sample_tick && running) begin
                if(tempo_next>=TEMPO_THRESHOLD) begin
                    tempo_phase<=32'(tempo_next-TEMPO_THRESHOLD);step_index<=step_index+1'b1;
                    for(k=0;k<4;k=k+1) if(pattern[k][4'(step_index+1'b1)]) triggers[sound[k]]<=1;
                end else tempo_phase<=tempo_next[31:0];
            end
            if(cmd_valid) case(cmd_op)
                8'h07: if(cmd_value>=40 && cmd_value<=240) bpm<=cmd_value;
                8'h0c: if(cmd_value<64) pattern[cmd_value[5:4]][cmd_value[3:0]]<=1;
                8'h0d: if(cmd_value<64) pattern[cmd_value[5:4]][cmd_value[3:0]]<=0;
                8'h0e: if(cmd_value<64) sound[cmd_value[5:4]]<=cmd_value[3:0];
                8'h12: if(cmd_value<=2) begin
                    pattern[0]<=cmd_value==0 ? 0 : cmd_value==1 ? 16'h0101 : 16'h1111;
                    pattern[1]<=cmd_value==0 ? 0 : 16'h1010;
                    pattern[2]<=cmd_value==0 ? 0 : 16'h5555;
                    pattern[3]<=0;
                end
                default: begin end
            endcase
        end
    end
endmodule
`default_nettype wire
