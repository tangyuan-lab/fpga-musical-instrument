`default_nettype none
// GW5A小型配置表，显式使用简单双口块RAM，禁止综合折叠成不支持的SP READ_FIRST。
// 同地址读写旁路新值；数据不复位，调用方用有效位屏蔽未写槽。读取延迟为一拍。
module control_ram_sdp #(parameter integer WIDTH=32,ADDRESS_WIDTH=5)(
    input wire clk,write_enable,
    input wire [ADDRESS_WIDTH-1:0] write_address,read_address,
    input wire [WIDTH-1:0] write_data,output wire [WIDTH-1:0] read_data
);
    localparam integer ALIGN=$clog2(WIDTH);
    wire [31:0] raw;reg forward_valid;reg [WIDTH-1:0] forward_data;
    SDPB #(.READ_MODE(1'b0),.BIT_WIDTH_0(WIDTH),.BIT_WIDTH_1(WIDTH),
        .BLK_SEL_0(3'd0),.BLK_SEL_1(3'd0),.RESET_MODE("SYNC")) memory(
        .DO(raw),.DI(32'(write_data)),.BLKSELA(3'd0),.BLKSELB(3'd0),
        .ADA(14'(write_address)<<ALIGN),.ADB(14'(read_address)<<ALIGN),
        .CLKA(clk),.CLKB(clk),.CEA(write_enable),.CEB(1'b1),.OCE(1'b1),.RESET(1'b0));
    always @(posedge clk) begin
        forward_valid<=write_enable && write_address==read_address;
        if(write_enable) forward_data<=write_data;
    end
    assign read_data=forward_valid ? forward_data:raw[WIDTH-1:0];
endmodule
`default_nettype wire
