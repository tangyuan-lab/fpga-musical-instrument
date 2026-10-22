`include "src/poly4_shared/resource_ports.vh"
// Mid/high tom controller, streaming modal kernel, and the production resources.
module T_test_fixture #(parameter integer ADSR_ENABLE=0)(
 input wire clk,rst_n,sample_tick,note_on,note_off,note_active,
 input wire [4:0] note_index,input wire [6:0] velocity,input wire [15:0] pitch_ratio_q15,
 output wire signed [15:0] sample_out,output wire sample_valid,active,overrun,
 output wire tp_request,input wire tp_ready,tp_valid,output wire [7:0] tp_address,input wire [255:0] tp_data,
 output wire ts_request,input wire ts_ready,ts_valid,output wire [11:0] ts_address,input wire [15:0] ts_data,
 output wire tn_request,input wire tn_ready,tn_valid,output wire [3:0] tn_address,input wire [127:0] tn_data
);
 `RESOURCE_WIRES(t_)
 `RESOURCE_WIRES(d_)
 `DRUM_JOB_WIRES(t_)
 `TOM_POST_WIRES
 wire busy,owner;wire [1:0] ready,done;wire [10:0] parameter_address;
 wire modal_active;wire signed [63:0] modal_sum;
 reg [287:0] retained_parameter;reg [159:0] retained_row;reg [1:0] returned_write;
 wire [287:0] normalized_tom_parameter=
  {56'd0,8'd0,tp_data[191:168],8'd0,tp_data[191:168],tp_data[167:120],tp_data[223:192],tp_data[255:224],tp_data[119:88],tp_data[87:64]};
 always @(posedge clk)begin
  if(!rst_n)returned_write<=0;
  else begin
   if(tp_valid)retained_parameter<=normalized_tom_parameter;
   else if(tn_valid)retained_parameter<={160'd0,tn_data};
   if(rr[0])returned_write[0]<=t_ram_write;
   if(rr[1])returned_write[1]<=d_ram_write;
   if((rv[0]&&!returned_write[0])||(rv[1]&&!returned_write[1]))retained_row<=rd[0+:160];
  end
 end
 shared_tom_adapter #(.ADSR_ENABLE(ADSR_ENABLE)) core(.clk(clk),.rst_n(rst_n),.sample_tick(sample_tick),.adsr_tick(sample_tick),
  .note_on(note_on),.note_off(note_off),.note_active(note_active),.note_index(note_index),.velocity(velocity),.pitch_ratio_q15(pitch_ratio_q15),
  .sample_out(sample_out),.sample_valid(sample_valid),.active(active),.overrun(overrun),
  `TOM_POST_LINK,`DRUM_JOB_LINK(t_));
 shared_C_core #(.EXTERNAL_BANKS(1)) post_controller(.clk(clk),.rst_n(rst_n),.tick24(1'b0),.note_on(1'b0),.cancel_C(1'b0),.velocity(7'd0),.pitch_ratio_q15(16'd32768),
  .retained_parameter(retained_parameter),.retained_row(retained_row),
  .cp_request(),.cp_ready(1'b0),.cp_valid(1'b0),.cp_address(),.cp_data(288'd0),
  .raw_q20(),.even_q20(),.odd_q20(),.even_pcm(),.odd_pcm(),.pair_valid(),.raw_valid(),.overrun(),
  `TOM_POST_LINK,`TOM_NOISE_LINK,`RESOURCE_LINK(t_),
  .modal_request(),.modal_first(),.modal_started(),.modal_ready(1'b0),.modal_done(1'b0),.modal_note(),.modal_age(),.modal_pitch(),
  .modal_sum(64'd0),.modal_active(1'b0),.modal_phase(12'd0),.modal_cosine());
 shared_drum_modes #(.EXTERNAL_BANKS(1)) modes(.clk(clk),.rst_n(rst_n),.abort_C(1'b0),.request({t_modal_request,1'b0}),.first({t_modal_first,1'b0}),.started({t_modal_started,1'b0}),
  .retained_parameter(retained_parameter),.retained_row(retained_row),
  .note({t_modal_note,5'd0}),.age({t_modal_age,17'd0}),.pitch({t_modal_pitch,16'd0}),.ready(ready),.done(done),
  .active(modal_active),.sum(modal_sum),.busy(busy),.C_owner(owner),
  .param_request(tp_request),.param_ready(tp_ready),.param_valid(tp_valid),.param_address(parameter_address),.param_data({32'd0,tp_data}),
  .sine_request(ts_request),.sine_ready(ts_ready),.sine_valid(ts_valid),.sine_address(ts_address),.sine_data(ts_data),`RESOURCE_LINK(d_));
 assign tp_address=parameter_address[7:0];
 assign t_modal_ready=ready[1];assign t_modal_done=done[1];assign t_modal_sum=modal_sum;assign t_modal_active=modal_active;
 wire [2:0] rr,rv,mr,mv;wire [479:0] rd;wire [188:0] mp0,mp1;wire [17:0] tags;
 shared_voice_ram memory(.clk(clk),.rst_n(rst_n),.request({1'b0,d_ram_request,t_ram_request}),.write_enable({1'b0,d_ram_write,t_ram_write}),
  .address({9'd0,d_ram_address,t_ram_address}),.write_data({160'd0,d_ram_data,t_ram_data}),.ready(rr),.response_valid(rv),.response_data(rd));
 shared_voice_mul #(.RESPONSE_CYCLES(2)) arithmetic(.clk(clk),.rst_n(rst_n),.request({1'b0,d_mul_request,t_mul_request}),.pair({1'b0,d_mul_pair,t_mul_pair}),
  .a0({36'd0,d_mul_a0,t_mul_a0}),.a1({36'd0,d_mul_a1,t_mul_a1}),.b0({27'd0,d_mul_b0,t_mul_b0}),.b1({27'd0,d_mul_b1,t_mul_b1}),
  .tag({6'd0,d_mul_tag,t_mul_tag}),.ready(mr),.response_valid(mv),.product0(mp0),.product1(mp1),.response_tag(tags));
 assign t_ram_ready=rr[0];assign t_ram_valid=rv[0];assign t_ram_q=rd[0+:160];
 assign d_ram_ready=rr[1];assign d_ram_valid=rv[1];assign d_ram_q=rd[160+:160];
 assign t_mul_ready=mr[0];assign t_mul_valid=mv[0];assign t_product0=mp0[0+:63];assign t_product1=mp1[0+:63];assign t_result_tag=tags[0+:6];
 assign d_mul_ready=mr[1];assign d_mul_valid=mv[1];assign d_product0=mp0[63+:63];assign d_product1=mp1[63+:63];assign d_result_tag=tags[6+:6];
endmodule
