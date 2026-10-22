`include "src/poly4_shared/resource_ports.vh"
// One accepted 32x24 arithmetic pipeline, with next-mode ROM/RAM prefetch.
// Prefetch removes parameter waits without storing two complete contexts.
module shared_piano_modes(
 input wire clk,rst_n,start,first,started,held,drum_C,
 input wire [4:0] note,input wire [16:0] age,input wire [15:0] pitch,
 output reg done,output wire active,output wire signed [63:0] sum,
 output wire param_request,input wire param_ready,param_valid,output wire [10:0] param_address,input wire [287:0] param_data,
 output wire sine_request,input wire sine_ready,sine_valid,output wire [11:0] sine_address,input wire signed [15:0] sine_data,
 `RESOURCE_PORTS
);
 localparam IDLE=0,LOAD=1,PITCH=2,MAIN=3,ONSET=4,ENVELOPE=5,AMPLITUDE=6,DRAIN=7;
 reg [2:0] state;reg [5:0] index;
 reg f_first,f_started,f_held;reg [4:0] f_note;reg [15:0] f_pitch;
 reg pp_pending,pp_loaded,ps_pending,ps_loaded,read_pending,row_loaded,write_pending,ram_was_write;
 reg [5:0] read_index,write_index;reg [10:0] pp_address;
 reg [127:0] parameter_row;wire [95:0] oscillator_row=f_first?{parameter_row[95:64],parameter_row[63:48],16'd0,parameter_row[63:48],16'd0}:f_started?ram_q[95:0]:96'd0;
 reg [31:0] main_next,onset_next,phase_next;
 wire [23:0] decay=parameter_row[47:24],onset_decay=parameter_row[23:0];
 reg [9:0] ps_address;reg signed [15:0] sine_q;reg sine_negative,mode_muted;
 wire signed [55:0] mix;reg result_seen;
 assign active=1'b0;assign sum={{8{mix[55]}},mix};
 assign param_request=pp_pending&&(state==IDLE||state==LOAD||state>=ONSET);assign param_address=pp_address;
 assign sine_request=ps_pending;assign sine_address={2'd0,ps_address};
 assign ram_request=write_pending||(read_pending&&(state==IDLE||state==LOAD||state>=ONSET));assign ram_write=write_pending;
 assign ram_address=9'd256+(write_pending?write_index:read_index);
 assign ram_data={64'd0,phase_next,main_next,onset_next};
 wire [15:0] sine_magnitude=sine_q[15]?-sine_q:sine_q;
 wire [55:0] multiply_q=product0[55:0];
 wire [32:0] rounded_drop={1'b0,multiply_q[55:24]}+multiply_q[23];
 wire [32:0] nonzero_drop=rounded_drop==0?33'd1:rounded_drop;
 wire [31:0] main_source=oscillator_row[63:32],onset_source=oscillator_row[31:0];
 wire [33:0] difference={2'b0,state==MAIN?main_source:onset_source}-{1'b0,nonzero_drop};
 wire [31:0] decayed=difference[33]?32'd0:difference[31:0];
 wire [32:0] envelope_difference={1'b0,main_next}-{1'b0,onset_next};
 wire [31:0] next_envelope=envelope_difference[32]?0:envelope_difference[31:0];
 wire [32:0] bent_increment=multiply_q[47:15];
 wire [31:0] next_phase=oscillator_row[95:64]+(f_first?32'd0:bent_increment[31:0]);
 reg request;reg [31:0] a;reg [23:0] b;
 always @*begin
  request=0;a=0;b=0;
  case(state)
   LOAD:if(pp_loaded&&row_loaded&&(!write_pending||ram_ready))begin request=1;a=parameter_row[127:96];b={8'd0,f_pitch};end
   PITCH:if(mul_valid||result_seen)begin request=1;a=main_source;b=decay+(f_held?24'd0:24'd8192);end
   MAIN:if(mul_valid||result_seen)begin request=1;a=onset_source;b=onset_decay+(f_held?24'd0:24'd8192);end
   ENVELOPE:if(ps_loaded)begin request=1;a=mode_muted?0:next_envelope;b={8'd0,sine_magnitude};end
  endcase
 end
 assign mul_request=request;assign mul_pair=0;assign mul_a0={4'd0,a};assign mul_b0={3'd0,b};
 assign mul_a1=0;assign mul_b1=0;assign mul_tag=0;

 wire mix_clear=state==IDLE&&start;
 shared_wide_accumulator #(.WIDTH(56)) modal_accumulator(.clk(clk),.rst_n(rst_n),
  .enable(mix_clear||state==AMPLITUDE&&mul_valid),.clear(mix_clear),.load(1'b0),
  .subtract(sine_negative),.value(multiply_q),.sum(mix));
 always @(posedge clk)begin
  if(!rst_n)begin
   state<=IDLE;done<=0;pp_pending<=0;pp_loaded<=0;ps_pending<=0;ps_loaded<=0;
   read_pending<=0;row_loaded<=0;write_pending<=0;ram_was_write<=0;result_seen<=0;
  end else begin
   done<=0;
   if(param_request&&param_ready)pp_pending<=0;
   if(param_valid)begin parameter_row<=param_data[127:0];pp_loaded<=1;end
   if(ps_pending&&sine_ready)ps_pending<=0;
   if(sine_valid)begin sine_q<=sine_data;ps_loaded<=1;end
   if(ram_request&&ram_ready)begin ram_was_write<=ram_write;if(ram_write)write_pending<=0;else read_pending<=0;end
   if(ram_valid&&!ram_was_write)row_loaded<=1;
   if(mul_valid)result_seen<=1;
   case(state)
    IDLE:if(start)begin
     f_first<=first;f_started<=started;f_held<=held;f_note<=note;f_pitch<=pitch;
     index<=0;pp_address<={note,6'd0};pp_pending<=1;pp_loaded<=0;
     read_index<=0;read_pending<=1;row_loaded<=0;result_seen<=0;state<=LOAD;
    end
    LOAD:if(request&&mul_ready)begin

     if(index!=63)begin pp_address<={f_note,index+6'd1};pp_pending<=1;pp_loaded<=0;read_index<=index+1'b1;read_pending<=1;row_loaded<=0;end
     result_seen<=0;state<=PITCH;
    end
    PITCH:begin
     if(mul_valid)begin phase_next<=next_phase;ps_address<=next_phase[31:22];mode_muted<=bent_increment>=33'h080000000;ps_pending<=1;ps_loaded<=0;end
     if(request&&mul_ready)begin result_seen<=0;state<=MAIN;end
    end
    MAIN:begin
     if(mul_valid)main_next<=f_first?main_source:decayed;
     if(request&&mul_ready)begin result_seen<=0;state<=ONSET;end
    end
    ONSET:if(mul_valid)begin onset_next<=f_first?onset_source:decayed;result_seen<=0;state<=ENVELOPE;end
    ENVELOPE:if(request&&mul_ready)begin sine_negative<=sine_q[15];state<=AMPLITUDE;end
    AMPLITUDE:if(mul_valid)begin
     
     write_index<=index;write_pending<=1;result_seen<=0;
     if(index==63)state<=DRAIN;else begin index<=index+1'b1;state<=LOAD;end
    end
    DRAIN:if(!write_pending||ram_ready)begin done<=1;state<=IDLE;end
    default:state<=IDLE;
   endcase
  end
 end
endmodule

// Full WIDTH-bit modulo arithmetic, using an Arora V48bit ALU for the high
// bits. The low slice supplies the exact carry/borrow as a one-bit product.
module shared_wide_accumulator #(parameter integer WIDTH=56)(
 input wire clk,rst_n,enable,clear,load,subtract,
 input wire [WIDTH-1:0] value,output wire [WIDTH-1:0] sum
);
 localparam integer LOW=WIDTH-48;
 reg [LOW-1:0] low;
 wire [47:0] high;
 wire sub=subtract&&!load&&!clear;
 wire [LOW:0] low_add={1'b0,low}+{1'b0,(value[LOW-1:0]^{LOW{sub}})}+sub;
 wire carry=(low_add[LOW]^sub)&&!load&&!clear;
 // synthesis translate_off
 GSR GSR(.GSRI(1'b1));
 // synthesis translate_on
 MULTALU27X18 #(.OREG_CLK("CLK0"),.DYN_ACC_SEL("TRUE"),
  .DYN_C_SEL("FALSE"),.C_SEL(1'b1),.DYN_ADD_SUB_0("TRUE"),.DYN_ADD_SUB_1("TRUE"),.PRE_LOAD(48'd0)) high_acc(
  .A({26'd0,carry}),.B(18'd1),.C(value[WIDTH-1:LOW]),.D(26'd0),.SIA(27'd0),.CASI(48'd0),
  .PSEL(1'b0),.ASEL(1'b0),.CSEL(1'b1),.CASISEL(1'b0),.PADDSUB(1'b0),
  .ACCSEL(!load&&!clear),.ADDSUB({sub,sub}),.CLK({1'b0,clk}),.CE({1'b0,enable}),
  .RESET({1'b0,(!rst_n||enable&&clear)}),.DOUT(high),.CASO(),.SOA());
 always @(posedge clk)begin
  if(!rst_n)low<=0;
  else if(enable)low<=clear?0:load?value[LOW-1:0]:low_add[LOW-1:0];
 end
 assign sum={high,low};
endmodule
