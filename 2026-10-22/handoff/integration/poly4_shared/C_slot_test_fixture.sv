`include "src/poly4_shared/resource_ports.vh"
// The same C/controller, shared drum scheduler and physical resources as a slot.
// Coefficient ports remain independent from the accepted reference in tb_C.
module C_test_fixture(
 input wire clk,rst_n,tick24,note_on,input wire [15:0] pitch_ratio_q15,input wire [6:0] velocity,
 output wire cp_request,input wire cp_ready,cp_valid,output wire [7:0] cp_address,input wire [287:0] cp_data,
 output wire signed [31:0] even_q20,odd_q20,raw_q20,
 output wire signed [15:0] even_pcm,odd_pcm,output wire pair_valid,raw_valid,overrun
);
 `RESOURCE_WIRES(c_)
 `RESOURCE_WIRES(d_)
 `DRUM_JOB_WIRES(c_)
 wire modal_busy,modal_owner,modal_active;wire signed [63:0] modal_sum;
 wire [1:0] modal_ready,modal_done;
 wire modal_parameter_request;wire [10:0] modal_parameter_address;
 wire modal_sine_request;reg modal_sine_valid;
 wire [11:0] modal_phase;wire signed [15:0] modal_cosine;
 wire core_cp_request;wire [7:0] core_cp_address;
 reg [1:0] header_partial;
 always @(posedge clk)begin
  if(!rst_n)header_partial<=0;
  else header_partial<={header_partial[0],cp_request&&cp_ready&&cp_address>=193&&cp_address<=215&&cp_address[0]};
 end
 reg [287:0] retained_parameter;wire [159:0] retained_row=rd[159:0];reg [1:0] returned_write;
 always @(posedge clk)begin
  if(!rst_n)returned_write<=0;
  else begin
   if(cp_valid)begin
    // Only ENV1's lower128 bits are meaningful. Keep this band's seed and
    // filter coefficients in the existing upper bank, without another128FF.
    if(header_partial[1])retained_parameter[127:0]<=cp_data[127:0];
    else retained_parameter<=cp_data;
   end
   if(rr[0])returned_write[0]<=c_ram_write;
   if(rr[1])returned_write[1]<=d_ram_write;

  end
 end
 shared_C_core #(.EXTERNAL_BANKS(1)) core(.clk(clk),.rst_n(rst_n),.tick24(tick24),.note_on(note_on),.cancel_C(1'b0),.velocity(velocity),.pitch_ratio_q15(pitch_ratio_q15),
  .retained_parameter(retained_parameter),.retained_row(retained_row),
  .post_request(1'b0),.post_first(1'b0),.post_started(1'b0),.post_modal_active(1'b0),.post_adsr_enable(1'b0),
  .post_bank(2'd0),.post_velocity(7'd0),.post_white(16'd0),.post_sum(56'd0),.post_adsr_gain(16'hffff),
  .tn_ready(1'b0),.tn_valid(1'b0),.tn_data(128'd0),
  .cp_request(core_cp_request),.cp_ready(cp_ready),.cp_valid(cp_valid),.cp_address(core_cp_address),.cp_data(cp_data),
  .raw_q20(raw_q20),.even_q20(even_q20),.odd_q20(odd_q20),.even_pcm(even_pcm),.odd_pcm(odd_pcm),
  .pair_valid(pair_valid),.raw_valid(raw_valid),.overrun(overrun),`RESOURCE_LINK(c_),`DRUM_JOB_LINK(c_),
  .modal_phase(modal_phase),.modal_cosine(modal_cosine));
 shared_drum_modes #(.EXTERNAL_BANKS(1)) modes(.clk(clk),.rst_n(rst_n),.abort_C(1'b0),.request({1'b0,c_modal_request}),.first({1'b0,c_modal_first}),
  .retained_parameter(retained_parameter),.retained_row(retained_row),
  .started({1'b0,c_modal_started}),.note({5'd0,c_modal_note}),.age({17'd0,c_modal_age}),.pitch({16'd0,c_modal_pitch}),
  .ready(modal_ready),.done(modal_done),.active(modal_active),.sum(modal_sum),.busy(modal_busy),.C_owner(modal_owner),
  .param_request(modal_parameter_request),.param_ready(cp_ready),.param_valid(cp_valid),.param_address(modal_parameter_address),.param_data(cp_data),
  .sine_request(modal_sine_request),.sine_ready(modal_sine_request),.sine_valid(modal_sine_valid),.sine_address(modal_phase),.sine_data(modal_cosine),`RESOURCE_LINK(d_));
 assign cp_request=modal_owner?modal_parameter_request:core_cp_request;
 assign cp_address=modal_owner?modal_parameter_address[7:0]:core_cp_address;
 assign c_modal_ready=modal_ready[0];assign c_modal_done=modal_done[0];assign c_modal_sum=modal_sum;assign c_modal_active=modal_active;
 always @(posedge clk)begin if(!rst_n)modal_sine_valid<=0;else modal_sine_valid<=modal_owner&&modal_sine_request;end
 wire [2:0] rr,rv,mr,mv;wire [479:0] rd;wire [188:0] mp0,mp1;wire [17:0] tags;
 shared_voice_ram #(.WRITE_HOLD(1)) memory(.clk(clk),.rst_n(rst_n),.request({1'b0,d_ram_request,c_ram_request}),.write_enable({1'b0,d_ram_write,c_ram_write}),
  .address({9'd0,d_ram_address,c_ram_address}),.write_data({160'd0,d_ram_data,c_ram_data}),.ready(rr),.response_valid(rv),.response_data(rd));
 shared_voice_mul #(.RESPONSE_CYCLES(2)) arithmetic(.clk(clk),.rst_n(rst_n),.request({1'b0,d_mul_request,c_mul_request}),.pair({1'b0,d_mul_pair,c_mul_pair}),
  .a0({36'd0,d_mul_a0,c_mul_a0}),.a1({36'd0,d_mul_a1,c_mul_a1}),.b0({27'd0,d_mul_b0,c_mul_b0}),.b1({27'd0,d_mul_b1,c_mul_b1}),
  .tag({6'd0,d_mul_tag,c_mul_tag}),.ready(mr),.response_valid(mv),.product0(mp0),.product1(mp1),.response_tag(tags));
 assign c_ram_ready=rr[0];assign c_ram_valid=rv[0];assign c_ram_q=rd[0+:160];
 assign d_ram_ready=rr[1];assign d_ram_valid=rv[1];assign d_ram_q=rd[160+:160];
 assign c_mul_ready=mr[0];assign c_mul_valid=mv[0];assign c_product0=mp0[0+:63];assign c_product1=mp1[0+:63];assign c_result_tag=tags[0+:6];
 assign d_mul_ready=mr[1];assign d_mul_valid=mv[1];assign d_product0=mp0[63+:63];assign d_product1=mp1[63+:63];assign d_result_tag=tags[6+:6];
endmodule
