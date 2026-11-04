`default_nettype none

// 每 50 ms 输出一次调试快照，格式如下（十六进制）：
// R=xxxx P=xxx G=x V=xxxx S=x\r\n
// S[3:0]={ADC故障,音频就绪,基线完成,ADC就绪}。
module pressure_audio_telemetry #(
    parameter integer PERIOD_CYCLES = 2_500_000,
    parameter integer CLKS_PER_BIT  = 434
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [13:0] raw_adc,
    input  wire [11:0] pressure,
    input  wire        gate,
    input  wire [12:0] volume,
    input  wire [3:0]  status,
    output wire        tx
);
    reg [15:0] snap_raw;
    reg [11:0] snap_pressure;
    reg        snap_gate;
    reg [15:0] snap_volume;
    reg [3:0]  snap_status;
    reg [31:0] period_count;
    reg [4:0] index;
    reg [1:0] state;
    reg start;
    reg [7:0] data;
    wire busy;
    wire done;

    function automatic [7:0] hexchar(input [3:0] nibble);
        hexchar = (nibble < 10) ? 8'h30 + {4'b0, nibble} :
                                 8'h41 + {4'b0, nibble} - 8'd10;
    endfunction

    always @(*) begin
        data = 8'h20;
        case (index)
            0:  data = "R";
            1:  data = "=";
            2:  data = hexchar(snap_raw[15:12]);
            3:  data = hexchar(snap_raw[11:8]);
            4:  data = hexchar(snap_raw[7:4]);
            5:  data = hexchar(snap_raw[3:0]);
            7:  data = "P";
            8:  data = "=";
            9:  data = hexchar(snap_pressure[11:8]);
            10: data = hexchar(snap_pressure[7:4]);
            11: data = hexchar(snap_pressure[3:0]);
            13: data = "G";
            14: data = "=";
            15: data = snap_gate ? "1" : "0";
            17: data = "V";
            18: data = "=";
            19: data = hexchar(snap_volume[15:12]);
            20: data = hexchar(snap_volume[11:8]);
            21: data = hexchar(snap_volume[7:4]);
            22: data = hexchar(snap_volume[3:0]);
            24: data = "S";
            25: data = "=";
            26: data = hexchar(snap_status);
            27: data = 8'h0d;
            28: data = 8'h0a;
            default: data = 8'h20;
        endcase
    end

    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_uart_tx (
        .clk(clk), .rst_n(rst_n), .start(start), .data(data),
        .tx(tx), .busy(busy), .done(done)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            snap_raw      <= 16'd0;
            snap_pressure <= 12'd0;
            snap_gate     <= 1'b0;
            snap_volume   <= 16'd0;
            snap_status   <= 4'd0;
            period_count  <= 32'd0;
            index         <= 5'd0;
            state         <= 2'd0;
            start         <= 1'b0;
        end else begin
            start <= 1'b0;
            if (period_count == PERIOD_CYCLES - 1)
                period_count <= 32'd0;
            else
                period_count <= period_count + 1'b1;

            case (state)
                2'd0: if (period_count == PERIOD_CYCLES - 1) begin
                    snap_raw      <= {2'b0, raw_adc};
                    snap_pressure <= pressure;
                    snap_gate     <= gate;
                    snap_volume   <= {3'b0, volume};
                    snap_status   <= status;
                    index         <= 5'd0;
                    state         <= 2'd1;
                end
                2'd1: if (!busy) begin
                    start <= 1'b1;
                    state <= 2'd2;
                end
                2'd2: if (done) begin
                    if (index == 5'd28)
                        state <= 2'd0;
                    else begin
                        index <= index + 1'b1;
                        state <= 2'd1;
                    end
                end
                default: state <= 2'd0;
            endcase
        end
    end
endmodule

`default_nettype wire
