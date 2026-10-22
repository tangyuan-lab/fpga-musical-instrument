`timescale 1ns/1ps
`default_nettype none

// Icarus 仿真用的 SDPB 行为模型。真实工程由 Gowin 原语推断 BSRAM；
// 按官方 GW5A prim_sim.v 的 8 位模式使用 ADA/ADB[13:3]，低三位不参与字节寻址。
// 保留同步读写时序，验证 UART 帧接收后的文件存储和 PLAY 握手。
module SDPB #(
    parameter integer READ_MODE = 0,
    parameter integer BIT_WIDTH_0 = 8,
    parameter integer BIT_WIDTH_1 = 8,
    parameter [2:0] BLK_SEL_0 = 3'b000,
    parameter [2:0] BLK_SEL_1 = 3'b000,
    parameter RESET_MODE = "SYNC"
) (
    output reg [31:0] DO,
    input  wire [31:0] DI,
    input  wire [2:0]  BLKSELA,
    input  wire [2:0]  BLKSELB,
    input  wire [13:0] ADA,
    input  wire [13:0] ADB,
    input  wire         CLKA,
    input  wire         CLKB,
    input  wire         CEA,
    input  wire         CEB,
    input  wire         OCE,
    input  wire         RESET
);
    reg [7:0] mem [0:2047];
    integer i;
    initial begin
        DO = 32'd0;
        for (i = 0; i < 2048; i = i + 1) mem[i] = 8'd0;
    end
    always @(posedge CLKA)
        if (CEA && BLKSELA == BLK_SEL_0) mem[ADA[13:3]] <= DI[7:0];
    always @(posedge CLKB)
        if (CEB && OCE && BLKSELB == BLK_SEL_1) DO <= {24'd0, mem[ADB[13:3]]};
endmodule

module tb_midi_player_engine;
    reg sys_clk = 1'b0;
    reg sys_rst_n = 1'b0;
    reg uart_rx_i = 1'b1;
    wire uart_tx_o;
    wire [7:0] led_n;
    wire hp_bck, hp_ws, hp_din, pa_en;
    reg start_seen = 1'b0;
    integer wait_cycles;
    integer i;
    reg [7:0] midi [0:34];
    reg [1055:0] payload;
    reg [31:0] crc;
    reg [7:0] force_type;
    reg [15:0] force_seq;
    reg [15:0] force_length;
    reg [1055:0] force_payload;

    always #10 sys_clk = ~sys_clk;

    reg external_play=0,external_stop=0;reg [9:0] divider=0;
    wire sample_tick=divider==1023;wire signed [15:0] pcm;wire file_ready,playing,parser_busy,parser_error;
    always @(posedge sys_clk) divider<=divider+1'b1;
    midi_player_engine dut (
        .sys_clk(sys_clk), .sys_rst_n(sys_rst_n), .uart_rx_i(uart_rx_i),
        .uart_tx_o(uart_tx_o), .led_n(led_n), .sample_tick_i(sample_tick),.audio_ready_i(1'b1),.play_enable_i(1'b1),
        .external_play(external_play),.external_stop(external_stop),.pcm_out(pcm),
        .file_ready_o(file_ready),.playing_o(playing),.parser_busy_o(parser_busy),.parser_error_o(parser_error)
    );

    always @(posedge sys_clk)
        if (dut.parser_start) start_seen <= 1'b1;

    function automatic [31:0] crc32_next;
        input [31:0] crc_in;
        input [7:0] byte_in;
        reg [31:0] c;
        integer bit_index;
        begin
            c = crc_in ^ byte_in;
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1)
                c = c[0] ? ((c >> 1) ^ 32'hedb88320) : (c >> 1);
            crc32_next = c;
        end
    endfunction

    // 直接在顶层内部帧接口注入一帧，避开 115200 baud 的长串行仿真时间。
    task automatic inject_frame;
        input [7:0] frame_type_i;
        input [15:0] frame_seq_i;
        input [15:0] frame_length_i;
        input [1055:0] frame_payload_i;
        begin
            force_type = frame_type_i;
            force_seq = frame_seq_i;
            force_length = frame_length_i;
            force_payload = frame_payload_i;
            @(negedge sys_clk);
            force dut.frame_valid = 1'b1;
            force dut.frame_type = force_type;
            force dut.frame_seq = force_seq;
            force dut.frame_length = force_length;
            force dut.frame_payload = force_payload;
            @(negedge sys_clk);
            release dut.frame_valid;
            release dut.frame_type;
            release dut.frame_seq;
            release dut.frame_length;
            release dut.frame_payload;
        end
    endtask

    initial begin
        // 与 tb_midi_type0_parser 相同：一个 C4 音符，确保后续解析器能完成。
        midi[0]=8'h4d; midi[1]=8'h54; midi[2]=8'h68; midi[3]=8'h64;
        midi[4]=0; midi[5]=0; midi[6]=0; midi[7]=6;
        midi[8]=0; midi[9]=0; midi[10]=0; midi[11]=1; midi[12]=1; midi[13]=8'he0;
        midi[14]=8'h4d; midi[15]=8'h54; midi[16]=8'h72; midi[17]=8'h6b;
        midi[18]=0; midi[19]=0; midi[20]=0; midi[21]=13;
        midi[22]=0; midi[23]=8'h90; midi[24]=8'h3c; midi[25]=8'h64;
        midi[26]=8'h83; midi[27]=8'h60; midi[28]=8'h80; midi[29]=8'h3c; midi[30]=0;
        midi[31]=0; midi[32]=8'hff; midi[33]=8'h2f; midi[34]=0;

        repeat (8) @(negedge sys_clk);
        sys_rst_n = 1'b1;
        repeat (8) @(negedge sys_clk);

        // FILE_BEGIN: MID0 + size + CRC32。
        crc = 32'hffffffff;
        for (i = 0; i < 35; i = i + 1) crc = crc32_next(crc, midi[i]);
        payload = 1056'd0;
        payload[31:0] = 32'h3044494d;
        payload[63:32] = 32'd35;
        payload[95:64] = ~crc;
        inject_frame(8'h10, 16'd1, 16'd12, payload);

        // FILE_DATA：一次性写入 35 字节，随后等待暂存缓冲完全落入 BSRAM。
        payload = 1056'd0;
        payload[31:0] = 32'd0;
        for (i = 0; i < 35; i = i + 1)
            payload[(i + 4) * 8 +: 8] = midi[i];
        inject_frame(8'h11, 16'd2, 16'd39, payload);
        wait (!dut.write_busy);
        @(negedge sys_clk);

        // 假设第一份 ACK 在电脑端丢失：同一序号和偏移的数据块会被重发。
        // FPGA 应重新 ACK，但不能再次写 RAM 或改变 CRC/received_bytes。
        inject_frame(8'h11, 16'd2, 16'd39, payload);
        repeat (3) @(negedge sys_clk);
        if (dut.store_inst.received_bytes != 32'd35 || dut.store_status != 0 || dut.write_busy)
            $fatal(1, "duplicate MIDI block was not accepted idempotently");

        payload = 1056'd0;
        payload[31:0] = ~crc;
        inject_frame(8'h12, 16'd3, 16'd4, payload);
        wait (dut.file_ready);

        // 错误长度的 PLAY 不应产生启动脉冲，也不能复用上一次音色编号。
        payload = 1056'd0;
        inject_frame(8'h13, 16'd4, 16'd2, payload);
        repeat (20) @(negedge sys_clk);
        if (start_seen)
            $fatal(1, "malformed PLAY unexpectedly started parser");

        // PLAY 帧之后，play_request 会延后一拍到达顶层；测试必须看到解析启动。
        payload = 1056'd0;
        payload[7:0] = 8'd0;
        inject_frame(8'h13, 16'd5, 16'd1, payload);
        wait_cycles = 0;
        while (!dut.parser_busy && wait_cycles < 50) begin
            @(negedge sys_clk);
            wait_cycles = wait_cycles + 1;
        end
        if (!start_seen || !dut.parser_busy)
            $fatal(1, "PLAY did not start parser: start_seen=%0d busy=%0d", start_seen, dut.parser_busy);

        wait_cycles = 0;
        while (!dut.parser_ready && !dut.parser_error && wait_cycles < 30000) begin
            @(negedge sys_clk);
            wait_cycles = wait_cycles + 1;
        end
        if (dut.parser_error || !dut.parser_ready || dut.event_count != 1)
            $fatal(1, "MIDI parse failed err=%0d code=%0d ready=%0d count=%0d",
                   dut.parser_error, dut.parser_error_code, dut.parser_ready, dut.event_count);
        wait_cycles=0;
        while(pcm==0 && wait_cycles<20000) begin @(negedge sys_clk);wait_cycles=wait_cycles+1;end
        if(pcm==0 || !playing) $fatal(1,"external sample clock produced no MIDI PCM");
        external_stop=1;repeat(4) @(negedge sys_clk);external_stop=0;
        repeat(4) @(negedge sys_clk);
        if(playing || !file_ready) $fatal(1,"stop must retain uploaded file");
        external_play=1;@(negedge sys_clk);external_play=0;
        wait_cycles=0;
        while(!playing && wait_cycles<30000) begin @(negedge sys_clk);wait_cycles=wait_cycles+1;end
        if(!playing) $fatal(1,"screen external PLAY failed");
        $display("PASS tb_midi_player_engine parser_start=%0d event_count=%0d", start_seen, dut.event_count);
        $finish;
    end
endmodule

`default_nettype wire
