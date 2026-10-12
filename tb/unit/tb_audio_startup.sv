`timescale 1ns/1ps
// audio_startup 单元测试：上电静音计数、计满放行、复位后重新计时、计数边界。
//
// 检查方式：
//   1) pa_en 是 audio_ready 的反相输出，功放低有效，所以等待期间 pa_en 必须为 1。
//   2) 用一个很小的 STARTUP_CYCLES 参数实例，逐拍检查 startup_count：
//      释放复位后的第一拍计数仍为 0，之后每拍加一，第 STARTUP_CYCLES-1 拍时
//      计数为 STARTUP_CYCLES-1，下一拍 audio_ready 才允许拉高。早一拍或晚一拍
//      都会被判失败。
//   3) 放行之后计数回到 0，audio_ready 不再变化。
//   4) 复位拉低后 audio_ready 立刻回到 0，重新释放复位后完整重跑一次计数。
//   5) 再用默认参数的实例，确认 5_000_000 拍的长计数在恰好那一拍放行。
//
// 不检查：pa_en 与真实功放芯片的时序余量、时钟频率。
//
// 注意：$display 的提示文字保持英文，这个 ModelSim 版本会把控制台里的
// 非 ASCII 文本弄成乱码。
`default_nettype none

module tb_audio_startup;
    localparam integer CLK_PERIOD  = 20;   // 与仓库其它 testbench 一致，50 MHz
    localparam integer FAST_CYCLES = 10;
    localparam integer BIG_CYCLES  = 5_000_000;
    // FAST_CYCLES=10 时 COUNT_WIDTH=$clog2(10)=4，计数范围 0..9。
    localparam integer FAST_WIDTH  = 4;

    reg clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    reg rst_n_fast = 1'b0;
    reg rst_n_big  = 1'b0;

    wire fast_ready, fast_pa_en;
    wire big_ready, big_pa_en;

    audio_startup #(.STARTUP_CYCLES(FAST_CYCLES)) dut_fast (
        .clk(clk), .rst_n(rst_n_fast), .audio_ready(fast_ready), .pa_en(fast_pa_en)
    );

    audio_startup #(.STARTUP_CYCLES(BIG_CYCLES)) dut_big (
        .clk(clk), .rst_n(rst_n_big), .audio_ready(big_ready), .pa_en(big_pa_en)
    );

    integer errors = 0;
    integer i;
    integer n;

    task check;
        input condition;
        input [1023:0] text;
        begin
            if (!condition) begin
                errors = errors + 1;
                $display("FAIL %0s", text);
            end
        end
    endtask

    // 数从当前时刻到 audio_ready 变高之间还要走几个 posedge。
    // 满 limit 拍仍未变高时返回 limit。
    task count_edges_to_ready;
        input integer limit;
        output integer edges;
        integer k;
        begin
            edges = limit;
            for (k = 1; k <= limit; k = k + 1) begin
                @(posedge clk);
                #1;
                if (fast_ready === 1'b1) begin
                    edges = k;
                    k = limit + 1;
                end
            end
        end
    endtask

    initial begin
        // ---- 1. 复位期间的状态 ----
        repeat (3) @(negedge clk);
        check(fast_ready === 1'b0, "audio_ready high while reset is asserted");
        check(fast_pa_en === 1'b1, "pa_en low while reset is asserted");
        check(big_ready === 1'b0, "default-dut audio_ready high while reset is asserted");
        check(big_pa_en === 1'b1, "default-dut pa_en low while reset is asserted");

        // ---- 2. 计数逐拍加一 ----
        // 复位在仿真起点就是低电平，异步复位把计数清零；释放复位后的第一个
        // posedge 上计数仍然是 0，后面的每一拍加一。
        rst_n_fast = 1'b1;
        for (n = 0; n < FAST_CYCLES - 1; n = n + 1) begin
            @(posedge clk);
            #1;
            check(fast_ready === 1'b0, "audio_ready asserted too early");
            check(dut_fast.startup_count === (n + 1),
                  "startup_count did not step by one");
        end

        // ---- 3. 边界：第 STARTUP_CYCLES 个 posedge 才放行 ----
        // 循环结束时计数已经等于 STARTUP_CYCLES-1 = 9，此时还不允许放行。
        check(dut_fast.startup_count === (FAST_CYCLES-1),
              "startup_count not at STARTUP_CYCLES-1 before the release edge");
        @(posedge clk);
        #1;
        check(fast_ready === 1'b1,
              "audio_ready did not assert on the STARTUP_CYCLES-th clock edge");
        check(fast_pa_en === 1'b0, "pa_en did not fall when audio_ready rose");
        check(dut_fast.startup_count === 0,
              "startup_count did not return to zero after release");

        // 放行后再走三拍，计数停在 0，audio_ready 不回退。
        for (i = 0; i < 3; i = i + 1) begin
            @(posedge clk);
            #1;
            check(fast_ready === 1'b1, "audio_ready dropped after release");
            check(fast_pa_en === 1'b0, "pa_en rose again after release");
            check(dut_fast.startup_count === 0,
                  "startup_count moved again after release");
        end

        // ---- 4. 复位后重新计时 ----
        rst_n_fast = 1'b0;
        repeat (2) @(posedge clk);
        #1;
        check(fast_ready === 1'b0, "audio_ready not cleared by reset");
        check(fast_pa_en === 1'b1, "pa_en not returned high by reset");
        check(dut_fast.startup_count === 0, "startup_count not cleared by reset");

        rst_n_fast = 1'b1;
        // 重新计时走 FAST_CYCLES-2 拍，计数应为 8，仍不允许放行。
        repeat (FAST_CYCLES - 2) @(posedge clk);
        #1;
        check(fast_ready === 1'b0, "audio_ready asserted too early after reset");
        check(dut_fast.startup_count === (FAST_CYCLES-2),
              "startup_count wrong while recounting");
        // 从计数 8 开始，还需要两拍才放行：一拍计到 9，一拍拉高 audio_ready。
        count_edges_to_ready(FAST_CYCLES, n);
        check(n == 2, "audio_ready did not re-assert exactly at the recount boundary");

        // 再抖一次异步复位，确认负沿立即清零。
        repeat (2) @(negedge clk);
        rst_n_fast = 1'b0;
        #1;
        check(fast_ready === 1'b0, "asynchronous reset did not clear audio_ready");

        // ---- 5. 默认参数实例完成长计数 ----
        rst_n_big = 1'b1;
        repeat (1_000) @(posedge clk);
        #1;
        check(big_ready === 1'b0, "default-dut released before STARTUP_CYCLES");
        check(big_pa_en === 1'b1, "default-dut pa_en fell before STARTUP_CYCLES");
        check(dut_big.startup_count === 1_000,
              "default-dut counter wrong during the long count");
        repeat (BIG_CYCLES - 1_001) @(posedge clk);
        #1;
        check(dut_big.startup_count === (BIG_CYCLES-1),
              "default-dut counter not at STARTUP_CYCLES-1 on the edge before release");
        check(big_ready === 1'b0,
              "default-dut released one clock earlier than STARTUP_CYCLES");
        @(posedge clk);
        #1;
        check(big_ready === 1'b1,
              "default-dut did not release after 5_000_000 clocks");
        check(big_pa_en === 1'b0, "default-dut pa_en did not fall");
        check(dut_big.startup_count === 0, "default-dut counter not cleared");

        if (errors == 0)
            $display("PASS: audio_startup mute window, exact release edge, reset recount, 5M-cycle release");
        else
            $display("FAIL %0d checks did not pass", errors);
        $finish;
    end

    initial begin
        #400_000_000;
        $display("FAIL timeout");
        $finish;
    end

    wire test_pass = (errors == 0);
endmodule

`default_nettype wire
