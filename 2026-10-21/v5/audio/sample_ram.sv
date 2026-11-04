`default_nettype none
// GW5A 16位简单双口BSRAM。明确分离读写端口，避免综合为不受支持的SP NO_CHANGE。
module sample_ram #(parameter integer ADDRESS_WIDTH=12)(
    input wire clk,write_enable,input wire [ADDRESS_WIDTH-1:0] write_address,read_address,
    input wire signed [15:0] write_data,output reg signed [15:0] read_data
);
    localparam integer BANKS=1<<(ADDRESS_WIDTH-10);
    wire [31:0] data[0:BANKS-1];reg [ADDRESS_WIDTH-1:0] selected;
    genvar b;generate for(b=0;b<BANKS;b=b+1) begin:bank
        SDPB #(.READ_MODE(1'b0),.BIT_WIDTH_0(16),.BIT_WIDTH_1(16),.BLK_SEL_0(3'd0),.BLK_SEL_1(3'd0),.RESET_MODE("SYNC")) ram(
            .DO(data[b]),.DI({16'd0,write_data}),.BLKSELA(3'd0),.BLKSELB(3'd0),
            .ADA({write_address[9:0],4'd0}),.ADB({read_address[9:0],4'd0}),.CLKA(clk),.CLKB(clk),
            .CEA(write_enable && (write_address>>10)==b),.CEB((read_address>>10)==b),.OCE(1'b1),.RESET(1'b0));
    end endgenerate
    always @(posedge clk) begin selected<=read_address;read_data<=data[selected>>10][15:0];end
endmodule
`default_nettype wire
