`default_nettype none

// 上电后先发送一段静音数据，再使能 NEO Dock 模拟功放，降低耳机/扬声器爆音。
// 原理图标注 PA_EN=0 时功放开启，因此 pa_en 在复位和等待期间保持为 1。
module audio_startup #(
    parameter integer STARTUP_CYCLES = 5_000_000
) (
    input  wire clk,
    input  wire rst_n,
    output reg  audio_ready,
    output wire pa_en
);
    localparam integer COUNT_WIDTH = (STARTUP_CYCLES <= 1) ? 1 : $clog2(STARTUP_CYCLES);
    reg [COUNT_WIDTH-1:0] startup_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            startup_count <= {COUNT_WIDTH{1'b0}};
            audio_ready   <= 1'b0;
        end else if (!audio_ready) begin
            if (STARTUP_CYCLES <= 1 || startup_count == STARTUP_CYCLES - 1) begin
                startup_count <= {COUNT_WIDTH{1'b0}};
                audio_ready   <= 1'b1;
            end else begin
                startup_count <= startup_count + {{(COUNT_WIDTH-1){1'b0}}, 1'b1};
            end
        end
    end

    assign pa_en = ~audio_ready;
endmodule

`default_nettype wire

