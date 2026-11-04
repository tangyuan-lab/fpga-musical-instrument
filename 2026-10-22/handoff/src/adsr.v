`timescale 1ns/1ns

// Per-note ADSR envelope, updated once for every 48 kHz audio sample.
// The default times are deliberately short enough for a responsive key.
module adsr
#(
    parameter [15:0] ATTACK_STEP  = 16'd256,
    parameter [15:0] DECAY_STEP   = 16'd8,
    parameter [15:0] SUSTAIN_LEVEL = 16'd39_322,
    // About 200 ms from the default sustain level to zero at 48 kHz.
    parameter [15:0] RELEASE_STEP = 16'd4
)
(
    input  wire        sys_clk,
    input  wire        sys_rst_n,
    input  wire        sample_tick,
    input  wire        note_on,
    input  wire        note_off,
    input  wire        note_active,

    output reg  [15:0] gain,
    output wire        voice_active
);

    localparam [2:0] ADSR_IDLE    = 3'd0;
    localparam [2:0] ADSR_ATTACK  = 3'd1;
    localparam [2:0] ADSR_DECAY   = 3'd2;
    localparam [2:0] ADSR_SUSTAIN = 3'd3;
    localparam [2:0] ADSR_RELEASE = 3'd4;

    reg [2:0] adsr_state;

    assign voice_active = (adsr_state != ADSR_IDLE);

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (sys_rst_n == 1'b0) begin
            adsr_state <= ADSR_IDLE;
            gain       <= 16'd0;
        end else if (note_on == 1'b1) begin
            adsr_state <= ADSR_ATTACK;
            // Retrigger from the current level when the previous note is
            // still releasing. Clearing gain here would create a step to
            // digital zero and produce an audible click.
            if (adsr_state == ADSR_IDLE)
                gain <= 16'd0;
        end else if ((note_off == 1'b1 || note_active == 1'b0)
                     && adsr_state != ADSR_IDLE
                     && adsr_state != ADSR_RELEASE) begin
            adsr_state <= ADSR_RELEASE;
        end else if (sample_tick == 1'b1) begin
            case (adsr_state)
                ADSR_IDLE: begin
                    gain <= 16'd0;
                end

                ADSR_ATTACK: begin
                    if (gain >= (16'hffff - ATTACK_STEP)) begin
                        gain       <= 16'hffff;
                        adsr_state <= ADSR_DECAY;
                    end else begin
                        gain <= gain + ATTACK_STEP;
                    end
                end

                ADSR_DECAY: begin
                    if (gain <= SUSTAIN_LEVEL) begin
                        gain       <= SUSTAIN_LEVEL;
                        adsr_state <= ADSR_SUSTAIN;
                    end else if (gain - DECAY_STEP <= SUSTAIN_LEVEL) begin
                        gain       <= SUSTAIN_LEVEL;
                        adsr_state <= ADSR_SUSTAIN;
                    end else begin
                        gain <= gain - DECAY_STEP;
                    end
                end

                ADSR_SUSTAIN: begin
                    gain <= SUSTAIN_LEVEL;
                end

                ADSR_RELEASE: begin
                    if (gain <= RELEASE_STEP) begin
                        gain       <= 16'd0;
                        adsr_state <= ADSR_IDLE;
                    end else begin
                        gain <= gain - RELEASE_STEP;
                    end
                end

                default: begin
                    adsr_state <= ADSR_IDLE;
                    gain       <= 16'd0;
                end
            endcase
        end
    end

endmodule
