// Standard Philips I2S framing for an external DAC: two 32-bit slots per
// 48 kHz frame, one BCK delay after each WS transition, 16 valid MSB-first
// two's-complement bits and zero padding. PT8211 uses LSBJ, not this format.
module i2s_tx_16 #(
    parameter integer CLK_HZ = 50_000_000,
    parameter integer SAMPLE_HZ = 48_000
) (
    input wire clk,
    input wire rst_n,
    input wire signed [15:0] sample_in,
    output reg bck = 1'b1,
    output reg ws = 1'b1,
    output reg din = 1'b0,
    output wire frame_tick
);
    localparam integer EDGE_HZ = SAMPLE_HZ * 128;
    localparam integer ACC_WIDTH = $clog2(CLK_HZ + EDGE_HZ);
    localparam [ACC_WIDTH-1:0] EDGE_INCREMENT = EDGE_HZ;
    localparam [ACC_WIDTH-1:0] CLK_LIMIT = CLK_HZ;
    reg [ACC_WIDTH-1:0] edge_acc = {ACC_WIDTH{1'b0}};
    reg [5:0] bit_index = 6'd0;
    reg [15:0] sample_hold = 16'd0;
    wire [ACC_WIDTH-1:0] edge_sum = edge_acc + EDGE_INCREMENT;
    wire toggle_bck = edge_sum >= CLK_LIMIT;
    assign frame_tick = rst_n && toggle_bck && !bck && bit_index == 6'd63;
    always @(posedge clk) begin
        if (!rst_n) begin
            edge_acc <= {ACC_WIDTH{1'b0}};
            bit_index <= 6'd0;
            sample_hold <= 16'd0;
            bck <= 1'b1;
            ws <= 1'b1;
            din <= 1'b0;
        end else if (toggle_bck) begin
            edge_acc <= edge_sum - CLK_LIMIT;
            bck <= !bck;
            if (bck) begin
                ws <= bit_index[5];
                if (bit_index == 6'd0) sample_hold <= sample_in;
                if (bit_index[4:0] >= 5'd1 && bit_index[4:0] <= 5'd16)
                    din <= sample_hold[16 - bit_index[4:0]];
                else
                    din <= 1'b0;
            end else begin
                bit_index <= bit_index + 6'd1;
            end
        end else begin
            edge_acc <= edge_sum;
        end
    end
endmodule
