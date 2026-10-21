`timescale 1ns/1ps
`default_nettype none

// 机械按键同步与消抖。默认 50 MHz 下连续稳定 10 ms 才确认一次按下事件。
// 压力演奏键不经过此模块，它只用于音色切换等低速功能键。
module button_filter #(
    parameter integer STABLE_CYCLES = 500_000
) (
    input  wire clk,
    input  wire rst_n,
    input  wire key_n,
    output reg  pressed
);
    localparam integer COUNT_WIDTH =
        (STABLE_CYCLES <= 1) ? 1 : $clog2(STABLE_CYCLES);

    reg [1:0] key_sync_n;
    reg stable_n;
    reg [COUNT_WIDTH-1:0] stable_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_sync_n  <= 2'b11;
            stable_n    <= 1'b1;
            stable_count <= {COUNT_WIDTH{1'b0}};
            pressed     <= 1'b0;
        end else begin
            key_sync_n <= {key_sync_n[0], key_n};
            pressed    <= 1'b0;

            if (key_sync_n[1] == stable_n) begin
                stable_count <= {COUNT_WIDTH{1'b0}};
            end else if (STABLE_CYCLES <= 1 || stable_count == STABLE_CYCLES - 1) begin
                stable_count <= {COUNT_WIDTH{1'b0}};
                stable_n     <= key_sync_n[1];
                pressed      <= !key_sync_n[1];
            end else begin
                stable_count <= stable_count + 1'b1;
            end
        end
    end
endmodule

`default_nettype wire
