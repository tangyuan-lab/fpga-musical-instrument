// One tagged client job per edge, two exact signed 36x27 lanes.
// A paired job uses both lanes. Scalar jobs use lane 0, keeping return wiring
// common to all clients. Four voice slots retain their independent resources.
module shared_voice_mul #(parameter integer TAG_WIDTH=6,RESPONSE_CYCLES=3,PIANO_SECOND_LANE=0,FIXED_DRUM_OWNER=0)(
 input wire clk,rst_n,input wire drum_owner,input wire [2:0] request,pair,
 input wire [107:0] a0,a1,input wire [80:0] b0,b1,
 input wire [3*TAG_WIDTH-1:0] tag,
 output wire [2:0] ready,response_valid,output wire [188:0] product0,product1,
 output wire [3*TAG_WIDTH-1:0] response_tag
);
 wire [1:0] drum_grant=rst_n?(request[0]?2'b01:request[1]?2'b10:2'b00):2'b00;
 wire piano_grant=rst_n&&request[2]&&!(|(drum_grant&pair[1:0]));
 wire [2:0] grant=PIANO_SECOND_LANE?{piano_grant,drum_grant}:
  rst_n?(request[0]?3'b001:request[1]?3'b010:request[2]?3'b100:3'b000):3'b000;
 assign ready=grant;
 wire [2:0] second=grant&pair;
 wire signed [35:0] selected_a0=FIXED_DRUM_OWNER?(drum_owner?a0[36+:36]:a0[0+:36]):(({36{grant[0]}}&a0[0+:36])|({36{grant[1]}}&a0[36+:36])|({36{grant[2]&&!PIANO_SECOND_LANE}}&a0[72+:36]));
 wire signed [26:0] selected_b0=FIXED_DRUM_OWNER?(drum_owner?b0[27+:27]:b0[0+:27]):(({27{grant[0]}}&b0[0+:27])|({27{grant[1]}}&b0[27+:27])|({27{grant[2]&&!PIANO_SECOND_LANE}}&b0[54+:27]));
 wire signed [35:0] selected_a1=FIXED_DRUM_OWNER?(PIANO_SECOND_LANE&&piano_grant?a0[72+:36]:(drum_owner?a1[36+:36]:a1[0+:36])):(PIANO_SECOND_LANE&&piano_grant?$signed(a0[72+:36]):({36{second[0]}}&a1[0+:36])|({36{second[1]}}&a1[36+:36])|({36{second[2]}}&a1[72+:36]));
 wire signed [26:0] selected_b1=FIXED_DRUM_OWNER?(PIANO_SECOND_LANE&&piano_grant?b0[54+:27]:(drum_owner?b1[27+:27]:b1[0+:27])):(PIANO_SECOND_LANE&&piano_grant?$signed(b0[54+:27]):({27{second[0]}}&b1[0+:27])|({27{second[1]}}&b1[27+:27])|({27{second[2]}}&b1[54+:27]));
 wire [TAG_WIDTH-1:0] selected_tag=FIXED_DRUM_OWNER?(drum_owner?tag[TAG_WIDTH+:TAG_WIDTH]:tag[0+:TAG_WIDTH]):(({TAG_WIDTH{grant[0]}}&tag[0+:TAG_WIDTH])|({TAG_WIDTH{grant[1]}}&tag[TAG_WIDTH+:TAG_WIDTH])|({TAG_WIDTH{grant[2]&&!PIANO_SECOND_LANE}}&tag[2*TAG_WIDTH+:TAG_WIDTH]));
 reg [TAG_WIDTH-1:0] piano_tag0,piano_tag1,piano_tag2;
 reg signed [35:0] ax0,ax1;reg signed [26:0] bx0,bx1;
 reg signed [62:0] p0,p1,q0,q1;
 reg [2:0] valid0,valid1,valid2;reg [TAG_WIDTH-1:0] tag0,tag1,tag2;
 always @(posedge clk)begin
  ax0<=selected_a0;ax1<=selected_a1;bx0<=selected_b0;bx1<=selected_b1;
  p0<=ax0*bx0;p1<=ax1*bx1;q0<=p0;q1<=p1;
  piano_tag0<=tag[2*TAG_WIDTH+:TAG_WIDTH];piano_tag1<=piano_tag0;piano_tag2<=piano_tag1;
  tag0<=selected_tag;tag1<=tag0;tag2<=tag1;
  if(!rst_n)begin valid0<=0;valid1<=0;valid2<=0;end
  else begin valid0<=grant;valid1<=valid0;valid2<=valid1;end
 end
 assign response_valid=RESPONSE_CYCLES==2?valid1:valid2;
 assign product0=PIANO_SECOND_LANE?{(RESPONSE_CYCLES==2?p1:q1),{2{RESPONSE_CYCLES==2?p0:q0}}}:{3{RESPONSE_CYCLES==2?p0:q0}};
 assign product1={3{RESPONSE_CYCLES==2?p1:q1}};
 assign response_tag=PIANO_SECOND_LANE?{(RESPONSE_CYCLES==2?piano_tag1:piano_tag2),{2{RESPONSE_CYCLES==2?tag1:tag2}}}:{3{RESPONSE_CYCLES==2?tag1:tag2}};
// synthesis translate_off
 always @(posedge clk)if(rst_n&&FIXED_DRUM_OWNER)begin
  if(request[0]&&request[1])$fatal(1,"Fixed math owner overlap");
  if(request[0]&&drum_owner||request[1]&&!drum_owner)$fatal(1,"Wrong fixed math owner");
 end
 // synthesis translate_on
endmodule
