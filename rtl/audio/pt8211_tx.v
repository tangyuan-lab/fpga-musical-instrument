// 来源：从本地先前的一个 MIT 练习工程改过来的；针对这块板换了时钟参数、引脚和功放控制，
// 并单独写了 testbench 把协议验出来。
module pt8211_tx #(
    parameter integer CLK_HZ = 50_000_000,
    parameter integer SAMPLE_HZ = 48_000
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] sample_in,
    output reg         bck = 1'b1,
    output reg         ws = 1'b0,
    output reg         din = 1'b0,
    output wire        frame_tick
);

    // 这里用的是分数分频，不是固定分频。最早我只改了"采样请求"的频率：每拍加 48000、
    // 满 50000000 发一次，但 BCK 还是固定 1.5625 MHz。结果串口每秒只能吃掉
    // 1562500/32 = 48828.125 帧，两头速率对不上，板上跑出来其实是 48,828.125 Hz。
    // 改法：BCK 的边沿也用累加器分配。每个立体声帧 64 个边沿，每拍加 48000*64 =
    // 3072000，满 50000000 就翻转并减去阈值。半周期在 16 和 17 个系统时钟之间分配，
    // 所以 BCK 不是严格等宽的。每 3 帧正好 3125 个时钟，平均 50000000*3/3125 = 48000 Hz，
    // 位时钟平均 1.536 MHz。
    localparam integer EDGE_HZ = SAMPLE_HZ * 64;
    localparam integer ACC_WIDTH = $clog2(CLK_HZ + EDGE_HZ);
    localparam [ACC_WIDTH-1:0] EDGE_INCREMENT = EDGE_HZ;
    localparam [ACC_WIDTH-1:0] CLK_LIMIT = CLK_HZ;
    reg [ACC_WIDTH-1:0] edge_acc = {ACC_WIDTH{1'b0}};
    reg [4:0] bit_index = 5'd0;
    reg [15:0] sample_hold = 16'd0;

    wire [ACC_WIDTH-1:0] edge_sum = edge_acc + EDGE_INCREMENT;
    wire toggle_bck = (edge_sum >= CLK_LIMIT);
    assign frame_tick = rst_n && toggle_bck && !bck &&
                        (bit_index == 5'd31);

    always @(posedge clk) begin
        if (!rst_n) begin
            edge_acc    <= {ACC_WIDTH{1'b0}};
            bit_index   <= 5'd0;
            sample_hold <= 16'd0;
            bck         <= 1'b1;
            ws          <= 1'b0;
            din         <= 1'b0;
        end else if (toggle_bck) begin
            edge_acc <= edge_sum - CLK_LIMIT;
            bck <= !bck;

            if (bck) begin
                // 当前高电平半周期结束，准备下一个数据位。
                ws <= bit_index[4];
                if (bit_index == 5'd0) begin
                    sample_hold <= sample_in;
                    din <= sample_in[15];
                end else begin
                    din <= sample_hold[15 - bit_index[3:0]];
                end
            end else begin
                // PT8211 在新的上升沿采样这一位。
                bit_index <= bit_index + 5'd1;
            end
        end else begin
            edge_acc <= edge_sum;
        end
    end

endmodule

