// Candidate three-instrument controller. Not connected to an accepted project.
// Physical K2 selects; K3 selects/triggers the next note. Off events retain
// the timbre/note captured on the corresponding down event.
module guitar_audition_controller #(parameter integer KEY_FILTER_MAX=250000)(
 input wire clk,rst_n,key2_n,key3_n,
 output wire event_valid,input wire event_ready,
 output wire event_on,output wire [4:0] event_key,
 output wire [1:0] event_timbre,output wire [4:0] event_note,
 output wire [6:0] event_velocity,
 output reg [1:0] selected_timbre,output reg overflow
);
 wire k2_state,k2_down,k2_up,k3_state,k3_down,k3_up;
 key_debounce #(.KEY_FILTER_MAX(KEY_FILTER_MAX)) k2(.sys_clk(clk),.sys_rst_n(rst_n),
  .key_n(key2_n),.key_state(k2_state),.note_on(k2_down),.note_off(k2_up));
 key_debounce #(.KEY_FILTER_MAX(KEY_FILTER_MAX)) k3(.sys_clk(clk),.sys_rst_n(rst_n),
  .key_n(key3_n),.key_state(k3_state),.note_on(k3_down),.note_off(k3_up));
 reg [4:0] piano_next;
 reg [2:0] drum_next;
 reg [3:0] guitar_next;
 reg held_valid;
 reg [1:0] held_timbre;
 reg [4:0] held_note;
 reg [19:0] queue[0:7];
 reg [2:0] rd,wr;
 reg [3:0] count;
 wire [1:0] next_timbre=selected_timbre==2 ? 2'd0 : selected_timbre+1'b1;
 wire [1:0] chosen=k2_down ? next_timbre : selected_timbre;
 wire [4:0] chosen_note=chosen==0 ? piano_next : chosen==1 ? {2'd0,drum_next} : {1'd0,guitar_next};
 wire push=k3_down||(k3_up&&held_valid);
 wire pop=event_valid&&event_ready;
 wire accepted_push=push&&(count<8||pop);
 assign event_valid=count!=0;
 assign {event_on,event_key,event_timbre,event_note,event_velocity}=queue[rd];
 always @(posedge clk)begin
  if(!rst_n)begin
   selected_timbre<=0;piano_next<=16;drum_next<=0;guitar_next<=0;
   held_valid<=0;held_timbre<=0;held_note<=0;
   rd<=0;wr<=0;count<=0;overflow<=0;
  end else begin
   if(k2_down)selected_timbre<=next_timbre;
   if(accepted_push)begin
    queue[wr]<={k3_down,5'd31,k3_down ? chosen : held_timbre,
                k3_down ? chosen_note : held_note,7'd112};
    wr<=wr+1'b1;
    if(k3_down)begin
     held_valid<=1;held_timbre<=chosen;held_note<=chosen_note;
     case(chosen)
      0:piano_next<=piano_next==16 ? 0 : piano_next+1'b1;
      1:drum_next<=drum_next==7 ? 0 : drum_next+1'b1;
      2:guitar_next<=guitar_next+1'b1;
      default:begin end
     endcase
    end else held_valid<=0;
   end
   if(push&&!accepted_push)overflow<=1;
   if(pop)rd<=rd+1'b1;
   case({accepted_push,pop})
    2'b10:count<=count+1'b1;
    2'b01:count<=count-1'b1;
    default:count<=count;
   endcase
  end
 end
endmodule
