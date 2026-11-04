`timescale 1ns/1ps
`default_nettype none
// 新裸FSR接法：ADC随压力上升。复用完整四声部/力度/释音用例，逐键镜像模拟输入。
module tb_16key_pressure_rising_audio_path;
    tb_16key_pressure_audio_path #(.ACTIVE_LOW_MASK(16'h0000)) path();
    final $display("PASS tb_16key_pressure_rising_audio_path");
endmodule
`default_nettype wire
