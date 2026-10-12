`timescale 1ns/1ps
// 整理这个仓库时补写的校验 testbench。
//
// 背景：原工程的 tb_mcp3208_dual_scan 和 MCP3208 行为模型放在 tests/ 下，
// 没有随工程保留下来，所以这个扫描器一直只有"能编译"这一条结论。
// 这里补一个不需要模拟模型的检查。
//
// 它检查两件事：
//   1) MOSI 上那 24 位命令帧。在 SCLK 上升沿采样 MOSI——这和真实
//      MCP3208（mode 0/0）的做法一样，所以它检验的是"命令帧能不能
//      被从机读懂"，而不只是"内部移位寄存器看起来对"。
//
//   2) 采样捕获路径。把 mcp0_miso 恒接 1、mcp1_miso 恒接 0，那么
//      无论采到哪一位，第一片的 8 个通道都必须是 12'hFFF，
//      第二片都必须是 12'h000。这能查出位序反了、位宽错了、
//      通道槽位串了。恒接常量是故意的：
//      这样就完全绕开了"从机在第几个边沿输出哪一位"的建模。
//
// 不检查：模拟电压、VREF、成品模块的 DOUT 电平特性，
// 以及真实 MCP3208 的建立/保持余量。
//
// 注意：$display 的提示文字故意保持英文——这个 ModelSim 版本会把
// 控制台里的非 ASCII 文本弄成乱码。
`default_nettype none
module tb_mcp3208_scan;
    localparam integer HALF_PERIOD = 4;   // 比 50 MHz 的半周期短一些，让仿真跑得快
    localparam integer RUN_CLOCKS  = 120_000;

    reg clk = 1'b0;
    always #10 clk = ~clk;                // 50 MHz

    reg rst_n = 1'b0;

    wire        mcp_sclk, mcp_mosi, mcp0_cs_n, mcp1_cs_n;
    wire [95:0] samples0, samples1;
    wire        frame_valid, ready, fault;

    mcp3208_dual_scan #(.HALF_PERIOD(HALF_PERIOD)) dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .mcp0_miso  (1'b1),
        .mcp1_miso  (1'b0),
        .mcp_sclk   (mcp_sclk),
        .mcp_mosi   (mcp_mosi),
        .mcp0_cs_n  (mcp0_cs_n),
        .mcp1_cs_n  (mcp1_cs_n),
        .samples0   (samples0),
        .samples1   (samples1),
        .frame_valid(frame_valid),
        .ready      (ready),
        .fault      (fault)
    );

    // ---- 命令帧检查 ---------------------------------------------------
    // 转换顺序：第一片 CH0..CH7，然后第二片 CH0..CH7，之后循环。
    reg [4:0]  conv_idx = 5'd0;
    reg [4:0]  mosi_cnt = 5'd0;
    reg [23:0] cmd_rx   = 24'd0;
    integer    cmd_errors  = 0;
    integer    cmd_checked = 0;

    wire [2:0]  exp_ch    = conv_idx[2:0];
    wire        exp_chip  = conv_idx[3];
    wire [7:0]  exp_first = 8'h06 | (exp_ch[2] ? 8'h01 : 8'h00);
    wire [23:0] exp_cmd   = {exp_first, exp_ch[1:0], 6'b0, 8'h00};
    wire [23:0] cmd_now   = {cmd_rx[22:0], mcp_mosi};

    always @(posedge mcp_sclk) begin
        cmd_rx   <= cmd_now;
        mosi_cnt <= mosi_cnt + 5'd1;
        if (mosi_cnt == 5'd23) begin
            cmd_checked = cmd_checked + 1;
            if (cmd_now !== exp_cmd) begin
                cmd_errors = cmd_errors + 1;
                if (cmd_errors <= 4)
                    $display("FAIL cmd frame conv=%0d chip=%0d ch=%0d got=%06h exp=%06h",
                             conv_idx, exp_chip, exp_ch, cmd_now, exp_cmd);
            end
            mosi_cnt <= 5'd0;
            conv_idx <= conv_idx + 5'd1;
        end
    end

    // ---- frame_valid / ready 计数 -------------------------------------
    integer frames = 0;
    always @(posedge clk) if (rst_n && frame_valid) frames = frames + 1;

    // ---- 主流程 -------------------------------------------------------
    integer errors = 0;
    integer i;
    reg [11:0] code;

    initial begin
        repeat (5) @(negedge clk);
        rst_n = 1'b1;
        repeat (RUN_CLOCKS) @(posedge clk);

        if (cmd_checked < 32) begin
            errors = errors + 1;
            $display("FAIL too few command frames captured (%0d); the scan never ran", cmd_checked);
        end
        if (cmd_errors != 0) begin
            errors = errors + 1;
            $display("FAIL %0d bad command frames out of %0d", cmd_errors, cmd_checked);
        end

        for (i = 0; i < 8; i = i + 1) begin
            code = samples0[i*12 +: 12];
            if (code !== 12'hFFF) begin
                errors = errors + 1;
                $display("FAIL samples0 channel %0d = %03h, expected FFF", i, code);
            end
        end

        for (i = 0; i < 8; i = i + 1) begin
            code = samples1[i*12 +: 12];
            if (code !== 12'h000) begin
                errors = errors + 1;
                $display("FAIL samples1 channel %0d = %03h, expected 000", i, code);
            end
        end

        if (frames < 12) begin
            errors = errors + 1;
            $display("FAIL frame_valid pulsed only %0d times, expected one per full round", frames);
        end
        if (ready !== 1'b1) begin
            errors = errors + 1;
            $display("FAIL ready never asserted");
        end
        if (fault !== 1'b0) begin
            errors = errors + 1;
            $display("FAIL fault asserted unexpectedly");
        end

        if (errors == 0)
            $display("PASS: 24-bit command frames, 16-channel capture and frame_valid handshake");
        else
            $display("FAIL %0d checks did not pass", errors);

        $finish;
    end

    initial begin
        #50_000_000;
        $display("FAIL timeout");
        $finish;
    end

    wire test_pass = (errors == 0);
endmodule
`default_nettype wire
