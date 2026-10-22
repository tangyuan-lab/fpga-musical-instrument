// Simulation only. SP32 normal/write-through, as specified by UG300.
module SP #(
 parameter BIT_WIDTH=32, READ_MODE=0, WRITE_MODE=0, RESET_MODE="SYNC",
 parameter [255:0] INIT_RAM_00=0,
 parameter [255:0] INIT_RAM_01=0,
 parameter [255:0] INIT_RAM_02=0,
 parameter [255:0] INIT_RAM_03=0,
 parameter [255:0] INIT_RAM_04=0,
 parameter [255:0] INIT_RAM_05=0,
 parameter [255:0] INIT_RAM_06=0,
 parameter [255:0] INIT_RAM_07=0,
 parameter [255:0] INIT_RAM_08=0,
 parameter [255:0] INIT_RAM_09=0,
 parameter [255:0] INIT_RAM_0A=0,
 parameter [255:0] INIT_RAM_0B=0,
 parameter [255:0] INIT_RAM_0C=0,
 parameter [255:0] INIT_RAM_0D=0,
 parameter [255:0] INIT_RAM_0E=0,
 parameter [255:0] INIT_RAM_0F=0,
 parameter [255:0] INIT_RAM_10=0,
 parameter [255:0] INIT_RAM_11=0,
 parameter [255:0] INIT_RAM_12=0,
 parameter [255:0] INIT_RAM_13=0,
 parameter [255:0] INIT_RAM_14=0,
 parameter [255:0] INIT_RAM_15=0,
 parameter [255:0] INIT_RAM_16=0,
 parameter [255:0] INIT_RAM_17=0,
 parameter [255:0] INIT_RAM_18=0,
 parameter [255:0] INIT_RAM_19=0,
 parameter [255:0] INIT_RAM_1A=0,
 parameter [255:0] INIT_RAM_1B=0,
 parameter [255:0] INIT_RAM_1C=0,
 parameter [255:0] INIT_RAM_1D=0,
 parameter [255:0] INIT_RAM_1E=0,
 parameter [255:0] INIT_RAM_1F=0,
 parameter [255:0] INIT_RAM_20=0,
 parameter [255:0] INIT_RAM_21=0,
 parameter [255:0] INIT_RAM_22=0,
 parameter [255:0] INIT_RAM_23=0,
 parameter [255:0] INIT_RAM_24=0,
 parameter [255:0] INIT_RAM_25=0,
 parameter [255:0] INIT_RAM_26=0,
 parameter [255:0] INIT_RAM_27=0,
 parameter [255:0] INIT_RAM_28=0,
 parameter [255:0] INIT_RAM_29=0,
 parameter [255:0] INIT_RAM_2A=0,
 parameter [255:0] INIT_RAM_2B=0,
 parameter [255:0] INIT_RAM_2C=0,
 parameter [255:0] INIT_RAM_2D=0,
 parameter [255:0] INIT_RAM_2E=0,
 parameter [255:0] INIT_RAM_2F=0,
 parameter [255:0] INIT_RAM_30=0,
 parameter [255:0] INIT_RAM_31=0,
 parameter [255:0] INIT_RAM_32=0,
 parameter [255:0] INIT_RAM_33=0,
 parameter [255:0] INIT_RAM_34=0,
 parameter [255:0] INIT_RAM_35=0,
 parameter [255:0] INIT_RAM_36=0,
 parameter [255:0] INIT_RAM_37=0,
 parameter [255:0] INIT_RAM_38=0,
 parameter [255:0] INIT_RAM_39=0,
 parameter [255:0] INIT_RAM_3A=0,
 parameter [255:0] INIT_RAM_3B=0,
 parameter [255:0] INIT_RAM_3C=0,
 parameter [255:0] INIT_RAM_3D=0,
 parameter [255:0] INIT_RAM_3E=0,
 parameter [255:0] INIT_RAM_3F=0)(
 output reg [31:0] DO,input wire [31:0] DI,input wire [13:0] AD,
 input wire [2:0] BLKSEL,input wire WRE,CLK,CE,OCE,RESET);
 localparam [16383:0] CONTENT={INIT_RAM_3F,INIT_RAM_3E,INIT_RAM_3D,INIT_RAM_3C,INIT_RAM_3B,INIT_RAM_3A,INIT_RAM_39,INIT_RAM_38,INIT_RAM_37,INIT_RAM_36,INIT_RAM_35,INIT_RAM_34,INIT_RAM_33,INIT_RAM_32,INIT_RAM_31,INIT_RAM_30,INIT_RAM_2F,INIT_RAM_2E,INIT_RAM_2D,INIT_RAM_2C,INIT_RAM_2B,INIT_RAM_2A,INIT_RAM_29,INIT_RAM_28,INIT_RAM_27,INIT_RAM_26,INIT_RAM_25,INIT_RAM_24,INIT_RAM_23,INIT_RAM_22,INIT_RAM_21,INIT_RAM_20,INIT_RAM_1F,INIT_RAM_1E,INIT_RAM_1D,INIT_RAM_1C,INIT_RAM_1B,INIT_RAM_1A,INIT_RAM_19,INIT_RAM_18,INIT_RAM_17,INIT_RAM_16,INIT_RAM_15,INIT_RAM_14,INIT_RAM_13,INIT_RAM_12,INIT_RAM_11,INIT_RAM_10,INIT_RAM_0F,INIT_RAM_0E,INIT_RAM_0D,INIT_RAM_0C,INIT_RAM_0B,INIT_RAM_0A,INIT_RAM_09,INIT_RAM_08,INIT_RAM_07,INIT_RAM_06,INIT_RAM_05,INIT_RAM_04,INIT_RAM_03,INIT_RAM_02,INIT_RAM_01,INIT_RAM_00};
 reg [31:0] words[0:511];integer row;
 initial begin
  for(row=0;row<512;row=row+1)words[row]=CONTENT[row*32+:32];
  DO=0;
  if(BIT_WIDTH!=32||READ_MODE!=0||WRITE_MODE>1)$fatal(1,"Unsupported SP32 primitive configuration");
 end
 wire [31:0] byte_mask={{8{AD[3]}},{8{AD[2]}},{8{AD[1]}},{8{AD[0]}}};
 wire [31:0] merged_word=(words[AD[13:5]]&~byte_mask)|(DI&byte_mask);
 always @(posedge CLK)begin
  if(RESET||BLKSEL!=0)$fatal(1,"Unexpected SP reset/block selection");
  if(CE)begin
   if(WRE)begin words[AD[13:5]]<=merged_word;if(WRITE_MODE==1)DO<=merged_word;end
   else DO<=words[AD[13:5]];
  end
 end
endmodule
