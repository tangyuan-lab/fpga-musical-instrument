module dds_sine_voice #(
    // 野火设计在 48 kHz 下的 440 Hz 调音字。
    parameter [31:0] PHASE_STEP = 32'd39370534
) (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               sample_tick,
    output wire signed [15:0] sample_out
);

    // 野火设计使用 32 位相位累加器，并采用相同的
    // 4096 点、幅值约为 +/-4096 的正弦表。采样节拍现在来自
    // PT8211 帧边界，因此波形速率和 DAC 采样速率保持一致。
    reg [31:0] phase_acc = 32'd0;
    wire [31:0] next_phase = phase_acc + PHASE_STEP;
    wire [11:0] rom_addr = sample_tick ? next_phase[31:20] :
                                        phase_acc[31:20];

    reg [15:0] sine_table [0:4095];
    reg [15:0] rom_q = 16'd0;
    initial $readmemh("../rtl/mem/sine_4096x16.ver", sine_table);

    always @(posedge clk) begin
        if (!rst_n)
            phase_acc <= 32'd0;
        else if (sample_tick)
            phase_acc <= next_phase;

        // 同步读取方式便于综合为 Gowin 块 RAM。
        rom_q <= sine_table[rom_addr];
    end

    assign sample_out = rst_n ? $signed(rom_q) : 16'sd0;

endmodule

