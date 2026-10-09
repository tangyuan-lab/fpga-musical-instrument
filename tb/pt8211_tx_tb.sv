`timescale 1ns/1ps

module pt8211_tx_tb;
    reg clk = 1'b0;
    always #10 clk = ~clk;
    reg rst_n = 1'b0;
    reg [15:0] sample_in = 16'hA53C;
    wire bck, ws, din, frame_tick;
    integer bit_no;
    integer frame_no;
    integer tick_count = 0;
    time last_bck_rise = 0;
    reg [15:0] expected_word;
    reg test_pass = 1'b0;

    // 使用较小的测试分频比，让协议仿真更快且结果可重复。
    pt8211_tx #(.CLK_HZ(128), .SAMPLE_HZ(1)) tx (
        .clk(clk), .rst_n(rst_n), .sample_in(sample_in),
        .bck(bck), .ws(ws), .din(din), .frame_tick(frame_tick)
    );

    always @(posedge clk)
        if (frame_tick)
            tick_count = tick_count + 1;

    initial begin
        repeat (5) @(negedge clk);
        rst_n = 1'b1;
        for (frame_no = 0; frame_no < 2; frame_no = frame_no + 1) begin
            expected_word = frame_no == 0 ? 16'hA53C : 16'h5AC3;
            for (bit_no = 0; bit_no < 32; bit_no = bit_no + 1) begin
                @(posedge bck);
                if (last_bck_rise != 0 && $time - last_bck_rise != 80)
                    $fatal(1, "BCK period wrong");
                last_bck_rise = $time;
                if (ws !== (bit_no >= 16))
                    $fatal(1, "WS wrong at frame %0d bit %0d", frame_no, bit_no);
                if (din !== expected_word[15 - (bit_no % 16)])
                    $fatal(1, "DIN wrong at frame %0d bit %0d", frame_no, bit_no);
                if (frame_no == 0 && bit_no == 7)
                    sample_in = 16'h5AC3;
            end
        end
        if (tick_count != 2)
            $fatal(1, "Expected two complete stereo frames, got %0d", tick_count);
        rst_n = 1'b0;
        repeat (2) @(negedge clk);
        if (bck !== 1'b1 || ws !== 1'b0 || din !== 1'b0)
            $fatal(1, "Serial pins did not return to reset state");
        test_pass = 1'b1;
        $display("PASS: PT8211 protocol, sample hold and reset");
        $finish;
    end
endmodule

