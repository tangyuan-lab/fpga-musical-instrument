`timescale 1ns/1ps
// 压力键矩阵单元测试。
//
// 覆盖内容：64 帧基线校准、按下判定、力度随压力单调变化、16/8 迟滞、
// 松开事件、adc_ready 掉线保护、多键并行。
//
// 做法：testbench 里另写一份参考模型（滤波步进、迟滞判定、力度映射、
// 掉线清除），每送一帧采样就把模型算出的下一状态与 DUT 输出逐项比较。
// RTL 里阈值、移位、校准帧数或事件时序写错，比较就会失败，test_pass 变 0。
//
// 参考模型的步进规则按 RTL 的实际算法写成：每帧向目标移动
// ceil(差值 / 4)，也就是 RTL 里 (difference + 3) >> 2 的效果。
//
// $display 的提示文字保持英文，这个 ModelSim 版本会把控制台里的非 ASCII
// 文本弄成乱码；中文只出现在注释里。
`default_nettype none
module tb_pressure_key_matrix;
    localparam integer KEY_COUNT           = 13;
    localparam integer ADC_BITS            = 12;
    localparam integer CALIBRATION_SAMPLES = 64;
    localparam integer FILTER_SHIFT        = 2;
    localparam [ADC_BITS-1:0] PRESS_ON     = 12'd16;
    localparam [ADC_BITS-1:0] PRESS_OFF    = 12'd8;
    localparam [ADC_BITS-1:0] PRESS_FULL   = 12'd2048;
    localparam [KEY_COUNT-1:0] ACTIVE_LOW_MASK = {KEY_COUNT{1'b1}};

    localparam integer CLK_HALF = 10;      // 50 MHz

    // ---- 时钟与 DUT ---------------------------------------------------
    reg clk = 1'b0;
    always #CLK_HALF clk = ~clk;

    reg rst_n = 1'b0;

    reg                              adc_ready          = 1'b0;
    reg                              sample_frame_valid = 1'b0;
    reg  [KEY_COUNT*ADC_BITS-1:0]    adc_samples        = {(KEY_COUNT*ADC_BITS){1'b0}};
    wire                             calibrated;
    wire [KEY_COUNT*ADC_BITS-1:0]    baseline_values;
    wire [KEY_COUNT*ADC_BITS-1:0]    pressure_values;
    wire [KEY_COUNT*8-1:0]           velocity_values;
    wire [KEY_COUNT-1:0]             key_down;
    wire [KEY_COUNT-1:0]             key_on_pulse;
    wire [KEY_COUNT-1:0]             key_off_pulse;
    wire [$clog2(KEY_COUNT+1)-1:0]   active_key_count;

    pressure_key_matrix #(
        .KEY_COUNT           (KEY_COUNT),
        .ADC_BITS            (ADC_BITS),
        .CALIBRATION_SAMPLES (CALIBRATION_SAMPLES),
        .FILTER_SHIFT        (FILTER_SHIFT),
        .PRESS_ON            (PRESS_ON),
        .PRESS_OFF           (PRESS_OFF),
        .PRESS_FULL          (PRESS_FULL),
        .ACTIVE_LOW_MASK     (ACTIVE_LOW_MASK)
    ) dut (
        .clk                (clk),
        .rst_n              (rst_n),
        .adc_ready          (adc_ready),
        .sample_frame_valid (sample_frame_valid),
        .adc_samples        (adc_samples),
        .calibrated         (calibrated),
        .baseline_values    (baseline_values),
        .pressure_values    (pressure_values),
        .velocity_values    (velocity_values),
        .key_down           (key_down),
        .key_on_pulse       (key_on_pulse),
        .key_off_pulse      (key_off_pulse),
        .active_key_count   (active_key_count)
    );

    // ---- 事件脉冲计数 -------------------------------------------------
    // 在下降沿采样脉冲。脉冲由 DUT 在上升沿置起，下一个上升沿清零，
    // 因此在每个时钟的下降沿读到 1 就代表这一帧发生了一次事件。
    // 若某次脉冲被拉宽到两个时钟，这里会数到两次，比较逻辑也会报错。
    integer on_pulse_cnt  [0:KEY_COUNT-1];
    integer off_pulse_cnt [0:KEY_COUNT-1];
    integer kk;
    always @(negedge clk) begin
        if (rst_n) begin
            for (kk = 0; kk < KEY_COUNT; kk = kk + 1) begin
                if (key_on_pulse[kk])  on_pulse_cnt[kk]  = on_pulse_cnt[kk] + 1;
                if (key_off_pulse[kk]) off_pulse_cnt[kk] = off_pulse_cnt[kk] + 1;
            end
        end
    end

    // ---- 参考模型用到的纯函数 -----------------------------------------
    // 静止基线：每个键给一个互不相同的码值，这样总线槽位串了也能查出来。
    function automatic integer base_code(input integer idx);
        base_code = 2600 + 16*idx;
    endfunction

    // 一阶低通的单帧步进，与 RTL 的 filter_step 同一规则。
    function automatic [ADC_BITS-1:0] ref_filter;
        input [ADC_BITS-1:0] old_value;
        input [ADC_BITS-1:0] new_value;
        integer diff;
        begin
            if (new_value > old_value) begin
                diff = new_value - old_value;
                ref_filter = old_value + ((diff + 3) >> FILTER_SHIFT);
            end else if (old_value > new_value) begin
                diff = old_value - new_value;
                ref_filter = old_value - ((diff + 3) >> FILTER_SHIFT);
            end else begin
                ref_filter = old_value;
            end
        end
    endfunction

    // 压力到 8 位力度的映射。PRESS_FULL 时饱和到 255，PRESS_ON 以下为 0。
    function automatic [7:0] ref_velocity;
        input [ADC_BITS-1:0] pressure;
        integer delta;
        begin
            if (pressure <= PRESS_ON)
                ref_velocity = 8'd0;
            else if (pressure >= PRESS_FULL)
                ref_velocity = 8'hff;
            else begin
                delta = pressure - PRESS_ON;
                ref_velocity = (delta >> 3) & 8'hff;
            end
        end
    endfunction

    function automatic integer pulse_on_total;
        integer idx;
        begin
            pulse_on_total = 0;
            for (idx = 0; idx < KEY_COUNT; idx = idx + 1)
                pulse_on_total = pulse_on_total + on_pulse_cnt[idx];
        end
    endfunction

    function automatic integer pulse_off_total;
        integer idx;
        begin
            pulse_off_total = 0;
            for (idx = 0; idx < KEY_COUNT; idx = idx + 1)
                pulse_off_total = pulse_off_total + off_pulse_cnt[idx];
        end
    endfunction

    // ---- 参考模型状态 -------------------------------------------------
    reg [ADC_BITS-1:0] m_base      [0:KEY_COUNT-1];
    reg [ADC_BITS-1:0] m_filt      [0:KEY_COUNT-1];
    reg                m_down      [0:KEY_COUNT-1];
    integer            m_sum       [0:KEY_COUNT-1];
    integer            m_cal_count;
    reg                m_calibrated;

    reg [ADC_BITS-1:0] m_base_next [0:KEY_COUNT-1];
    reg [ADC_BITS-1:0] m_filt_next [0:KEY_COUNT-1];
    reg [7:0]          m_vel_next  [0:KEY_COUNT-1];
    reg                m_down_next [0:KEY_COUNT-1];
    reg                m_on_next   [0:KEY_COUNT-1];
    reg                m_off_next  [0:KEY_COUNT-1];
    integer            m_count_next;
    reg                m_cal_next;

    // ---- 本帧驱动值 ---------------------------------------------------
    reg [ADC_BITS-1:0] sample_now [0:KEY_COUNT-1];   // 实际送到 DUT 的 ADC 码
    reg [ADC_BITS-1:0] sample_drv [0:KEY_COUNT-1];   // drive_mode=0 时直接使用
    integer            press_drv  [0:KEY_COUNT-1];   // drive_mode=1 时表示期望压力
    integer            drive_mode;                   // 0 直接给码值，1 基线减压力

    integer errors;
    integer step_no;
    integer i, f, k;

    // 每段测试开始前记录脉冲计数，用增量判断事件次数。
    integer on_before  [0:KEY_COUNT-1];
    integer off_before [0:KEY_COUNT-1];
    integer on_total_before;
    integer off_total_before;
    integer on_total_mid;

    // ---- 检查辅助 -----------------------------------------------------
    task automatic count_error;
        input [8*24-1:0] what;
        input integer    step;
        input integer    key;
        input integer    got;
        input integer    expected;
        begin
            errors = errors + 1;
            if (errors <= 25)
                $display("FAIL %0s step %0d key %0d: got %0d expected %0d",
                         what, step, key, got, expected);
        end
    endtask

    task automatic check_eq;
        input [8*48-1:0] what;
        input integer    got;
        input integer    expected;
        begin
            if (got !== expected) begin
                errors = errors + 1;
                $display("FAIL %0s: got %0d expected %0d (step %0d time %0t)",
                         what, got, expected, step_no, $time);
            end
        end
    endtask

    task automatic save_pulse_counts;
        integer idx;
        begin
            for (idx = 0; idx < KEY_COUNT; idx = idx + 1) begin
                on_before[idx]  = on_pulse_cnt[idx];
                off_before[idx] = off_pulse_cnt[idx];
            end
            on_total_before  = pulse_on_total();
            off_total_before = pulse_off_total();
        end
    endtask

    task automatic clear_press;
        integer idx;
        begin
            for (idx = 0; idx < KEY_COUNT; idx = idx + 1)
                press_drv[idx] = 0;
        end
    endtask

    task automatic set_press;
        input integer idx;
        input integer value;
        begin
            press_drv[idx] = value;
        end
    endtask

    // ---- 参考模型：状态推进 -------------------------------------------
    task automatic model_reset;
        integer idx;
        begin
            for (idx = 0; idx < KEY_COUNT; idx = idx + 1) begin
                m_base[idx]      = {ADC_BITS{1'b0}};
                m_filt[idx]      = {ADC_BITS{1'b0}};
                m_down[idx]      = 1'b0;
                m_sum[idx]       = 0;
                m_base_next[idx] = {ADC_BITS{1'b0}};
                m_filt_next[idx] = {ADC_BITS{1'b0}};
                m_vel_next[idx]  = 8'd0;
                m_down_next[idx] = 1'b0;
                m_on_next[idx]   = 1'b0;
                m_off_next[idx]  = 1'b0;
                on_pulse_cnt[idx]  = 0;
                off_pulse_cnt[idx] = 0;
            end
            m_cal_count  = 0;
            m_calibrated = 1'b0;
            m_cal_next   = 1'b0;
            m_count_next = 0;
        end
    endtask

    // 一帧有效采样（adc_ready 与 sample_frame_valid 同时为高）后的下一状态。
    task automatic model_frame_step;
        integer idx;
        integer raw;
        begin
            for (idx = 0; idx < KEY_COUNT; idx = idx + 1) begin
                if (!m_calibrated) begin
                    // 校准阶段只累加，不滤波也不判键。
                    if (m_cal_count == CALIBRATION_SAMPLES-1)
                        m_base_next[idx] = (m_sum[idx] + sample_now[idx]) >> 6;
                    else begin
                        m_base_next[idx] = m_base[idx];
                        m_sum[idx]       = m_sum[idx] + sample_now[idx];
                    end
                    m_filt_next[idx] = {ADC_BITS{1'b0}};
                    m_vel_next[idx]  = 8'd0;
                    m_down_next[idx] = 1'b0;
                    m_on_next[idx]   = 1'b0;
                    m_off_next[idx]  = 1'b0;
                end else begin
                    m_base_next[idx] = m_base[idx];
                    raw = (m_base[idx] > sample_now[idx]) ?
                          (m_base[idx] - sample_now[idx]) : 0;
                    m_filt_next[idx] = ref_filter(m_filt[idx], raw[ADC_BITS-1:0]);
                    m_vel_next[idx]  = ref_velocity(m_filt_next[idx]);
                    if (!m_down[idx] && (m_filt_next[idx] >= PRESS_ON)) begin
                        m_down_next[idx] = 1'b1;
                        m_on_next[idx]   = 1'b1;
                        m_off_next[idx]  = 1'b0;
                    end else if (m_down[idx] && (m_filt_next[idx] <= PRESS_OFF)) begin
                        m_down_next[idx] = 1'b0;
                        m_on_next[idx]   = 1'b0;
                        m_off_next[idx]  = 1'b1;
                    end else begin
                        m_down_next[idx] = m_down[idx];
                        m_on_next[idx]   = 1'b0;
                        m_off_next[idx]  = 1'b0;
                    end
                end
            end
            if (m_cal_count == CALIBRATION_SAMPLES-1) begin
                m_cal_next   = 1'b1;
                m_count_next = m_cal_count;
            end else begin
                m_cal_next   = m_calibrated;
                m_count_next = m_cal_count + 1;
            end
        end
    endtask

    // adc_ready 掉线：门控全部清除，并为仍按下的键产生一次释音。
    task automatic model_dropout_step;
        integer idx;
        begin
            for (idx = 0; idx < KEY_COUNT; idx = idx + 1) begin
                m_base_next[idx] = m_base[idx];
                m_filt_next[idx] = {ADC_BITS{1'b0}};
                m_vel_next[idx]  = 8'd0;
                m_down_next[idx] = 1'b0;
                m_on_next[idx]   = 1'b0;
                m_off_next[idx]  = m_down[idx];
            end
            m_cal_next   = m_calibrated;
            m_count_next = m_cal_count;
        end
    endtask

    // 无有效帧：状态保持，事件脉冲清零。
    task automatic model_hold_step;
        integer idx;
        begin
            for (idx = 0; idx < KEY_COUNT; idx = idx + 1) begin
                m_base_next[idx] = m_base[idx];
                m_filt_next[idx] = m_filt[idx];
                m_vel_next[idx]  = ref_velocity(m_filt[idx]);
                m_down_next[idx] = m_down[idx];
                m_on_next[idx]   = 1'b0;
                m_off_next[idx]  = 1'b0;
            end
            m_cal_next   = m_calibrated;
            m_count_next = m_cal_count;
        end
    endtask

    task automatic model_idle_step;
        input integer ready_level;
        begin
            if (m_calibrated && (ready_level == 0))
                model_dropout_step;
            else
                model_hold_step;
        end
    endtask

    task automatic model_commit;
        integer idx;
        begin
            for (idx = 0; idx < KEY_COUNT; idx = idx + 1) begin
                m_base[idx] = m_base_next[idx];
                m_filt[idx] = m_filt_next[idx];
                m_down[idx] = m_down_next[idx];
            end
            m_calibrated = m_cal_next;
            m_cal_count  = m_count_next;
        end
    endtask

    // 把 DUT 的全部输出与模型比较。
    task automatic compare_all;
        integer idx;
        integer exp_active;
        begin
            exp_active = 0;
            for (idx = 0; idx < KEY_COUNT; idx = idx + 1) begin
                if (m_down_next[idx])
                    exp_active = exp_active + 1;

                if (baseline_values[idx*ADC_BITS +: ADC_BITS] !== m_base_next[idx])
                    count_error("baseline", step_no, idx,
                                baseline_values[idx*ADC_BITS +: ADC_BITS], m_base_next[idx]);
                if (pressure_values[idx*ADC_BITS +: ADC_BITS] !== m_filt_next[idx])
                    count_error("pressure", step_no, idx,
                                pressure_values[idx*ADC_BITS +: ADC_BITS], m_filt_next[idx]);
                if (velocity_values[idx*8 +: 8] !== m_vel_next[idx])
                    count_error("velocity", step_no, idx,
                                velocity_values[idx*8 +: 8], m_vel_next[idx]);
                if (key_down[idx] !== m_down_next[idx])
                    count_error("key_down", step_no, idx, key_down[idx], m_down_next[idx]);
                if (key_on_pulse[idx] !== m_on_next[idx])
                    count_error("key_on_pulse", step_no, idx, key_on_pulse[idx], m_on_next[idx]);
                if (key_off_pulse[idx] !== m_off_next[idx])
                    count_error("key_off_pulse", step_no, idx, key_off_pulse[idx], m_off_next[idx]);
            end
            if (active_key_count !== exp_active)
                count_error("active_key_count", step_no, -1, active_key_count, exp_active);
            if (calibrated !== m_cal_next)
                count_error("calibrated", step_no, -1, calibrated, m_cal_next);
        end
    endtask

    // ---- 驱动与核对 ---------------------------------------------------
    // 送一帧有效采样：adc_ready 与 sample_frame_valid 同为一个时钟的高电平。
    task automatic step_frame;
        integer idx;
        begin
            for (idx = 0; idx < KEY_COUNT; idx = idx + 1) begin
                if (drive_mode == 0)
                    sample_now[idx] = sample_drv[idx];
                else
                    sample_now[idx] = base_code(idx) - press_drv[idx];
                adc_samples[idx*ADC_BITS +: ADC_BITS] = sample_now[idx];
            end
            adc_ready          = 1'b1;
            sample_frame_valid = 1'b1;
            @(posedge clk);
            #1;
            sample_frame_valid = 1'b0;
            @(negedge clk);
            #1;
            step_no = step_no + 1;
            model_frame_step;
            compare_all;
            model_commit;
        end
    endtask

    // 保持采样总线不变，推进若干时钟。ready_level 决定 adc_ready 的电平。
    task automatic hold_cycles;
        input integer ready_level;
        input integer cycles;
        integer idx;
        begin
            sample_frame_valid = 1'b0;
            adc_ready          = (ready_level != 0);
            for (idx = 0; idx < cycles; idx = idx + 1) begin
                @(posedge clk);
                #1;
                @(negedge clk);
                #1;
                step_no = step_no + 1;
                model_idle_step(ready_level);
                compare_all;
                model_commit;
            end
        end
    endtask

    // 让模型与被测模块从同一个起点出发。
    task automatic apply_reset;
        begin
            rst_n = 1'b0;
            repeat (4) @(negedge clk);
            model_reset;
            rst_n = 1'b1;
            @(negedge clk);
            #1;
        end
    endtask

    // ---- 主流程 -------------------------------------------------------
    integer press_seen, press_frame;
    integer ramp_val [0:5];
    integer vel_rec  [0:5];
    integer all_down;
    integer stall_held;
    integer clean;

    initial begin
        errors   = 0;
        step_no  = 0;
        drive_mode = 1;
        clear_press;
        for (k = 0; k < KEY_COUNT; k = k + 1)
            sample_drv[k] = {ADC_BITS{1'b0}};

        apply_reset;

        // [0] 复位后的默认输出
        check_eq("reset calibrated", calibrated, 0);
        check_eq("reset key_down", key_down, 0);
        check_eq("reset velocity", velocity_values, 0);
        check_eq("reset active_key_count", active_key_count, 0);
        check_eq("reset on pulses", pulse_on_total(), 0);
        check_eq("reset off pulses", pulse_off_total(), 0);

        // [1] 基线校准：先送 10 帧，再让 adc_ready 拉低 5 个时钟，
        //     确认校准计数不被无效帧推进，之后补满 64 帧。
        $display("# [1] baseline calibration over %0d static frames", CALIBRATION_SAMPLES);
        drive_mode = 0;
        for (k = 0; k < KEY_COUNT; k = k + 1)
            sample_drv[k] = base_code(k);

        for (f = 0; f < 10; f = f + 1) begin
            step_frame;
            check_eq("calibrated during calibration", calibrated, 0);
        end
        hold_cycles(0, 5);
        check_eq("calibrated after adc_ready low", calibrated, 0);
        for (f = 0; f < CALIBRATION_SAMPLES-11; f = f + 1) begin
            step_frame;
            check_eq("calibrated during calibration", calibrated, 0);
        end
        check_eq("calibrated after 63 accumulating frames", calibrated, 0);
        step_frame;
        check_eq("calibrated after 64 accumulating frames", calibrated, 1);

        for (k = 0; k < KEY_COUNT; k = k + 1)
            check_eq("baseline value", baseline_values[k*ADC_BITS +: ADC_BITS], base_code(k));
        for (k = 0; k < KEY_COUNT; k = k + 1)
            check_eq("key_down during calibration", key_down[k], 0);
        check_eq("on pulses during calibration", pulse_on_total(), 0);

        // [2] 静止基线不误触发；采样高于基线（反方向）也不应触发。
        $display("# [2] static baseline must not trigger");
        drive_mode = 1;
        clear_press;
        for (f = 0; f < 32; f = f + 1)
            step_frame;
        check_eq("active after idle frames", active_key_count, 0);
        check_eq("on pulses after idle frames", pulse_on_total(), 0);

        drive_mode = 0;
        for (k = 0; k < KEY_COUNT; k = k + 1)
            sample_drv[k] = base_code(k) + 30;
        for (f = 0; f < 24; f = f + 1)
            step_frame;
        check_eq("sample above baseline must not press", active_key_count, 0);
        drive_mode = 1;

        // [3] 按下判定与力度
        $display("# [3] press detection and velocity value");
        clear_press;
        set_press(0, 200);
        save_pulse_counts;
        press_seen  = 0;
        press_frame = 0;
        for (f = 0; f < 40; f = f + 1) begin
            step_frame;
            if (!press_seen && key_down[0]) begin
                press_seen  = 1;
                press_frame = step_no;
            end
        end
        check_eq("key0 pressed", key_down[0], 1);
        check_eq("key0 press event seen", press_seen, 1);
        check_eq("key0 pressure converged", pressure_values[0*ADC_BITS +: ADC_BITS], 200);
        check_eq("key0 velocity", velocity_values[0*8 +: 8], 23);
        check_eq("key0 on pulse delta", on_pulse_cnt[0] - on_before[0], 1);
        check_eq("key0 off pulse delta", off_pulse_cnt[0] - off_before[0], 0);
        check_eq("one key active", active_key_count, 1);
        $display("# key0 press detected at step %0d", press_frame);

        clear_press;
        save_pulse_counts;
        for (f = 0; f < 30; f = f + 1)
            step_frame;
        check_eq("key0 released", key_down[0], 0);
        check_eq("key0 off pulse delta after release", off_pulse_cnt[0] - off_before[0], 1);
        check_eq("key0 on pulse delta after release", on_pulse_cnt[0] - on_before[0], 0);
        check_eq("key0 velocity after release", velocity_values[0*8 +: 8], 0);
        check_eq("key0 pressure after release", pressure_values[0*ADC_BITS +: ADC_BITS], 0);
        check_eq("active after release", active_key_count, 0);

        // [4] 压力升高时力度单调不减，并与映射结果一致
        $display("# [4] velocity increases monotonically with pressure");
        ramp_val[0] = 40;   ramp_val[1] = 120;  ramp_val[2] = 400;
        ramp_val[3] = 900;  ramp_val[4] = 1500; ramp_val[5] = 2048;
        clear_press;
        save_pulse_counts;
        for (i = 0; i < 6; i = i + 1) begin
            set_press(1, ramp_val[i]);
            for (f = 0; f < 40; f = f + 1)
                step_frame;
            vel_rec[i] = velocity_values[1*8 +: 8];
            check_eq("ramp pressure converged",
                     pressure_values[1*ADC_BITS +: ADC_BITS], ramp_val[i]);
            check_eq("ramp velocity", vel_rec[i], ref_velocity(ramp_val[i]));
            check_eq("ramp key still down", key_down[1], 1);
        end
        for (i = 1; i < 6; i = i + 1) begin
            if (vel_rec[i] <= vel_rec[i-1]) begin
                errors = errors + 1;
                $display("FAIL velocity not increasing at pressure %0d: %0d <= %0d",
                         ramp_val[i], vel_rec[i], vel_rec[i-1]);
            end
        end
        check_eq("ramp on pulse delta", on_pulse_cnt[1] - on_before[1], 1);
        check_eq("ramp off pulse delta", off_pulse_cnt[1] - off_before[1], 0);

        clear_press;
        for (f = 0; f < 30; f = f + 1)
            step_frame;
        check_eq("key1 released", key_down[1], 0);
        check_eq("key1 off pulse after ramp", off_pulse_cnt[1], 1);

        // [5] 迟滞：16 以上才按下，8 以下才松开，中间来回不抖动
        $display("# [5] press %0d / release %0d hysteresis", PRESS_ON, PRESS_OFF);
        clear_press;
        save_pulse_counts;
        set_press(2, 12);
        for (f = 0; f < 30; f = f + 1)
            step_frame;
        check_eq("below on-threshold not pressed", key_down[2], 0);
        check_eq("pressure settled at 12", pressure_values[2*ADC_BITS +: ADC_BITS], 12);
        check_eq("no on pulse below threshold", on_pulse_cnt[2] - on_before[2], 0);

        set_press(2, 40);
        for (f = 0; f < 24; f = f + 1)
            step_frame;
        check_eq("pressed above on-threshold", key_down[2], 1);
        check_eq("on pulse delta after press", on_pulse_cnt[2] - on_before[2], 1);
        check_eq("velocity at pressure 40", velocity_values[2*8 +: 8], 3);

        set_press(2, 12);
        for (f = 0; f < 24; f = f + 1)
            step_frame;
        check_eq("held between thresholds", key_down[2], 1);
        check_eq("no off pulse between thresholds", off_pulse_cnt[2] - off_before[2], 0);
        check_eq("velocity zero inside band", velocity_values[2*8 +: 8], 0);

        for (i = 0; i < 4; i = i + 1) begin
            set_press(2, 9);
            for (f = 0; f < 6; f = f + 1)
                step_frame;
            set_press(2, 15);
            for (f = 0; f < 6; f = f + 1)
                step_frame;
        end
        check_eq("no chatter across band", key_down[2], 1);
        check_eq("on pulses after chatter", on_pulse_cnt[2] - on_before[2], 1);
        check_eq("off pulses after chatter", off_pulse_cnt[2] - off_before[2], 0);

        set_press(2, 8);
        for (f = 0; f < 24; f = f + 1)
            step_frame;
        check_eq("released at off-threshold", key_down[2], 0);
        check_eq("off pulse delta at release", off_pulse_cnt[2] - off_before[2], 1);
        check_eq("velocity after release", velocity_values[2*8 +: 8], 0);

        clear_press;
        for (f = 0; f < 12; f = f + 1)
            step_frame;
        check_eq("no extra off pulse at zero pressure", off_pulse_cnt[2] - off_before[2], 1);

        // [6] 多键：两个键、三个键、最后 13 键全按下
        $display("# [6] multiple keys at once");
        clear_press;
        set_press(0, 400);
        set_press(3, 1200);
        save_pulse_counts;
        for (f = 0; f < 40; f = f + 1)
            step_frame;
        check_eq("two keys down", active_key_count, 2);
        check_eq("multi key0 down", key_down[0], 1);
        check_eq("multi key3 down", key_down[3], 1);
        check_eq("multi pressure key0", pressure_values[0*ADC_BITS +: ADC_BITS], 400);
        check_eq("multi pressure key3", pressure_values[3*ADC_BITS +: ADC_BITS], 1200);
        check_eq("multi velocity key0", velocity_values[0*8 +: 8], 48);
        check_eq("multi velocity key3", velocity_values[3*8 +: 8], 148);
        check_eq("multi on pulse key0", on_pulse_cnt[0] - on_before[0], 1);
        check_eq("multi on pulse key3", on_pulse_cnt[3] - on_before[3], 1);

        set_press(7, 60);
        for (f = 0; f < 30; f = f + 1)
            step_frame;
        check_eq("three keys down", active_key_count, 3);
        check_eq("multi key7 down", key_down[7], 1);
        check_eq("multi velocity key7", velocity_values[7*8 +: 8], 5);
        check_eq("multi key0 velocity kept", velocity_values[0*8 +: 8], 48);
        check_eq("multi key3 velocity kept", velocity_values[3*8 +: 8], 148);

        set_press(0, 0);
        for (f = 0; f < 30; f = f + 1)
            step_frame;
        check_eq("multi key0 released", key_down[0], 0);
        check_eq("multi key3 still down", key_down[3], 1);
        check_eq("multi key7 still down", key_down[7], 1);
        check_eq("two keys left", active_key_count, 2);
        check_eq("multi key3 velocity kept after release", velocity_values[3*8 +: 8], 148);
        check_eq("multi key7 velocity kept after release", velocity_values[7*8 +: 8], 5);

        clear_press;
        for (f = 0; f < 30; f = f + 1)
            step_frame;
        check_eq("all keys idle before full press", active_key_count, 0);

        for (k = 0; k < KEY_COUNT; k = k + 1)
            set_press(k, 40 + 100*k);
        save_pulse_counts;
        for (f = 0; f < 45; f = f + 1)
            step_frame;
        check_eq("all keys active count", active_key_count, KEY_COUNT);
        clean = 1;
        for (k = 0; k < KEY_COUNT; k = k + 1) begin
            if (key_down[k] !== 1'b1)
                clean = 0;
            check_eq("all keys velocity", velocity_values[k*8 +: 8], ref_velocity(40 + 100*k));
            check_eq("all keys on pulse", on_pulse_cnt[k] - on_before[k], 1);
        end
        check_eq("all keys key_down", clean, 1);

        clear_press;
        save_pulse_counts;
        for (f = 0; f < 30; f = f + 1)
            step_frame;
        check_eq("all keys released count", active_key_count, 0);
        clean = 1;
        for (k = 0; k < KEY_COUNT; k = k + 1) begin
            if (key_down[k] !== 1'b0)
                clean = 0;
            if (pressure_values[k*ADC_BITS +: ADC_BITS] !== {ADC_BITS{1'b0}})
                clean = 0;
            if (off_pulse_cnt[k] - off_before[k] !== 1)
                clean = 0;
        end
        check_eq("all keys released cleanly", clean, 1);
        check_eq("all keys off pulse total", pulse_off_total() - off_total_before, KEY_COUNT);

        // [7] 掉线保护：adc_ready 拉低后门控状态被清除
        $display("# [7] adc_ready dropout clears gating");
        clear_press;
        set_press(1, 500);
        set_press(4, 900);
        save_pulse_counts;
        for (f = 0; f < 40; f = f + 1)
            step_frame;
        check_eq("drop key1 down", key_down[1], 1);
        check_eq("drop key4 down", key_down[4], 1);
        check_eq("drop velocity key1", velocity_values[1*8 +: 8], 60);
        check_eq("drop velocity key4", velocity_values[4*8 +: 8], 110);

        // 从这里开始只关心掉线是否凭空产生新的按下事件。
        on_total_mid = pulse_on_total();

        hold_cycles(0, 3);
        check_eq("drop calibrated kept", calibrated, 1);
        check_eq("drop active cleared", active_key_count, 0);
        clean = 1;
        for (k = 0; k < KEY_COUNT; k = k + 1) begin
            if (key_down[k] !== 1'b0)
                clean = 0;
            if (pressure_values[k*ADC_BITS +: ADC_BITS] !== {ADC_BITS{1'b0}})
                clean = 0;
            if (velocity_values[k*8 +: 8] !== 8'd0)
                clean = 0;
        end
        check_eq("drop gating and velocity cleared", clean, 1);
        check_eq("drop off pulse key1", off_pulse_cnt[1] - off_before[1], 1);
        check_eq("drop off pulse key4", off_pulse_cnt[4] - off_before[4], 1);
        check_eq("drop off pulse total", pulse_off_total() - off_total_before, 2);

        // adc_ready 恢复后仍未送来采样帧，门控必须保持清除。
        hold_cycles(1, 5);
        check_eq("no phantom press after dropout", active_key_count, 0);
        check_eq("no phantom on pulse after dropout", pulse_on_total() - on_total_mid, 0);

        // 压力撤掉后再送采样帧，DUT 必须仍然静默。
        clear_press;
        for (f = 0; f < 10; f = f + 1)
            step_frame;
        check_eq("still idle after dropout", active_key_count, 0);
        check_eq("no on pulse at baseline after dropout", pulse_on_total() - on_total_mid, 0);

        // 掉线后重新施加压力，按下判定必须能正常恢复。
        set_press(1, 500);
        for (f = 0; f < 40; f = f + 1)
            step_frame;
        check_eq("press works again after dropout", key_down[1], 1);
        check_eq("velocity works again after dropout", velocity_values[1*8 +: 8], 60);
        check_eq("on pulse delta after dropout recovery", on_pulse_cnt[1] - on_before[1], 2);
        clear_press;
        for (f = 0; f < 30; f = f + 1)
            step_frame;
        check_eq("final release clean", active_key_count, 0);

        // [8] 只停止送新采样、adc_ready 仍为高时的行为，只记录现象不计错误。
        $display("# [8] no new frames while adc_ready stays high");
        clear_press;
        set_press(6, 600);
        for (f = 0; f < 40; f = f + 1)
            step_frame;
        check_eq("stall key6 down", key_down[6], 1);
        hold_cycles(1, 200);
        stall_held = key_down[6];
        if (stall_held)
            $display("# INFO: key_down stayed asserted for 200 clocks without sample_frame_valid");
        else
            $display("# INFO: key_down cleared after sample_frame_valid stopped");
        clear_press;
        for (f = 0; f < 20; f = f + 1)
            step_frame;
        check_eq("stall key6 released", key_down[6], 0);

        if (errors == 0)
            $display("PASS: pressure key matrix calibration, press/release hysteresis, velocity mapping, adc_ready dropout and multi-key checks");
        else
            $display("FAIL %0d checks did not pass", errors);

        $finish;
    end

    initial begin
        #500_000;
        $display("FAIL timeout");
        $finish;
    end

    wire test_pass = (errors == 0);
endmodule
`default_nettype wire
