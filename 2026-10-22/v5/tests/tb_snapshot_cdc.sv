`timescale 1ns/1ps
`default_nettype none

module tb_snapshot_cdc;
    reg src_clk = 1'b0;
    reg dst_clk = 1'b0;
    reg src_rst_n = 1'b0;
    reg dst_rst_n = 1'b0;
    reg [15:0] counter = 16'd1;
    wire [31:0] dst_data;
    wire dst_valid;
    integer received = 0;

    always #10 src_clk = ~src_clk;
    always #17 dst_clk = ~dst_clk;

    snapshot_cdc #(.WIDTH(32)) dut (
        .src_clk(src_clk), .src_rst_n(src_rst_n), .src_data({counter, ~counter}),
        .dst_clk(dst_clk), .dst_rst_n(dst_rst_n),
        .dst_data(dst_data), .dst_valid(dst_valid)
    );

    always @(negedge src_clk)
        if (src_rst_n)
            counter <= counter + 1'b1;

    always @(negedge dst_clk) begin
        if (dst_valid) begin
            if (dst_data[31:16] !== ~dst_data[15:0])
                $fatal(1, "torn multi-bit snapshot");
            received = received + 1;
        end
    end

    initial begin
        #100 src_rst_n = 1'b1;
        #333 dst_rst_n = 1'b1;
        #20_000;
        if (received < 50)
            $fatal(1, "snapshot CDC stopped publishing");
        $display("PASS tb_snapshot_cdc received=%0d", received);
        $finish;
    end
endmodule

`default_nettype wire
