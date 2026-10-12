`timescale 1ns/1ps
// voice_allocator_4 单元测试：空闲槽位分配、同键重启、释音槽位复用、轮询抢占、复位。
//
// 抢占策略从 rtl/polyphony/voice_allocator_4.sv 读出：
//   第 78～85 行   同一个键仍在某个声部上时，重启该声部；
//   第 88～93 行   否则取编号最小的未分配槽位；
//   第 94～99 行   否则取编号最小的未开门槽位，也就是正在释音的声部；
//   第 102～103 行 以上都不成立时取 steal_pointer 指向的声部，这一步才是抢占；
//   第 109 行      每个事件之后 steal_pointer 指向 selected_voice+1，声部 3 之后回到 0。
// 从复位开始连续分配满四个声部时，指针依次经过 0、1、2、3 又回到 0，
// 所以第 5、6、7、8、9 个事件依次抢占声部 0、1、2、3、0。
//
// 采样方式：每个 posedge 之后 #1 读输出，逐位比较 voice_keys、voice_gate、
// voice_assigned、voice_trigger。voice_idle 由测试台显式给出，默认全 0，
// 表示四个包络都还在发声；需要测试释音回收时才拉起对应位一个时钟。
//
// 不检查：KEY_COUNT 取 13 以外数值时的行为、时钟频率、按键消抖。
//
// $display 文字保持英文，这个 ModelSim 版本的控制台显示中文会乱码。
`default_nettype none

module tb_voice_allocator_4;
    localparam integer CLK_PERIOD = 10;

    reg clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    reg rst_n = 1'b0;
    reg [12:0] key_on_pulse = 13'd0;
    reg [12:0] key_off_pulse = 13'd0;
    reg [3:0] voice_idle = 4'b0000;

    wire [3:0] voice_gate;
    wire [3:0] voice_assigned;
    wire [3:0] voice_trigger;
    wire [15:0] voice_keys;

    voice_allocator_4 #(.KEY_COUNT(13), .KEY_INDEX_WIDTH(4)) dut (
        .clk(clk),
        .rst_n(rst_n),
        .key_on_pulse(key_on_pulse),
        .key_off_pulse(key_off_pulse),
        .voice_idle(voice_idle),
        .voice_gate(voice_gate),
        .voice_assigned(voice_assigned),
        .voice_trigger(voice_trigger),
        .voice_keys(voice_keys)
    );

    integer errors = 0;
    integer k;
    integer n;
    integer expected_mask;

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

    function [3:0] key_of;
        input integer v;
        begin
            key_of = voice_keys[v*4 +: 4];
        end
    endfunction

    // 走一个时钟，停在上升沿之后 1 ns，此时寄存器输出已经稳定。
    task step_clk;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    // 在上升沿之前拉高对应的事件位，只保持这一个时钟。
    task press_keys;
        input [12:0] mask;
        begin
            @(negedge clk);
            key_on_pulse = mask;
            @(posedge clk);
            #1;
            key_on_pulse = 13'd0;
        end
    endtask

    task release_keys;
        input [12:0] mask;
        begin
            @(negedge clk);
            key_off_pulse = mask;
            @(posedge clk);
            #1;
            key_off_pulse = 13'd0;
        end
    endtask

    // 让指定声部的包络空闲标志保持一个时钟，模拟包络归零。
    task idle_pulse;
        input [3:0] mask;
        begin
            @(negedge clk);
            voice_idle = mask;
            @(posedge clk);
            #1;
            voice_idle = 4'b0000;
        end
    endtask

    initial begin
        // ---- 1. 复位之后所有状态为零 ----
        repeat (3) @(negedge clk);
        #1;
        check(voice_gate === 4'b0000, "gate not cleared by reset");
        check(voice_assigned === 4'b0000, "assigned not cleared by reset");
        check(voice_trigger === 4'b0000, "trigger not cleared by reset");
        check(voice_keys === 16'h0000, "voice_keys not cleared by reset");
        check(dut.steal_pointer === 2'd0, "steal_pointer not cleared by reset");
        check(dut.pending_on === 13'd0, "pending_on not cleared by reset");

        rst_n = 1'b1;
        step_clk();

        // ---- 2. 依次按下 4 个键，每个键分到不同的空闲声部 ----
        for (k = 0; k < 4; k = k + 1) begin
            press_keys(13'd1 << k);
            expected_mask = (1 << (k + 1)) - 1;
            check(voice_assigned === expected_mask[3:0],
                  "sequential press gave the wrong assigned mask");
            check(voice_gate === expected_mask[3:0],
                  "sequential press gave the wrong gate mask");
            check(voice_trigger === (4'd1 << k),
                  "sequential press raised trigger on the wrong voice");
            check(key_of(k) === k,
                  "sequential press did not take the next free voice");
            step_clk();
            check(voice_trigger === 4'b0000, "trigger stayed high for more than one clock");
        end
        check(voice_keys[15:0] === 16'h3210,
              "four keys were not mapped to voices 0..3 in press order");

        // ---- 3. 第 5 个事件：四个声部全满，抢占指针指向声部 0 ----
        press_keys(13'd1 << 4);
        check(voice_assigned === 4'b1111, "fifth press dropped a voice slot");
        check(voice_gate === 4'b1111, "fifth press changed the gate mask");
        check(key_of(0) === 4'd4, "fifth press did not steal voice 0");
        check(key_of(0) !== 4'd0, "stolen key 0 is still stored in the voice map");
        check(key_of(1) === 4'd1 && key_of(2) === 4'd2 && key_of(3) === 4'd3,
              "steal changed a voice that should have been kept");
        check(voice_trigger === 4'b0001, "steal did not raise trigger on voice 0");
        step_clk();
        check(voice_trigger === 4'b0000, "trigger stayed high after a steal");

        // ---- 4. 继续按键，抢占指针轮转 1、2、3，再回到 0 ----
        press_keys(13'd1 << 5);
        check(key_of(1) === 4'd5 && voice_trigger === 4'b0010,
              "sixth press did not steal voice 1");
        press_keys(13'd1 << 6);
        check(key_of(2) === 4'd6 && voice_trigger === 4'b0100,
              "seventh press did not steal voice 2");
        press_keys(13'd1 << 7);
        check(key_of(3) === 4'd7 && voice_trigger === 4'b1000,
              "eighth press did not steal voice 3");
        press_keys(13'd1 << 8);
        check(key_of(0) === 4'd8 && voice_trigger === 4'b0001,
              "ninth press did not wrap the steal pointer back to voice 0");
        check(voice_assigned === 4'b1111 && voice_gate === 4'b1111,
              "steal left a voice slot idle");
        step_clk();

        // ---- 5. 异步复位清掉正在发声的和弦 ----
        rst_n = 1'b0;
        repeat (2) @(negedge clk);
        #1;
        check(voice_gate === 4'b0000 && voice_assigned === 4'b0000,
              "asynchronous reset did not clear a sounding chord");
        check(voice_keys === 16'h0000, "asynchronous reset did not clear the voice map");
        rst_n = 1'b1;
        step_clk();

        // ---- 6. 同一拍按下 5 个键：按键号从小到大逐个处理 ----
        press_keys(13'b0000000011111);
        check(key_of(0) === 4'd0, "queued event 0 was not processed first");
        step_clk();
        check(key_of(1) === 4'd1, "queued events were not consumed in key order");
        step_clk();
        check(key_of(2) === 4'd2, "queued events were not consumed in key order");
        step_clk();
        check(key_of(3) === 4'd3, "queued events were not consumed in key order");
        step_clk();
        check(key_of(0) === 4'd4, "fifth queued event did not steal voice 0");
        check(key_of(1) === 4'd1 && key_of(2) === 4'd2 && key_of(3) === 4'd3,
              "fifth queued event disturbed the other voices");
        check(voice_trigger === 4'b0001, "fifth queued event raised trigger elsewhere");

        // ---- 7. 松键只关闭本声部，包络归零后槽位可以被重新分配 ----
        release_keys(13'd1 << 1);
        check(voice_gate === 4'b1101, "key off did not close voice 1 alone");
        check(voice_assigned === 4'b1111,
              "voice slot was released before the envelope reached zero");
        check(key_of(1) === 4'd1, "key off erased the voice key too early");
        idle_pulse(4'b0010);
        check(voice_assigned === 4'b1101, "idle voice was not returned to the free pool");
        check(voice_gate === 4'b1101, "gate changed while recycling an idle voice");
        press_keys(13'd1 << 9);
        check(key_of(1) === 4'd9, "recycled slot was not handed to the next key");
        check(voice_trigger === 4'b0010, "trigger was not raised on the recycled slot");
        check(voice_assigned === 4'b1111 && voice_gate === 4'b1111,
              "recycled slot did not reopen");
        check(key_of(0) === 4'd4 && key_of(2) === 4'd2 && key_of(3) === 4'd3,
              "recycling disturbed a sounding voice");

        // ---- 8. 四个槽位都被占用时，正在释音的声部优先于抢占 ----
        release_keys(13'd1 << 9);
        check(voice_gate === 4'b1101 && voice_assigned === 4'b1111,
              "releasing voice 1 was returned to the free pool too early");
        press_keys(13'd1 << 10);
        check(key_of(1) === 4'd10, "new key did not reuse the releasing voice");
        check(voice_trigger === 4'b0010, "trigger was not raised on the reused voice");
        check(voice_gate === 4'b1111 && voice_assigned === 4'b1111,
              "reused voice was not reopened");
        check(key_of(0) === 4'd4 && key_of(2) === 4'd2 && key_of(3) === 4'd3,
              "reusing a releasing voice disturbed a sounding voice");

        // ---- 9. 同键在释音期间再次按下，重启原声部而不是占用空闲声部 ----
        rst_n = 1'b0;
        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        step_clk();
        press_keys(13'd1 << 7);
        press_keys(13'd1 << 8);
        press_keys(13'd1 << 9);
        check(voice_assigned === 4'b0111 && voice_gate === 4'b0111,
              "three presses were not placed in voices 0..2");
        check(key_of(0) === 4'd7 && key_of(1) === 4'd8 && key_of(2) === 4'd9,
              "three presses were mapped to the wrong voices");
        release_keys(13'd1 << 8);
        check(voice_gate === 4'b0101 && voice_assigned === 4'b0111,
              "releasing key 8 closed the wrong voices");
        press_keys(13'd1 << 8);
        check(key_of(1) === 4'd8, "re-pressed key did not restart its own voice");
        check(voice_trigger === 4'b0010, "trigger was not raised on the restarted voice");
        check(voice_gate === 4'b0111 && voice_assigned === 4'b0111,
              "restart changed the voice mask");
        check(voice_assigned[3] === 1'b0,
              "restart consumed free voice 3 instead of the voice holding the key");

        // ---- 10. 从未使用的槽位优先于正在释音的槽位 ----
        rst_n = 1'b0;
        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        step_clk();
        press_keys(13'd1 << 0);
        release_keys(13'd1 << 0);
        check(voice_assigned === 4'b0001 && voice_gate === 4'b0000,
              "releasing voice 0 was dropped from the assigned map");
        press_keys(13'd1 << 1);
        check(key_of(1) === 4'd1, "never used voice 1 was not preferred");
        check(key_of(0) === 4'd0 && voice_trigger === 4'b0010,
              "releasing voice 0 was reused before the never used voice 1");

        // ---- 11. 门还开着时 voice_idle 不能让槽位被回收 ----
        idle_pulse(4'b1111);
        check(voice_assigned === 4'b0010,
              "voice_idle recycled a slot whose gate is still open");
        check(voice_gate === 4'b0010, "voice_idle closed an open gate");

        // ---- 12. 排队期间复位，剩下的事件不再被处理 ----
        rst_n = 1'b0;
        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        step_clk();
        press_keys(13'b0000000000011);
        check(key_of(0) === 4'd0, "first of two same-cycle events was not processed");
        check(dut.pending_on[1] === 1'b1, "second same-cycle event was not queued");
        rst_n = 1'b0;
        #1;
        check(dut.pending_on === 13'd0, "asynchronous reset did not clear the queue");
        check(voice_assigned === 4'b0000 && voice_gate === 4'b0000,
              "asynchronous reset did not clear the assigned voices");
        repeat (2) @(negedge clk);
        rst_n = 1'b1;
        repeat (4) @(posedge clk);
        #1;
        check(voice_assigned === 4'b0000 && key_of(0) === 4'd0,
              "queued event survived the reset");

        if (errors == 0)
            $display("PASS: voice_allocator_4 free-slot assignment, same-key restart, releasing-slot reuse, round-robin steal, reset");
        else
            $display("FAIL %0d checks did not pass", errors);
        $finish;
    end

    initial begin
        #1_000_000;
        $display("FAIL timeout");
        $finish;
    end

    wire test_pass = (errors == 0);
endmodule

`default_nettype wire
