module instrument_rimshot_slot #(
    parameter integer PIANO_ADSR_ENABLE=0,
    parameter integer TOM_ADSR_ENABLE=0
)(
    output wire pp_request,input wire pp_ready,pp_valid,
    output wire [10:0] pp_address,input wire [127:0] pp_data,
    output wire ps_request,input wire ps_ready,ps_valid,
    output wire [9:0] ps_address,input wire [15:0] ps_data,
    output wire tp_request,input wire tp_ready,tp_valid,
    output wire [7:0] tp_address,input wire [255:0] tp_data,
    output wire ts_request,input wire ts_ready,ts_valid,
    output wire [11:0] ts_address,input wire [15:0] ts_data,
    output wire tn_request,input wire tn_ready,tn_valid,
    output wire [3:0] tn_address,input wire [127:0] tn_data,
    output wire cp_request,input wire cp_ready,cp_valid,
    output wire [7:0] cp_address,input wire [287:0] cp_data,output reg [2:0] cp_bank,
    input wire clk,rst_n,sample_tick,start,release_note,
    input wire new_timbre,input wire [4:0] new_note,
    input wire [6:0] new_velocity,input wire [15:0] pitch_ratio_q15,
    input wire [6:0] output_gain,
    output reg busy,output reg held,
    output reg [15:0] level,
    output reg signed [15:0] sample_out,output reg sample_valid,
    output wire overrun
);
    reg timbre,frame_timbre,frame_busy,uses_C,frame_C;
    reg key_gate;
    reg [10:0] quiet_frames;
    wire signed [15:0] piano_sample,tom_sample;
    wire piano_valid,tom_valid,tom_active;
    wire C_valid,C_overrun,old_overrun;
    wire signed [15:0] C_sample;
    assign overrun=C_overrun|old_overrun;
    wire chosen_valid=frame_timbre ? (frame_C ? C_valid : tom_valid) : piano_valid;
    wire signed [15:0] chosen_sample=frame_timbre ? (frame_C ? C_sample : tom_sample) : piano_sample;
    wire [15:0] magnitude=chosen_sample[15] ? -chosen_sample : chosen_sample;
    wire [15:0] drop=(level>>8)==0 ? 16'd1 : level>>8;
    wire [15:0] level_decay=level>drop ? level-drop : 0;
    wire signed [23:0] scaled=chosen_sample*$signed({1'b0,output_gain});
    piano_C_pipelined_voice #(.ADSR_ENABLE(PIANO_ADSR_ENABLE)) piano(
        .pp_request(pp_request),.pp_ready(pp_ready),.pp_valid(pp_valid),.pp_address(pp_address),.pp_data(pp_data),
        .ps_request(ps_request),.ps_ready(ps_ready),.ps_valid(ps_valid),.ps_address(ps_address),.ps_data(ps_data),
        .clk(clk),.rst_n(rst_n),.sample_tick(sample_tick),.note_on(start&&!new_timbre),
        .note_off(release_note&&!timbre),.note_active(held&&!timbre),
        .note_index(new_note),.velocity(new_velocity),.pitch_ratio_q15(pitch_ratio_q15),
        .sample_out(piano_sample),.sample_valid(piano_valid));
    tom_shared_voice #(.ADSR_ENABLE(TOM_ADSR_ENABLE)) tom(
        .tp_request(tp_request),.tp_ready(tp_ready),.tp_valid(tp_valid),.tp_address(tp_address),.tp_data(tp_data),
        .ts_request(ts_request),.ts_ready(ts_ready),.ts_valid(ts_valid),.ts_address(ts_address),.ts_data(ts_data),
        .tn_request(tn_request),.tn_ready(tn_ready),.tn_valid(tn_valid),.tn_address(tn_address),.tn_data(tn_data),
        .clk(clk),.rst_n(rst_n),.sample_tick(sample_tick),.note_on(start&&new_timbre&&(new_note==1||new_note==2)),
        .note_off(release_note&&timbre),.note_active(key_gate&&timbre),.note_index(new_note),.velocity(new_velocity),
        .pitch_ratio_q15(pitch_ratio_q15),.sample_out(tom_sample),.sample_valid(tom_valid),
        .active(tom_active),.overrun(old_overrun));
    tom_C_voice #(.ADSR_ENABLE(TOM_ADSR_ENABLE)) C_voice(.clk(clk),.rst_n(rst_n),.sample_tick(sample_tick),
        .note_on(start&&new_timbre&&(new_note==0||new_note==3||new_note==4||new_note==5||new_note==6||new_note==7)),.velocity(new_velocity),.pitch_ratio_q15(pitch_ratio_q15),
        .note_off(release_note&&timbre&&uses_C),.note_active(key_gate&&timbre&&uses_C),
        .cp_request(cp_request),.cp_ready(cp_ready),.cp_valid(cp_valid),.cp_address(cp_address),.cp_data(cp_data),
        .sample_out(C_sample),.sample_valid(C_valid),.overrun(C_overrun));
    always @(posedge clk)begin
        if(!rst_n)begin
            cp_bank<=0;busy<=0;held<=0;level<=0;sample_out<=0;sample_valid<=0;
            timbre<=0;frame_timbre<=0;uses_C<=0;frame_C<=0;frame_busy<=0;quiet_frames<=0;key_gate<=0;
        end else begin
            sample_valid<=0;
            if(sample_tick)begin frame_timbre<=start ? new_timbre : timbre;frame_busy<=busy||start;frame_C<=start ? (new_note==0||new_note==3||new_note==4||new_note==5||new_note==6||new_note==7) : uses_C;end
            if(chosen_valid)begin
                sample_valid<=1;sample_out<=frame_busy ? scaled>>>6 : 0;
                level<=magnitude>level_decay ? magnitude : level_decay;
                if(busy&&!held&&magnitude<=1)begin
                    if(quiet_frames==1023)begin busy<=0;quiet_frames<=0;end
                    else quiet_frames<=quiet_frames+1'b1;
                end else quiet_frames<=0;
            end
            if(release_note)begin held<=0;key_gate<=0;end
            if(start&&new_timbre&&(new_note==0||new_note==3||new_note==4||new_note==5||new_note==6||new_note==7))cp_bank<=new_note==7 ? 3'd5 : new_note==6 ? 3'd4 : new_note==5 ? 3'd3 : new_note==4 ? 3'd2 : new_note==3 ? 3'd1 : 3'd0;
            if(start)begin uses_C<=(new_note==0||new_note==3||new_note==4||new_note==5||new_note==6||new_note==7);timbre<=new_timbre;held<=!new_timbre;key_gate<=1;busy<=1;quiet_frames<=0;level<=65535;end
        end
    end
endmodule
