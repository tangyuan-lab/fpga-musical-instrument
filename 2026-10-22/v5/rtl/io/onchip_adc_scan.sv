`default_nettype none
// Tang Mega 60K 片内 ADC 双通道轮询控制器。
// NEO Dock 的 J11 将两路专用差分输入分别标为 ADCV_P/N 与 ADCT_P/N；
// 它们直接进入 FPGA 的模拟硬核，不作为普通数字顶层端口出现。
module onchip_adc_scan #(
    parameter integer REQUEST_HIGH_CYCLES = 1,
    parameter integer MUX_SETTLE_CYCLES   = 64
)(
    input  wire        clk,
    input  wire        rst_n,
    output reg  [13:0] sample0,
    output reg  [13:0] sample1,
    output reg         sample_valid,
    output reg         ready,
    output reg         timeout_fault
);
    localparam [2:0] ST_STARTUP   = 3'd0,
                     ST_SETTLE    = 3'd1,
                     ST_REQUEST   = 3'd2,
                     ST_WAIT_LOW  = 3'd3,
                     ST_WAIT_HIGH = 3'd4;

    reg [2:0] state;
    reg       channel;
    reg       adc_request;
    reg [15:0] delay_count;
    reg [23:0] timeout_count;
    wire       adc_ready;
    wire [12:0] adc_value;
    wire       unused_adceno;
    wire       unused_adc1bit;
    wire       unused_adcclko;
    wire [7:0] unused_mdrp_rdata;
    wire       unused_sar_clko;

    // GW5AT-60B 使用 ADC_SAR 硬核。CHEN=1/2 分别选择专用 ADCV/ADCT 通道；
    // 50 MHz 采样时钟满足 10~300 MHz 规格，单次转换只需几十个时钟周期。
    ADC_SAR #(
        .BUF_EN(29'b0),
        .CLK_SRC_SEL(1'b1),
        .VREF_BUF_EN(1'b1),
        .ADC_CLKDIV_EN(1'b0),
        .ADC_CLK_DIV(2'b00)
    ) adc_hard_block (
        // Delta-sigma ADC 一侧本测试不启用。
        .ADCMODE(1'b1), .VSENCTL(3'b000), .CLK(clk),
        .ADCENO(unused_adceno), .DRSTN(rst_n), .ADCREQI(1'b0),
        .ADCRDY(), .ADCVALUE(),
        .MDRP_CLK(1'b0), .MDRP_WDATA(8'd0), .MDRP_A_INC(1'b0),
        .MDRP_OPCODE(2'b00), .MDRP_RDATA(unused_mdrp_rdata),
        .ADC1BIT(unused_adc1bit), .ADCCLKO(unused_adcclko), .ADCENI(1'b0),
        // SAR ADC 一侧用于两个外部压力输入。
        .ADCBIT(adc_value), .CLKO(unused_sar_clko), .EOC(adc_ready),
        .CLKI(clk), .CHEN(channel ? 7'b0000010 : 7'b0000001),
        .RSTN(rst_n), .SOC(adc_request)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= ST_STARTUP;
            channel       <= 1'b0;
            adc_request   <= 1'b0;
            delay_count   <= 16'd0;
            timeout_count <= 24'd0;
            sample0       <= 14'd0;
            sample1       <= 14'd0;
            sample_valid  <= 1'b0;
            ready         <= 1'b0;
            timeout_fault <= 1'b0;
        end else begin
            sample_valid <= 1'b0;
            // 默认拉低 SOC；仅在 ST_REQUEST 状态覆盖为高，从而保证离开该状态后
            // 立即产生下降沿。REQUEST_HIGH_CYCLES=1 时也能得到一个完整时钟周期的高脉冲。
            adc_request <= 1'b0;
            case (state)
                ST_STARTUP: begin
                    // 给模拟硬核约 1.3 ms 的上电稳定时间。
                    if (timeout_count == 24'd65535) begin
                        timeout_count <= 24'd0;
                        delay_count   <= 16'd0;
                        state         <= ST_SETTLE;
                    end else timeout_count <= timeout_count + 1'b1;
                end

                ST_SETTLE: begin
                    if (delay_count == MUX_SETTLE_CYCLES-1) begin
                        delay_count <= 16'd0;
                        state       <= ST_REQUEST;
                    end else delay_count <= delay_count + 1'b1;
                end

                ST_REQUEST: begin
                    // SAR ADC 在 SOC 上升沿启动转换；这里至少保持一个完整的 50 MHz 周期。
                    adc_request <= 1'b1;
                    if (delay_count == REQUEST_HIGH_CYCLES-1) begin
                        delay_count   <= 16'd0;
                        timeout_count <= 24'd0;
                        state         <= ST_WAIT_LOW;
                    end else delay_count <= delay_count + 1'b1;
                end

                ST_WAIT_LOW: begin
                    // EOC 可能保持上一次转换的高电平，直到新的 SOC 将它清零。
                    // 因此每次发起转换后必须先观察到 EOC=0，再接受后续的上升沿；
                    // 否则会把上一笔数据误当成新数据，甚至永久停在第一次采样。
                    if (!adc_ready) begin
                        timeout_count <= 24'd0;
                        state         <= ST_WAIT_HIGH;
                    end else if (timeout_count == 24'd2_499_999) begin
                        // 50 ms 内 EOC 未被新 SOC 清零，说明硬核没有接受请求。
                        timeout_fault <= 1'b1;
                        timeout_count <= 24'd0;
                        delay_count   <= 16'd0;
                        state         <= ST_SETTLE;
                    end else timeout_count <= timeout_count + 1'b1;
                end

                ST_WAIT_HIGH: begin
                    if (adc_ready) begin
                        if (!channel) sample0 <= {1'b0, adc_value};
                        else          sample1 <= {1'b0, adc_value};
                        sample_valid  <= 1'b1;
                        ready         <= 1'b1;
                        timeout_count <= 24'd0;
                        channel       <= ~channel;
                        delay_count   <= 16'd0;
                        state         <= ST_SETTLE;
                    end else if (timeout_count == 24'd2_499_999) begin
                        // 50 ms 仍无完成信号时锁存故障，但继续重试，方便排查。
                        timeout_fault <= 1'b1;
                        timeout_count <= 24'd0;
                        channel       <= ~channel;
                        delay_count   <= 16'd0;
                        state         <= ST_SETTLE;
                    end else timeout_count <= timeout_count + 1'b1;
                end

                default: state <= ST_STARTUP;
            endcase
        end
    end
endmodule
`default_nettype wire
