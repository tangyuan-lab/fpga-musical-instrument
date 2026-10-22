`default_nettype none

// 将片内 ADC 原始值转换为可直接用于演奏的压力、门控和目标音量。
// 当前 FSR 模块在 A 模式下“按压越重，输出电压越低”，因此压力定义为
// baseline - adc_sample。上电校准期间必须完全松开传感器。
module pressure_control #(
    parameter integer CALIBRATION_SAMPLES = 64,
    parameter [12:0] PRESS_ON              = 13'd16,
    parameter [12:0] PRESS_OFF             = 13'd8,
    parameter [12:0] PRESS_FULL            = 13'd224
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        sample_valid,
    input  wire        adc_ready,
    input  wire        audio_ready,
    input  wire [12:0] adc_sample,
    output reg         calibrated,
    output reg  [12:0] baseline,
    output wire [12:0] pressure_drop,
    output wire [11:0] pressure_value,
    output reg         note_gate,
    output reg  [12:0] volume_target
);
    localparam integer CAL_COUNT_WIDTH =
        (CALIBRATION_SAMPLES <= 1) ? 1 : $clog2(CALIBRATION_SAMPLES);
    localparam integer CAL_SUM_WIDTH = 13 + CAL_COUNT_WIDTH;
    localparam [12:0] VOLUME_MAX = 13'd4096;

    reg [CAL_SUM_WIDTH-1:0] baseline_sum;
    reg [CAL_COUNT_WIDTH-1:0] baseline_count;
    wire [12:0] pressure_above_on;
    wire [25:0] volume_scaled;

    // CALIBRATION_SAMPLES 固定为 2 的整数次幂；默认 64 次可兼顾启动速度和噪声平均。
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baseline_sum   <= {CAL_SUM_WIDTH{1'b0}};
            baseline_count <= {CAL_COUNT_WIDTH{1'b0}};
            baseline       <= 13'd0;
            calibrated     <= 1'b0;
        end else if (!calibrated && sample_valid && adc_ready) begin
            if (baseline_count == CALIBRATION_SAMPLES - 1) begin
                baseline   <= (baseline_sum + adc_sample) >> CAL_COUNT_WIDTH;
                calibrated <= 1'b1;
            end else begin
                baseline_sum   <= baseline_sum + adc_sample;
                baseline_count <= baseline_count + 1'b1;
            end
        end
    end

    // 只把低于松开基线的变化视为压力，向上的电源漂移不会触发琴键。
    assign pressure_drop = calibrated && (baseline > adc_sample) ?
                           baseline - adc_sample : 13'd0;
    assign pressure_value = pressure_drop[12] ? 12'hfff : pressure_drop[11:0];

    // 16 码触发、8 码释放形成迟滞区，避免噪声造成音符反复开关。
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            note_gate <= 1'b0;
        end else if (!calibrated || !adc_ready || !audio_ready) begin
            note_gate <= 1'b0;
        end else if (sample_valid) begin
            if (!note_gate && pressure_drop >= PRESS_ON)
                note_gate <= 1'b1;
            else if (note_gate && pressure_drop <= PRESS_OFF)
                note_gate <= 1'b0;
        end
    end

    assign pressure_above_on = (pressure_drop > PRESS_ON) ?
                               pressure_drop - PRESS_ON : 13'd0;
    // 315/16≈19.69，把 16～224 码近似线性映射为 0～4096。
    assign volume_scaled = pressure_above_on * 13'd315;

    always @(*) begin
        if (!note_gate || pressure_drop <= PRESS_ON)
            volume_target = 13'd0;
        else if (pressure_drop >= PRESS_FULL || volume_scaled[25:4] >= VOLUME_MAX)
            volume_target = VOLUME_MAX;
        else
            volume_target = volume_scaled[16:4];
    end
endmodule

`default_nettype wire
