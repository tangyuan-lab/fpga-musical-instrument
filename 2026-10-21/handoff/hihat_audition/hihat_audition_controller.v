// Board keys only. Future keyboards feed instrument_engine's event interface.
module hihat_audition_controller #(parameter integer KEY_FILTER_MAX=250000)(
    input wire clk,rst_n,key1_n,key2_n,
    output wire event_valid,input wire event_ready,
    output wire event_on,output wire [4:0] event_key,
    output wire event_timbre,output wire [4:0] event_note,
    output wire [6:0] event_velocity,
    output reg selected_timbre,output reg overflow
);
    wire k1_state,k1_down,k1_up,k2_state,k2_down,k2_up;
    key_debounce #(.KEY_FILTER_MAX(KEY_FILTER_MAX)) k1(.sys_clk(clk),.sys_rst_n(rst_n),
        .key_n(key1_n),.key_state(k1_state),.note_on(k1_down),.note_off(k1_up));
    key_debounce #(.KEY_FILTER_MAX(KEY_FILTER_MAX)) k2(.sys_clk(clk),.sys_rst_n(rst_n),
        .key_n(key2_n),.key_state(k2_state),.note_on(k2_down),.note_off(k2_up));
    reg [4:0] piano_next;
    reg [2:0] tom_next;
    reg [18:0] queue[0:7];
    reg [2:0] rd,wr;
    reg [3:0] count;
    wire chosen=k1_down ? !selected_timbre : selected_timbre;
    wire push=k2_down||k2_up;
    wire pop=event_valid&&event_ready;
    wire accepted_push=push&&(count<8||pop);
    assign event_valid=count!=0;
    assign {event_on,event_key,event_timbre,event_note,event_velocity}=queue[rd];
    always @(posedge clk) begin
        if(!rst_n)begin
            selected_timbre<=0;piano_next<=16;tom_next<=0;rd<=0;wr<=0;count<=0;overflow<=0;
        end else begin
            if(k1_down)selected_timbre<=!selected_timbre;
            if(accepted_push)begin
                queue[wr]<={k2_down,5'd31,chosen,chosen ? {2'd0,tom_next} : piano_next,7'd112};
                wr<=wr+1'b1;
                if(k2_down)begin
                    if(chosen)tom_next<=tom_next==5 ? 0 : tom_next+1'b1;
                    else piano_next<=piano_next==16 ? 0 : piano_next+1'b1;
                end
            end
            if(push&&!accepted_push)overflow<=1;
            if(pop)rd<=rd+1'b1;
            case({accepted_push,pop})2'b10:count<=count+1'b1;2'b01:count<=count-1'b1;default:count<=count;endcase
        end
    end
endmodule
