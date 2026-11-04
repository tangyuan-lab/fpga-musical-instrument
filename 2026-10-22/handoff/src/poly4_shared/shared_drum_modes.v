`include "src/poly4_shared/resource_ports.vh"
// One two-context modal scheduler serves mutually exclusive C/legacy drums.
// Metadata is accepted with ready; a request may wait while an old job drains.
module shared_drum_modes #(parameter integer EXTERNAL_BANKS=0)(
 input wire clk,rst_n,abort_C,input wire [1:0] request,first,started,
 input wire [9:0] note,input wire [33:0] age,input wire [31:0] pitch,
 output wire [1:0] ready,done,output wire active,output wire signed [63:0] sum,
 output reg busy,output wire C_owner,
 output wire param_request,input wire param_ready,param_valid,
 input wire [287:0] retained_parameter,input wire [159:0] retained_row,
 output wire [10:0] param_address,input wire [287:0] param_data,
 output wire sine_request,input wire sine_ready,sine_valid,
 output wire [11:0] sine_address,input wire signed [15:0] sine_data,
 `RESOURCE_PORTS
);
 reg owner;wire chosen=request[0]?1'b0:1'b1;
 wire abort_modal=abort_C&&(!busy||!owner);
 wire launch=!busy&&(|request);wire finish;
 assign ready=launch?(chosen?2'b10:2'b01):2'b00;
 assign done=finish?(owner?2'b10:2'b01):2'b00;
 assign C_owner=busy&&!owner;
 shared_drum_stream #(.EXTERNAL_BANKS(EXTERNAL_BANKS)) modes(.clk(clk),.rst_n(rst_n&&!abort_modal),.start(launch),.drum_C(!chosen),
  .retained_parameter(retained_parameter),.retained_row(retained_row),
  .first(chosen?first[1]:first[0]),.started(chosen?started[1]:started[0]),.held(1'b0),
  .note(chosen?note[5+:5]:note[0+:5]),.age(chosen?age[17+:17]:age[0+:17]),.pitch(chosen?pitch[16+:16]:pitch[0+:16]),
  .done(finish),.active(active),.sum(sum),
  .param_request(param_request),.param_ready(param_ready),.param_valid(param_valid),.param_address(param_address),.param_data(param_data),
  .sine_request(sine_request),.sine_ready(sine_ready),.sine_valid(sine_valid),.sine_address(sine_address),.sine_data(sine_data),`RESOURCE_DIRECT_LINK);
 always @(posedge clk)begin
  if(!rst_n||abort_modal)begin busy<=0;owner<=0;end
  else begin if(launch)begin busy<=1;owner<=chosen;end;if(finish)busy<=0;end
 end
endmodule
