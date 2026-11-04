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

    // 32 BCK periods = 64 BCK edges per stereo sample. The accumulator
    // distributes 16- and 17-cycle half-periods, giving exactly 48 kHz
    // on average from 50 MHz without a second, drifting sample clock.
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
                // Current high half-cycle ends: set up the next bit.
                ws <= bit_index[4];
                if (bit_index == 5'd0) begin
                    sample_hold <= sample_in;
                    din <= sample_in[15];
                end else begin
                    din <= sample_hold[15 - bit_index[3:0]];
                end
            end else begin
                // PT8211 samples this bit on the new rising edge.
                bit_index <= bit_index + 5'd1;
            end
        end else begin
            edge_acc <= edge_sum;
        end
    end

endmodule
