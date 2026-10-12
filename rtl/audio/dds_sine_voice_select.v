// 一个 4096 点的 Wildfire 正弦声部，每次按键选择一个音符。
module dds_sine_voice_select (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               sample_tick,
    input  wire        [31:0] phase_step,
    input  wire               note_on,
    input  wire               voice_active,
    output wire signed [15:0] sample_out
);
    reg [31:0] phase_acc = 32'd0;
    wire [31:0] next_phase = phase_acc + phase_step;
    wire [11:0] rom_addr = sample_tick ? next_phase[31:20] :
                                        phase_acc[31:20];

    reg [15:0] sine_table [0:4095];
    reg [15:0] rom_q = 16'd0;
    initial $readmemh("../rtl/mem/sine_4096x16.ver", sine_table);

    always @(posedge clk) begin
        if (!rst_n)
            phase_acc <= 32'd0;
        else if (note_on && !voice_active)
            // 新乐句从零开始。如果音符在释放过程中重新触发，
            // 则保持相位连续，避免产生可听见的跳变。
            phase_acc <= 32'd0;
        else if (sample_tick)
            phase_acc <= next_phase;

        // 同步 ROM 读取方式便于综合为 Gowin 块 RAM。
        rom_q <= sine_table[rom_addr];
    end

    assign sample_out = rst_n ? $signed(rom_q) : 16'sd0;
endmodule

