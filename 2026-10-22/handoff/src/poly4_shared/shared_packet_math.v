// Four-cycle scalar chirplet datapath, with at least five clocks between inputs.
// The core scheduler guarantees this spacing, so metadata needs only one copy.
// The LUTs contain mathematical functions.
// The body/noise scheduler uses the same LUT ports between packet operations.
module shared_packet_math(
 input wire clk,rst_n,in_valid,input wire [7:0] tag,
 input wire [31:0] phase,step,phase_step,input wire signed [31:0] step_delta,
 input wire signed [47:0] log_env,log_delta,input wire signed [39:0] log_accel,
 input wire [23:0] peak,input wire [11:0] body_phase,input wire [9:0] sqrt_index,
 output wire signed [15:0] cosine_q,output reg [16:0] math_q,
 output reg out_valid,output reg [7:0] out_tag,
 output reg signed [31:0] sample_q20,output reg [159:0] next_state
);
 reg signed [15:0] cosine[0:1023] /* synthesis syn_ramstyle="block_ram" */;
 reg signed [15:0] quarter_q;reg cos_negative,cos_zero;
 wire [11:0] cos_address=in_valid?phase[31:20]:body_phase;
 wire [9:0] quarter_address=cos_address[10]?-cos_address[9:0]:cos_address[9:0];
 assign cosine_q=cos_zero?16'sd0:cos_negative?-quarter_q:quarter_q;
 reg [16:0] math_table[0:2047] /* synthesis syn_ramstyle="block_ram" */;
 initial begin
  $readmemh("src/excitation_v3/cosine_quarter_1024x16.mem",cosine);
  $readmemh("src/excitation_v3/exp_sqrt_2048x17.mem",math_table);
 end
 always @(posedge clk)begin
  quarter_q<=cosine[quarter_address];
  cos_negative<=cos_address[11]^cos_address[10];
  cos_zero<=cos_address[10]&&cos_address[9:0]==0;
  math_q<=math_table[in_valid?{1'b0,log_env[39:30]}:{1'b1,sqrt_index}];
 end
 reg v0,v1,v2;reg [23:0] p0,e2;
 reg [40:0] gain1;reg [5:0] sh0,sh1;
 reg signed [15:0] c1,c2;
 wire signed [7:0] whole=log_env[47:40];
 wire [31:0] ph_next=phase+phase_step,st_next=step+step_delta;
 wire signed [47:0] le_next=log_env+log_delta,ld_next=log_delta+log_accel;
 wire signed [40:0] product=c2*$signed({1'b0,e2});
 always @(posedge clk)begin
  if(!rst_n)begin v0<=0;v1<=0;v2<=0;out_valid<=0;end
  else begin
   v0<=in_valid;v1<=v0;v2<=v1;out_valid<=v2;
   if(in_valid)begin
    out_tag<=tag;p0<=peak;next_state<={ph_next,st_next,le_next,ld_next};
    sh0<=whole>=0?0:(whole<=-63?63:-whole);
   end
   if(v0)begin gain1<=p0*math_q;c1<=cosine_q;sh1<=sh0;end
   if(v1)begin e2<=(gain1>>16)>>sh1;c2<=c1;end
   if(v2)begin sample_q20<=product>>>15;end
  end
 end
endmodule
