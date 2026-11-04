// 一段 48 kHz、单声道、1.5 秒的录音，综合成块 RAM。
// 松键时用约 42.6 ms 的淡出，避免幅度直接跳到零。
module sampled_piano_a4 (
    input  wire               clk,
    input  wire               rst_n,
    input  wire               sample_tick,
    input  wire               note_on,
    input  wire               note_active,
    output wire signed [15:0] sample_out
);
    localparam [16:0] LAST_INDEX = 17'd72000;
    reg signed [15:0] sample_rom [0:72000];
    initial $readmemh("mem/sample_a4_v16_bright_72001x16.mem", sample_rom);

    reg [16:0] sample_index = 17'd0;
    wire [16:0] next_index = (sample_index < LAST_INDEX) ?
                             sample_index + 17'd1 : sample_index;
    wire [16:0] rom_addr = sample_tick ? next_index : sample_index;
    reg signed [15:0] rom_q = 16'sd0;
    reg [10:0] release_level = 11'd0;

    always @(posedge clk) begin
        rom_q <= sample_rom[rom_addr];
        if (!rst_n) begin
            sample_index <= 17'd0;
            release_level <= 11'd0;
        end else if (note_on) begin
            sample_index <= 17'd0;
            release_level <= 11'd2047;
        end else if (sample_tick) begin
            sample_index <= next_index;
            if (!note_active && release_level != 11'd0)
                release_level <= release_level - 11'd1;
        end
    end

    wire signed [27:0] release_product =
        $signed(rom_q) * $signed({1'b0, release_level});
    assign sample_out = rst_n ? release_product[26:11] : 16'sd0;
endmodule
