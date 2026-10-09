`timescale 1ns/1ns

// 移植自野火工程的按键消抖模块。
// 一个低有效按键的同步与消抖滤波器。
// 默认 5 ms 滤波时间将控制延迟保持在 10 ms 以内。
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

    // 将机械按键信号同步到系统时钟域。
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (sys_rst_n == 1'b0) begin
            key_meta <= 1'b1;
            key_sync <= 1'b1;
        end else begin
            key_meta <= key_n;
            key_sync <= key_meta;
        end
    end

    // 输入稳定后产生一个 note_on 或 note_off 脉冲。
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

