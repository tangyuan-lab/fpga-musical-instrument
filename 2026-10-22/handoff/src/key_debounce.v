`timescale 1ns/1ns

// One active-low key synchronizer and debounce filter.
// The default 5 ms filter keeps the control latency below 10 ms.
module key_debounce
#(
    parameter integer KEY_FILTER_MAX = 250_000
)
(
    input  wire sys_clk,
    input  wire sys_rst_n,
    input  wire key_n,

    output reg  key_state,
    output reg  note_on,
    output reg  note_off
);

    reg        key_meta;
    reg        key_sync;
    reg        key_stable;
    reg [20:0] key_filter_cnt;

    // Synchronize the mechanical key signal into the system clock domain.
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (sys_rst_n == 1'b0) begin
            key_meta <= 1'b1;
            key_sync <= 1'b1;
        end else begin
            key_meta <= key_n;
            key_sync <= key_meta;
        end
    end

    // Generate one note_on or note_off pulse after the input is stable.
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (sys_rst_n == 1'b0) begin
            key_stable     <= 1'b1;
            key_filter_cnt <= 21'd0;
            key_state      <= 1'b0;
            note_on        <= 1'b0;
            note_off       <= 1'b0;
        end else begin
            note_on  <= 1'b0;
            note_off <= 1'b0;

            if (key_sync == key_stable) begin
                key_filter_cnt <= 21'd0;
            end else if (key_filter_cnt < KEY_FILTER_MAX) begin
                key_filter_cnt <= key_filter_cnt + 1'b1;
            end else begin
                key_filter_cnt <= 21'd0;
                key_stable     <= key_sync;
                key_state      <= ~key_sync;

                if (key_sync == 1'b0)
                    note_on <= 1'b1;
                else
                    note_off <= 1'b1;
            end
        end
    end

endmodule
