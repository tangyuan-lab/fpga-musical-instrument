`timescale 1ns/1ps
`default_nettype none

// 实时演奏输入合并：实体键与串口屏共用编号；16 键为 0..15（C4..D#5）。
// 屏幕按键使用固定 8 位力度，不经过 MCP3208 或标定就绪条件。
// 同音有两个来源时，最后一个来源松开才释音；心跳保持不重复产生起音。
module live_touch_key_merge #(
    parameter integer KEY_COUNT = 13,
    parameter [7:0] TOUCH_VELOCITY = 8'd160
) (
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     live_enable,
    input  wire [KEY_COUNT-1:0]      physical_keys,
    input  wire [KEY_COUNT*8-1:0]    physical_velocity,
    input  wire [KEY_COUNT-1:0]      touch_keys,
    output wire [KEY_COUNT-1:0]      held_keys,
    output wire [KEY_COUNT-1:0]      key_on_pulse,
    output wire [KEY_COUNT-1:0]      key_off_pulse,
    output reg  [KEY_COUNT*8-1:0]    velocity_values,
    output reg  [$clog2(KEY_COUNT+1)-1:0] active_key_count
);
    reg [KEY_COUNT-1:0] previous_keys;
    integer k;

    assign held_keys = live_enable ? (physical_keys | touch_keys) : {KEY_COUNT{1'b0}};
    assign key_on_pulse = held_keys & ~previous_keys;
    assign key_off_pulse = previous_keys & ~held_keys;

    // 同音实体键有更高力度时保留它；仅触摸按下时始终使用固定力度。
    always @(*) begin
        velocity_values = {KEY_COUNT*8{1'b0}};
        active_key_count = {$clog2(KEY_COUNT+1){1'b0}};
        for (k = 0; k < KEY_COUNT; k = k + 1) begin
            if (held_keys[k]) begin
                active_key_count = active_key_count + 1'b1;
                if (touch_keys[k] && (!physical_keys[k] ||
                    physical_velocity[k*8 +: 8] < TOUCH_VELOCITY)) begin
                    velocity_values[k*8 +: 8] = TOUCH_VELOCITY;
                end else begin
                    velocity_values[k*8 +: 8] = physical_velocity[k*8 +: 8];
                end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            previous_keys <= {KEY_COUNT{1'b0}};
        end else begin
            previous_keys <= held_keys;
        end
    end
endmodule

`default_nettype wire
