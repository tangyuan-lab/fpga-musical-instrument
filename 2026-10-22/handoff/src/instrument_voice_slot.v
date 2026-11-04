module instrument_voice_slot #(
    parameter integer PIANO_ADSR_ENABLE=0,
    parameter integer TOM_ADSR_ENABLE=0
)(
    input wire clk,rst_n,sample_tick,start,release_note,
    input wire new_timbre,input wire [4:0] new_note,
    input wire [6:0] new_velocity,input wire [15:0] pitch_ratio_q15,
    input wire [6:0] output_gain,
    output reg busy,output reg held,
    output reg [15:0] level,
    output reg signed [15:0] sample_out,output reg sample_valid,
    output wire overrun
);
    reg timbre,frame_timbre,frame_busy;
    reg key_gate;
    reg [10:0] quiet_frames;
    wire signed [15:0] piano_sample,tom_sample;
    wire piano_valid,tom_valid,tom_active;
    wire chosen_valid=frame_timbre ? tom_valid : piano_valid;
    wire signed [15:0] chosen_sample=frame_timbre ? tom_sample : piano_sample;
    wire [15:0] magnitude=chosen_sample[15] ? -chosen_sample : chosen_sample;
    wire [15:0] drop=(level>>8)==0 ? 16'd1 : level>>8;
    wire [15:0] level_decay=level>drop ? level-drop : 0;
    wire signed [23:0] scaled=chosen_sample*$signed({1'b0,output_gain});
    piano_accepted_voice #(.ADSR_ENABLE(PIANO_ADSR_ENABLE)) piano(
        .clk(clk),.rst_n(rst_n),.sample_tick(sample_tick),.note_on(start&&!new_timbre),
        .note_off(release_note&&!timbre),.note_active(held&&!timbre),
        .note_index(new_note),.velocity(new_velocity),.pitch_ratio_q15(pitch_ratio_q15),
        .sample_out(piano_sample),.sample_valid(piano_valid));
    tom_voice #(.ADSR_ENABLE(TOM_ADSR_ENABLE)) tom(
        .clk(clk),.rst_n(rst_n),.sample_tick(sample_tick),.note_on(start&&new_timbre),
        .note_off(release_note&&timbre),.note_active(key_gate&&timbre),.note_index(new_note),.velocity(new_velocity),
        .pitch_ratio_q15(pitch_ratio_q15),.sample_out(tom_sample),.sample_valid(tom_valid),
        .active(tom_active),.overrun(overrun));
    always @(posedge clk)begin
        if(!rst_n)begin
            busy<=0;held<=0;level<=0;sample_out<=0;sample_valid<=0;
            timbre<=0;frame_timbre<=0;frame_busy<=0;quiet_frames<=0;key_gate<=0;
        end else begin
            sample_valid<=0;
            if(sample_tick)begin frame_timbre<=start ? new_timbre : timbre;frame_busy<=busy||start;end
            if(chosen_valid)begin
                sample_valid<=1;sample_out<=frame_busy ? scaled>>>6 : 0;
                level<=magnitude>level_decay ? magnitude : level_decay;
                if(busy&&!held&&magnitude<=1)begin
                    if(quiet_frames==1023)begin busy<=0;quiet_frames<=0;end
                    else quiet_frames<=quiet_frames+1'b1;
                end else quiet_frames<=0;
            end
            if(release_note)begin held<=0;key_gate<=0;end
            if(start)begin timbre<=new_timbre;held<=!new_timbre;key_gate<=1;busy<=1;quiet_frames<=0;level<=65535;end
        end
    end
endmodule
