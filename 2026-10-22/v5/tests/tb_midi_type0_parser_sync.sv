`timescale 1ns/1ps
`default_nettype none

// 与 midi_file_ram_sdp 的两级同步读延迟一致：第一拍读取 SDPB，第二拍
// 锁存 bank 选择结果，确认解析器不会依赖异步 RAM 输出。
module tb_midi_type0_parser_sync;
    reg clk = 0; always #5 clk = ~clk;
    reg rst_n = 0;
    reg start = 0;
    reg stop = 0;
    wire [15:0] address;
    reg [7:0] mem [0:255];
    reg [7:0] data_bram_q = 0;
    reg [7:0] data_q = 0;
    wire [7:0] data = data_q;
    wire busy, ready, error;
    wire [3:0] error_code;
    wire [8:0] event_count;
    reg [8:0] event_index = 0;
    wire [31:0] event_start, event_end;
    wire [6:0] event_note;
    wire [7:0] event_velocity;
    wire [5:0] tempo_count;
    reg [5:0] tempo_index = 0;
    wire [31:0] tempo_tick;
    wire [23:0] tempo_value;
    wire [15:0] ppqn;
    integer i;

    always @(posedge clk) begin
        data_bram_q <= mem[address];
        data_q <= data_bram_q;
    end

    midi_type0_parser dut (
        .clk(clk), .rst_n(rst_n), .start(start), .stop(stop), .file_size(17'd35),
        .file_read_address(address), .file_read_data(data), .busy(busy), .ready(ready),
        .error(error), .error_code(error_code), .event_count(event_count),
        .event_read_index(event_index), .event_start_tick(event_start), .event_end_tick(event_end),
        .event_note(event_note), .event_velocity(event_velocity), .tempo_count(tempo_count),
        .tempo_read_index(tempo_index), .tempo_tick(tempo_tick),
        .tempo_us_per_quarter(tempo_value), .division_ppqn(ppqn)
    );

    initial begin
        for (i = 0; i < 256; i = i + 1) mem[i] = 0;
        mem[0]=8'h4d; mem[1]=8'h54; mem[2]=8'h68; mem[3]=8'h64;
        mem[4]=0; mem[5]=0; mem[6]=0; mem[7]=6;
        mem[8]=0; mem[9]=0; mem[10]=0; mem[11]=1; mem[12]=1; mem[13]=8'he0;
        mem[14]=8'h4d; mem[15]=8'h54; mem[16]=8'h72; mem[17]=8'h6b;
        mem[18]=0; mem[19]=0; mem[20]=0; mem[21]=13;
        mem[22]=0; mem[23]=8'h90; mem[24]=8'h3c; mem[25]=8'h64;
        mem[26]=8'h83; mem[27]=8'h60; mem[28]=8'h80; mem[29]=8'h3c; mem[30]=0;
        mem[31]=0; mem[32]=8'hff; mem[33]=8'h2f; mem[34]=0;
        repeat (4) @(posedge clk);
        rst_n <= 1;
        @(posedge clk); start <= 1;
        @(posedge clk); start <= 0;
        wait (ready || error);
        #1;
        if (error || !ready || event_count != 1 || event_note != 7'd60 ||
            event_velocity != 8'd100 || event_start != 0 || event_end != 480 || ppqn != 480)
            $fatal(1, "sync parser mismatch err=%0d code=%0d count=%0d note=%0d vel=%0d start=%0d end=%0d ppqn=%0d",
                   error, error_code, event_count, event_note, event_velocity, event_start,
                   event_end, ppqn);
        $display("PASS tb_midi_type0_parser_sync");
        $finish;
    end
endmodule
`default_nettype wire
