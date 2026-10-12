`timescale 1ns/1ps
`default_nettype none

// 13 键压力数据处理核心。
//
// 本模块只处理已经完成 A/D 转换的数字采样，不依赖具体 ADC 型号。当前可在仿真中
// 输入假数据；MCP3208 到货后，SPI 采样器只需每轮把 13 个通道装入 adc_samples，
// 再产生一个 sample_frame_valid 脉冲，后面的校准、滤波和按键判断无需改动。
//
// adc_samples、baseline_values 和 pressure_values 都采用低位优先的扁平总线：
// 第 n 个键位于 [n*ADC_BITS +: ADC_BITS]。
module pressure_key_matrix #(
    parameter integer KEY_COUNT           = 13,
    parameter integer ADC_BITS            = 12,
    parameter integer CALIBRATION_SAMPLES = 64,
    parameter integer FILTER_SHIFT        = 2,
    parameter [ADC_BITS-1:0] PRESS_ON      = 12'd16,
    parameter [ADC_BITS-1:0] PRESS_OFF     = 12'd8,
    // MCP3208 使用 3.3 V 参考时，把约 1.65 V 的压力变化定义为满力度。
    // 旧版本按 512 码（约 0.41 V）饱和，换成 3.3 V 输入范围后会显得过早满音量。
    parameter [ADC_BITS-1:0] PRESS_FULL    = 12'd2048,
    // 1 表示按压后 ADC 值下降；0 表示按压后 ADC 值上升。
    // 每一位对应一个键，因此必要时也能混用两种接法。
    parameter [KEY_COUNT-1:0] ACTIVE_LOW_MASK = {KEY_COUNT{1'b1}}
) (
    input  wire                              clk,
    input  wire                              rst_n,
    input  wire                              adc_ready,
    input  wire                              sample_frame_valid,
    input  wire [KEY_COUNT*ADC_BITS-1:0]     adc_samples,
    output reg                               calibrated,
    output wire [KEY_COUNT*ADC_BITS-1:0]     baseline_values,
    output wire [KEY_COUNT*ADC_BITS-1:0]     pressure_values,
    output reg  [KEY_COUNT*8-1:0]            velocity_values,
    output reg  [KEY_COUNT-1:0]              key_down,
    output reg  [KEY_COUNT-1:0]              key_on_pulse,
    output reg  [KEY_COUNT-1:0]              key_off_pulse,
    output reg  [$clog2(KEY_COUNT+1)-1:0]    active_key_count
);
    localparam integer CAL_COUNT_WIDTH =
        (CALIBRATION_SAMPLES <= 1) ? 1 : $clog2(CALIBRATION_SAMPLES);
    localparam integer CAL_SUM_WIDTH = ADC_BITS + CAL_COUNT_WIDTH;

    reg [CAL_COUNT_WIDTH-1:0] calibration_count;
    reg [CAL_SUM_WIDTH-1:0] baseline_sum [0:KEY_COUNT-1];
    reg [ADC_BITS-1:0] baseline_reg [0:KEY_COUNT-1];
    reg [ADC_BITS-1:0] filtered_pressure [0:KEY_COUNT-1];

    wire [KEY_COUNT*ADC_BITS-1:0] raw_pressure_bus;
    wire [KEY_COUNT*ADC_BITS-1:0] filtered_next_bus;

    integer key_index;
    integer count_index;
    genvar bus_index;

    // 一阶低通滤波：每帧向新值移动 1/(2^FILTER_SHIFT)。默认采样 1 kHz、
    // FILTER_SHIFT=2 时，按键响应约为数毫秒，仍可满足 10 ms 交互延迟目标。
    function automatic [ADC_BITS-1:0] filter_step;
        input [ADC_BITS-1:0] old_value;
        input [ADC_BITS-1:0] new_value;
        reg [ADC_BITS:0] difference;
        reg [ADC_BITS:0] step;
        begin
            if (FILTER_SHIFT == 0) begin
                filter_step = new_value;
            end else if (new_value > old_value) begin
                difference = new_value - old_value;
                step = (difference + ((1 << FILTER_SHIFT) - 1)) >> FILTER_SHIFT;
                filter_step = old_value + step[ADC_BITS-1:0];
            end else if (old_value > new_value) begin
                difference = old_value - new_value;
                step = (difference + ((1 << FILTER_SHIFT) - 1)) >> FILTER_SHIFT;
                filter_step = old_value - step[ADC_BITS-1:0];
            end else begin
                filter_step = old_value;
            end
        end
    endfunction

    // 把有效压力区间映射到 8 bit 力度。
    // 当前默认 PRESS_FULL=2048、PRESS_ON=16，使用右移 3 近似除以 8，
    // 可避免 13 路并行通用乘法器/除法器；接近满力度时结果约为 248，
    // 对耳机音量和四声部混音已经足够。若将来需要严格的 0..255 标定，
    // 可在较低采样率的校准任务中加入分段查表，不放回实时按键路径。
    function automatic [7:0] normalize_velocity;
        input [ADC_BITS-1:0] pressure;
        reg [ADC_BITS-1:0] delta;
        begin
            if (pressure <= PRESS_ON) begin
                normalize_velocity = 8'd0;
            end else if (pressure >= PRESS_FULL) begin
                normalize_velocity = 8'hff;
            end else begin
                delta = pressure - PRESS_ON;
                // 采用常量移位代替除法，避免在 13 路实时按键路径中推断通用除法器。
                // PRESS_FULL=2048 时，delta/8 映射到约 0..255；保留 512 分支，
                // 这样旧版参数仍能复用本模块。
                if (PRESS_FULL == 12'd2048)
                    normalize_velocity = delta[10:3];
                else if (PRESS_FULL == 12'd512)
                    normalize_velocity = delta[8:1];
                else
                    normalize_velocity = delta[8:1];
            end
        end
    endfunction

    generate
        for (bus_index = 0; bus_index < KEY_COUNT; bus_index = bus_index + 1) begin : g_key_bus
            wire [ADC_BITS-1:0] sample_value;
            wire [ADC_BITS-1:0] raw_pressure;
            wire [ADC_BITS-1:0] next_filtered_pressure;

            assign sample_value = adc_samples[bus_index*ADC_BITS +: ADC_BITS];
            assign raw_pressure = !calibrated ? {ADC_BITS{1'b0}} :
                (ACTIVE_LOW_MASK[bus_index] ?
                    ((baseline_reg[bus_index] > sample_value) ?
                        baseline_reg[bus_index] - sample_value : {ADC_BITS{1'b0}}) :
                    ((sample_value > baseline_reg[bus_index]) ?
                        sample_value - baseline_reg[bus_index] : {ADC_BITS{1'b0}}));
            assign next_filtered_pressure =
                filter_step(filtered_pressure[bus_index], raw_pressure);

            assign baseline_values[bus_index*ADC_BITS +: ADC_BITS] =
                baseline_reg[bus_index];
            assign pressure_values[bus_index*ADC_BITS +: ADC_BITS] =
                filtered_pressure[bus_index];
            assign raw_pressure_bus[bus_index*ADC_BITS +: ADC_BITS] = raw_pressure;
            assign filtered_next_bus[bus_index*ADC_BITS +: ADC_BITS] =
                next_filtered_pressure;
        end
    endgenerate

    // 统计当前同时按下的键数；13 键最多需要 4 bit。
    always @(*) begin
        active_key_count = {$clog2(KEY_COUNT+1){1'b0}};
        for (count_index = 0; count_index < KEY_COUNT; count_index = count_index + 1)
            active_key_count = active_key_count + key_down[count_index];
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            calibrated       <= 1'b0;
            calibration_count <= {CAL_COUNT_WIDTH{1'b0}};
            velocity_values  <= {(KEY_COUNT*8){1'b0}};
            key_down         <= {KEY_COUNT{1'b0}};
            key_on_pulse     <= {KEY_COUNT{1'b0}};
            key_off_pulse    <= {KEY_COUNT{1'b0}};
            for (key_index = 0; key_index < KEY_COUNT; key_index = key_index + 1) begin
                baseline_sum[key_index]      <= {CAL_SUM_WIDTH{1'b0}};
                baseline_reg[key_index]      <= {ADC_BITS{1'b0}};
                filtered_pressure[key_index] <= {ADC_BITS{1'b0}};
            end
        end else begin
            // 事件脉冲只保持一个系统时钟周期，便于音源捕获各键的起音和释音。
            key_on_pulse  <= {KEY_COUNT{1'b0}};
            key_off_pulse <= {KEY_COUNT{1'b0}};

            if (!calibrated && adc_ready && sample_frame_valid) begin
                for (key_index = 0; key_index < KEY_COUNT; key_index = key_index + 1) begin
                    if (calibration_count == CALIBRATION_SAMPLES - 1) begin
                        if (CALIBRATION_SAMPLES == 64)
                            baseline_reg[key_index] <=
                                (baseline_sum[key_index] +
                                 adc_samples[key_index*ADC_BITS +: ADC_BITS]) >> 6;
                        else
                            baseline_reg[key_index] <=
                                (baseline_sum[key_index] +
                                 adc_samples[key_index*ADC_BITS +: ADC_BITS]) /
                                CALIBRATION_SAMPLES;
                    end else begin
                        baseline_sum[key_index] <= baseline_sum[key_index] +
                            adc_samples[key_index*ADC_BITS +: ADC_BITS];
                    end
                end

                if (calibration_count == CALIBRATION_SAMPLES - 1)
                    calibrated <= 1'b1;
                else
                    calibration_count <= calibration_count + 1'b1;
            end else if (calibrated && !adc_ready) begin
                // ADC 掉线时立即静音，并为仍按下的键产生一次释音事件。
                key_off_pulse   <= key_down;
                key_down        <= {KEY_COUNT{1'b0}};
                velocity_values <= {(KEY_COUNT*8){1'b0}};
                for (key_index = 0; key_index < KEY_COUNT; key_index = key_index + 1)
                    filtered_pressure[key_index] <= {ADC_BITS{1'b0}};
            end else if (calibrated && sample_frame_valid) begin
                for (key_index = 0; key_index < KEY_COUNT; key_index = key_index + 1) begin
                    filtered_pressure[key_index] <=
                        filtered_next_bus[key_index*ADC_BITS +: ADC_BITS];

                    if (!key_down[key_index] &&
                        filtered_next_bus[key_index*ADC_BITS +: ADC_BITS] >= PRESS_ON) begin
                        key_down[key_index]     <= 1'b1;
                        key_on_pulse[key_index] <= 1'b1;
                    end else if (key_down[key_index] &&
                                 filtered_next_bus[key_index*ADC_BITS +: ADC_BITS] <= PRESS_OFF) begin
                        key_down[key_index]      <= 1'b0;
                        key_off_pulse[key_index] <= 1'b1;
                    end

                    velocity_values[key_index*8 +: 8] <= normalize_velocity(
                        filtered_next_bus[key_index*ADC_BITS +: ADC_BITS]);
                end
            end
        end
    end

    // 保留该信号有助于波形调试；综合器会自动删除未被顶层使用的逻辑。
    wire _unused_raw_pressure = &{1'b0, raw_pressure_bus};
endmodule

`default_nettype wire


