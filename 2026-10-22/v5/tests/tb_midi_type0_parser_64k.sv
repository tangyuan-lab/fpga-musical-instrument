`timescale 1ns/1ps
`default_nettype none

// 验证恰好 65536 字节的文件不会在最后一个地址后回绕到地址 0。
// 轨道主体使用一个 65505 字节 SysEx，再把 End-of-Track 放在 0xffff。
module tb_midi_type0_parser_64k;
    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg start = 1'b0;
    reg stop = 1'b0;
    wire [15:0] address;
    reg [7:0] mem [0:65535];
    wire [7:0] data = mem[address];
    wire busy, ready, error;
    wire [3:0] error_code;
    wire [8:0] event_count;
    reg [8:0] event_index = 9'd0;
    wire [31:0] event_start, event_end;
    wire [6:0] event_note;
    wire [7:0] event_velocity;
    wire [5:0] tempo_count;
    reg [5:0] tempo_index = 6'd0;
    wire [31:0] tempo_tick;
    wire [23:0] tempo_value;
    wire [15:0] ppqn;
    integer i;
    integer cycles;

    always #5 clk = ~clk;

    midi_type0_parser dut (
        .clk(clk), .rst_n(rst_n), .start(start), .stop(stop), .file_size(17'd65536),
        .file_read_address(address), .file_read_data(data), .busy(busy), .ready(ready),
        .error(error), .error_code(error_code), .event_count(event_count),
        .event_read_index(event_index), .event_start_tick(event_start), .event_end_tick(event_end),
        .event_note(event_note), .event_velocity(event_velocity), .tempo_count(tempo_count),
        .tempo_read_index(tempo_index), .tempo_tick(tempo_tick),
        .tempo_us_per_quarter(tempo_value), .division_ppqn(ppqn)
    );

    initial begin
        for (i = 0; i < 65536; i = i + 1) mem[i] = 8'd0;

        // MThd：format 0、一个轨道、PPQN=480。
        mem[0]=8'h4d; mem[1]=8'h54; mem[2]=8'h68; mem[3]=8'h64;
        mem[4]=0; mem[5]=0; mem[6]=0; mem[7]=6;
        mem[8]=0; mem[9]=0; mem[10]=0; mem[11]=1; mem[12]=1; mem[13]=8'he0;
        mem[14]=8'h4d; mem[15]=8'h54; mem[16]=8'h72; mem[17]=8'h6b;
        // 65536 - 22 = 65514 = 0x0000ffea 字节轨道数据。
        mem[18]=0; mem[19]=0; mem[20]=8'hff; mem[21]=8'hea;

        // delta=0，SysEx 长度 65505 的 VLQ 为 83 ff 61。
        mem[22]=0; mem[23]=8'hf0; mem[24]=8'h83; mem[25]=8'hff; mem[26]=8'h61;
        // mem[27]..mem[65531] 保持 0，作为 SysEx payload。
        mem[65532]=0; mem[65533]=8'hff; mem[65534]=8'h2f; mem[65535]=0;

        repeat (4) @(posedge clk);
        rst_n <= 1'b1;
        @(posedge clk); start <= 1'b1;
        @(posedge clk); start <= 1'b0;

        cycles = 0;
        while (!ready && !error && cycles < 300000) begin
            @(posedge clk);
            cycles = cycles + 1;
        end
        #1;
        if (error || !ready || event_count != 0 || dut.file_position != 17'd65536)
            $fatal(1, "64 KiB boundary failed err=%0d code=%0d ready=%0d count=%0d pos=%0d",
                   error, error_code, ready, event_count, dut.file_position);
        $display("PASS tb_midi_type0_parser_64k cycles=%0d", cycles);
        $finish;
    end
endmodule

`default_nettype wire
