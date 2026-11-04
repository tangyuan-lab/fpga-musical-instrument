`default_nettype none

// 64 KiB 字节寻址 MIDI 缓存：32 个 16 Kbit SDPB、每个 8 bit x 2048。
// 写口和读口共用系统时钟；读数据在 SDPB 的读时钟后更新。BLKSELA/B 固定为
// 0，完整地址的高 5 位由每个实例的 CEA/CEB 译码，避免异步数组退化成 DFF。
module midi_file_ram_sdp (
    input  wire        clk,
    input  wire        write_enable,
    input  wire [15:0] write_address,
    input  wire [7:0]  write_data,
    input  wire [15:0] read_address,
    output reg  [7:0]  read_data
);
    wire [7:0] bank_data [0:31];
    wire [31:0] bank_do [0:31];
    // 读口和解析器使用同一上升沿。32 个存储块的输出先经过 bank 选择，
    // 再写入 read_data 寄存器，把“存储块选择”和“解析状态判断”拆成
    // 两个时钟周期，避免整合工程中形成过长的组合路径。
    wire read_clk = clk;
    genvar bank;
    generate
        for (bank = 0; bank < 32; bank = bank + 1) begin : g_file_bank
            SDPB #(
                .READ_MODE(1'b0),
                .BIT_WIDTH_0(8),
                .BIT_WIDTH_1(8),
                .BLK_SEL_0(3'b000),
                .BLK_SEL_1(3'b000),
                .RESET_MODE("SYNC")
            ) bank_ram (
                .DO(bank_do[bank]), .DI({24'd0, write_data}),
                .BLKSELA(3'b000), .BLKSELB(3'b000),
                // 8 位 SDPB 的字节地址必须放在 [13:3]，低三位补 0。
                // 放在低 11 位会使每八个连续字节写到同一地址，破坏 MIDI 头。
                .ADA({write_address[10:0], 3'b000}),
                .ADB({read_address[10:0], 3'b000}),
                .CLKA(clk), .CLKB(read_clk),
                .CEA(write_enable && (write_address[15:11] == bank[4:0])),
                .CEB(read_address[15:11] == bank[4:0]),
                .OCE(1'b1), .RESET(1'b0)
            );
            assign bank_data[bank] = bank_do[bank][7:0];
        end
    endgenerate

    reg [7:0] read_mux;
    integer i;
    always @(*) begin
        read_mux = 8'd0;
        for (i = 0; i < 32; i = i + 1)
            if (read_address[15:11] == i[4:0]) read_mux = bank_data[i];
    end
    always @(posedge clk) begin
        read_data <= read_mux;
    end
endmodule

`default_nettype wire
