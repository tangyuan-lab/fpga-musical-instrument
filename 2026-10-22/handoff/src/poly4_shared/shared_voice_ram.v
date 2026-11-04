// One 512x160 physical state store per voice. C=0..255, piano=256..319,
// legacy tom=320..447. No array reset, no read-before-write assumption.
module shared_voice_ram #(parameter integer WRITE_HOLD=0)(
 input wire clk,rst_n,
 input wire [2:0] request,write_enable,
 input wire [26:0] address,input wire [479:0] write_data,
 output reg [2:0] ready,output reg [2:0] response_valid,
 output wire [479:0] response_data
);
 reg [1:0] owner;
 reg found;
 always @*begin
  ready=0;owner=0;found=0;
  // Client 0 is the C deadline, 1 the legacy tom, 2 the background piano.
  if(rst_n)begin
   if(request[0])begin ready[0]=1;owner=0;found=1;end
   else if(request[1])begin ready[1]=1;owner=1;found=1;end
   else if(request[2])begin ready[2]=1;owner=2;found=1;end
  end
 end
 // Constant slices prevent a variable-width barrel selector in synthesis.
 wire [8:0] a=({9{ready[0]}}&address[0+:9])|({9{ready[1]}}&address[9+:9])|({9{ready[2]}}&address[18+:9]);
 wire [159:0] d=({160{ready[0]}}&write_data[0+:160])|({160{ready[1]}}&write_data[160+:160])|({160{ready[2]}}&write_data[320+:160]);
 wire w=|(write_enable&ready);wire [159:0] q;
 genvar lane;
 generate for(lane=0;lane<5;lane=lane+1)begin:lanes
  SP #(.BIT_WIDTH(32),.READ_MODE(1'b0),.WRITE_MODE(WRITE_HOLD?2'b00:2'b01),.RESET_MODE("SYNC")) ram(
   .DO(q[lane*32+:32]),.DI(d[lane*32+:32]),.AD({a,1'b0,4'b1111}),
   .BLKSEL(3'b0),.WRE(w),.CLK(clk),.CE(found),.OCE(1'b1),.RESET(1'b0));
 end endgenerate
 assign response_data={3{q}};
 always @(posedge clk)begin
  if(!rst_n)response_valid<=0;
  else response_valid<=ready;
 end
endmodule

// A piano row is three words. Read prefetch and writeback bursts fit under
// its modal arithmetic; this store never contends with the drum state port.
module shared_piano_state_store(
 input wire clk,rst_n,request,write_enable,input wire [8:0] address,
 input wire [159:0] write_data,output wire ready,output reg response_valid,
 output wire [159:0] response_data
);
 reg [1:0] phase;reg writing;reg [5:0] row;
 reg [63:0] read_low;wire [31:0] q;
 assign ready=rst_n&&phase==0;
 wire accepted=request&&ready;
 wire enable=rst_n&&(accepted||phase==1||phase==2);
 wire w=phase==0?write_enable:writing;
 wire [8:0] a={1'b0,phase==0?address[5:0]:row,phase==0?2'd0:phase};
 wire [31:0] d=phase==0?write_data[31:0]:phase==1?write_data[63:32]:write_data[95:64];
 SP #(.BIT_WIDTH(32),.READ_MODE(1'b0),.WRITE_MODE(2'b00),.RESET_MODE("SYNC")) memory(
  .DO(q),.DI(d),.AD({a,1'b0,4'b1111}),.BLKSEL(3'b0),.WRE(w),.CLK(clk),.CE(enable),.OCE(1'b1),.RESET(1'b0));
 assign response_data={64'd0,q,read_low};
 always @(posedge clk)begin
  if(!rst_n)begin phase<=0;writing<=0;response_valid<=0;end
  else begin
   response_valid<=0;
   case(phase)
    0:if(accepted)begin row<=address[5:0];writing<=write_enable;phase<=1;end
    1:begin if(!writing)read_low[31:0]<=q;phase<=2;end
    2:begin if(!writing)read_low[63:32]<=q;phase<=3;end
    3:begin response_valid<=!writing;phase<=0;end
   endcase
  end
 end
 // Data fields are consumed before their next modal result can overwrite
 // them: onset on grant, main one edge later, phase two edges later.
 // synthesis translate_off
 reg [95:0] accepted_payload;
 always @(posedge clk)if(rst_n)begin
  if(accepted&&write_enable)accepted_payload<=write_data[95:0];
  if(writing&&phase==1&&write_data[63:32]!==accepted_payload[63:32])$fatal(1,"Piano main write field changed before consumption");
  if(writing&&phase==2&&write_data[95:64]!==accepted_payload[95:64])$fatal(1,"Piano phase write field changed before consumption");
 end
 // synthesis translate_on
endmodule
