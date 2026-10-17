`timescale 1ns/1ps
module ddr3_mock_case #(
    parameter integer MODE = 0
) (
    input wire clk,
    input wire rst,
    output wire [1:0] status,
    output reg [3:0] writes = 4'd0,
    output reg [3:0] reads = 4'd0
);
    wire cmd_en, wr_data_en, wr_data_end;
    wire [2:0] cmd;
    wire [27:0] addr;
    wire [127:0] wr_data;
    wire [15:0] wr_data_mask;
    reg [127:0] rd_data = 128'd0;
    reg rd_data_valid = 1'b0;
    reg pending = 1'b0;
    reg read_slot = 1'b0;
    reg [127:0] memory [0:1];
    wire init_calib_complete = (MODE != 2);

    ddr3_selftest #(.WATCHDOG_BIT(10)) dut (
        .clk(clk), .rst(rst), .init_calib_complete(init_calib_complete),
        .cmd_ready(1'b1), .wr_data_rdy(1'b1),
        .rd_data(rd_data), .rd_data_valid(rd_data_valid),
        .cmd_en(cmd_en), .cmd(cmd), .addr(addr),
        .wr_data_en(wr_data_en), .wr_data(wr_data),
        .wr_data_mask(wr_data_mask), .wr_data_end(wr_data_end),
        .status(status)
    );

    always @(posedge clk) begin
        if (rst) begin
            rd_data_valid <= 1'b0;
            pending <= 1'b0;
            writes <= 4'd0;
            reads <= 4'd0;
        end else begin
            rd_data_valid <= 1'b0;
            if (pending) begin
                rd_data <= (MODE == 1 && read_slot == 1'b0) ?
                           ~memory[read_slot] : memory[read_slot];
                rd_data_valid <= 1'b1;
                pending <= 1'b0;
            end
            if (cmd_en) begin
                if (addr != 28'd0 && addr != 28'h40)
                    $fatal(1, "Unexpected DDR address");
                if (cmd == 3'b000) begin
                    if (!wr_data_en || !wr_data_end || wr_data_mask != 16'd0)
                        $fatal(1, "Malformed write beat");
                    memory[addr[6]] <= wr_data;
                    writes <= writes + 4'd1;
                end else if (cmd == 3'b001) begin
                    if (wr_data_en) $fatal(1, "Read enabled write data");
                    read_slot <= addr[6];
                    pending <= 1'b1;
                    reads <= reads + 4'd1;
                end else $fatal(1, "Unexpected DDR command");
            end
        end
    end
endmodule

module tb_ddr3_selftest;
    reg clk = 1'b0;
    always #5 clk = ~clk;
    reg rst = 1'b1;
    wire [1:0] ok_status, mismatch_status, timeout_status;
    wire [3:0] ok_writes, ok_reads;
    reg test_pass = 1'b0;

    ddr3_mock_case #(.MODE(0)) success_case (
        .clk(clk), .rst(rst), .status(ok_status),
        .writes(ok_writes), .reads(ok_reads)
    );
    ddr3_mock_case #(.MODE(1)) mismatch_case (
        .clk(clk), .rst(rst), .status(mismatch_status),
        .writes(), .reads()
    );
    ddr3_mock_case #(.MODE(2)) timeout_case (
        .clk(clk), .rst(rst), .status(timeout_status),
        .writes(), .reads()
    );

    initial begin
        repeat (4) @(negedge clk);
        rst = 1'b0;
        repeat (1300) @(negedge clk);
        if (ok_status !== 2'd1 || ok_writes !== 4'd2 || ok_reads !== 4'd2)
            $fatal(1, "Write/read success path failed: status=%0d w=%0d r=%0d",
                   ok_status, ok_writes, ok_reads);
        if (mismatch_status !== 2'd3)
            $fatal(1, "Corrupted read was not detected");
        if (timeout_status !== 2'd2)
            $fatal(1, "Calibration timeout was not detected");
        test_pass = 1'b1;
        $display("PASS: DDR3 command sequence, two 128-bit round trips, mismatch and calibration timeout");
        $finish;
    end
endmodule
