`ifndef POLY4_SHARED_RESOURCE_PORTS
`define POLY4_SHARED_RESOURCE_PORTS
`define RESOURCE_PORTS \
 output wire ram_request,ram_write,input wire ram_ready,ram_valid, \
 output wire [8:0] ram_address,output wire [159:0] ram_data,input wire [159:0] ram_q, \
 output wire mul_request,mul_pair,input wire mul_ready,mul_valid, \
 output wire signed [35:0] mul_a0,mul_a1,output wire signed [26:0] mul_b0,mul_b1, \
 output wire [5:0] mul_tag,input wire [5:0] result_tag, \
 input wire signed [62:0] product0,product1
`define RESOURCE_WIRES(P) \
 wire P``ram_request,P``ram_write,P``ram_ready,P``ram_valid; \
 wire [8:0] P``ram_address;wire [159:0] P``ram_data,P``ram_q; \
 wire P``mul_request,P``mul_pair,P``mul_ready,P``mul_valid; \
 wire signed [35:0] P``mul_a0,P``mul_a1;wire signed [26:0] P``mul_b0,P``mul_b1; \
 wire [5:0] P``mul_tag,P``result_tag;wire signed [62:0] P``product0,P``product1;
`define RESOURCE_LINK(P) \
 .ram_request(P``ram_request),.ram_write(P``ram_write),.ram_ready(P``ram_ready),.ram_valid(P``ram_valid), \
 .ram_address(P``ram_address),.ram_data(P``ram_data),.ram_q(P``ram_q), \
 .mul_request(P``mul_request),.mul_pair(P``mul_pair),.mul_ready(P``mul_ready),.mul_valid(P``mul_valid), \
 .mul_a0(P``mul_a0),.mul_a1(P``mul_a1),.mul_b0(P``mul_b0),.mul_b1(P``mul_b1), \
 .mul_tag(P``mul_tag),.result_tag(P``result_tag),.product0(P``product0),.product1(P``product1)
`define RESOURCE_DIRECT_LINK \
 .ram_request(ram_request),.ram_write(ram_write),.ram_ready(ram_ready),.ram_valid(ram_valid), \
 .ram_address(ram_address),.ram_data(ram_data),.ram_q(ram_q), \
 .mul_request(mul_request),.mul_pair(mul_pair),.mul_ready(mul_ready),.mul_valid(mul_valid), \
 .mul_a0(mul_a0),.mul_a1(mul_a1),.mul_b0(mul_b0),.mul_b1(mul_b1), \
 .mul_tag(mul_tag),.result_tag(result_tag),.product0(product0),.product1(product1)
`define DRUM_JOB_PORTS \
 output wire modal_request,modal_first,modal_started,input wire modal_ready,modal_done, \
 output wire [4:0] modal_note,output wire [16:0] modal_age,output wire [15:0] modal_pitch, \
 input wire signed [63:0] modal_sum,input wire modal_active
`define DRUM_JOB_WIRES(P) \
 wire P``modal_request,P``modal_first,P``modal_started,P``modal_ready,P``modal_done,P``modal_active; \
 wire [4:0] P``modal_note;wire [16:0] P``modal_age;wire [15:0] P``modal_pitch;wire signed [63:0] P``modal_sum;
`define DRUM_JOB_LINK(P) \
 .modal_request(P``modal_request),.modal_first(P``modal_first),.modal_started(P``modal_started),.modal_ready(P``modal_ready),.modal_done(P``modal_done), \
 .modal_note(P``modal_note),.modal_age(P``modal_age),.modal_pitch(P``modal_pitch),.modal_sum(P``modal_sum),.modal_active(P``modal_active)
`define DRUM_JOB_DIRECT_LINK \
 .modal_request(modal_request),.modal_first(modal_first),.modal_started(modal_started),.modal_ready(modal_ready),.modal_done(modal_done), \
 .modal_note(modal_note),.modal_age(modal_age),.modal_pitch(modal_pitch),.modal_sum(modal_sum),.modal_active(modal_active)
`define TOM_POST_PORTS \
 input wire post_request,output wire post_ready,output reg post_valid,post_active, \
 output reg signed [15:0] post_sample, \
 input wire post_first,post_started,post_modal_active,post_adsr_enable, \
 input wire [1:0] post_bank,input wire [6:0] post_velocity, \
 input wire signed [15:0] post_white,input wire signed [55:0] post_sum, \
 input wire [15:0] post_adsr_gain, \
 output wire tn_request,input wire tn_ready,tn_valid,output wire [3:0] tn_address,input wire [127:0] tn_data
`define TOM_POST_WIRES \
 wire post_request,post_ready,post_valid,post_active,post_first,post_started,post_modal_active,post_adsr_enable; \
 wire signed [15:0] post_sample,post_white;wire signed [55:0] post_sum; \
 wire [1:0] post_bank;wire [6:0] post_velocity;wire [15:0] post_adsr_gain;
`define TOM_POST_LINK \
 .post_request(post_request),.post_ready(post_ready),.post_valid(post_valid),.post_active(post_active),.post_sample(post_sample), \
 .post_first(post_first),.post_started(post_started),.post_modal_active(post_modal_active),.post_adsr_enable(post_adsr_enable), \
 .post_bank(post_bank),.post_velocity(post_velocity),.post_white(post_white),.post_sum(post_sum),.post_adsr_gain(post_adsr_gain)
`define TOM_NOISE_LINK \
 .tn_request(tn_request),.tn_ready(tn_ready),.tn_valid(tn_valid),.tn_address(tn_address),.tn_data(tn_data)
`endif
