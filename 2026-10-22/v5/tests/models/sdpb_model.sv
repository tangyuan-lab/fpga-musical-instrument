// 仅供RTL测试的GW5A SDPB行为模型：4/8/16/32位模式、同步读、独立读写端口。
module SDPB #(
    parameter integer READ_MODE=0,BIT_WIDTH_0=8,BIT_WIDTH_1=8,
    parameter [2:0] BLK_SEL_0=0,BLK_SEL_1=0,parameter RESET_MODE="SYNC"
)(output reg [31:0] DO,input wire [31:0] DI,input wire [2:0] BLKSELA,BLKSELB,
    input wire [13:0] ADA,ADB,input wire CLKA,CLKB,CEA,CEB,OCE,RESET);
    localparam integer SHIFT=$clog2(BIT_WIDTH_0);
    reg [BIT_WIDTH_0-1:0] memory[0:(16384/BIT_WIDTH_0)-1];
    always @(posedge CLKA) if(CEA && BLKSELA==BLK_SEL_0) memory[ADA>>SHIFT]<=DI[BIT_WIDTH_0-1:0];
    always @(posedge CLKB) if(CEB && OCE && BLKSELB==BLK_SEL_1) DO<={{(32-BIT_WIDTH_1){1'b0}},memory[ADB>>SHIFT]};
endmodule
