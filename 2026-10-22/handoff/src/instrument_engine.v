// Four parallel logical voice slots. Events are accepted using valid/ready.
// A 64-frame (1.33 ms) fade precedes stealing an occupied slot.
module instrument_engine #(
    parameter integer PIANO_ADSR_ENABLE=0,
    parameter integer TOM_ADSR_ENABLE=0
)(
    input wire clk,rst_n,sample_tick,
    input wire event_valid,output wire event_ready,
    input wire event_on,input wire [4:0] event_key,
    input wire event_timbre,input wire [4:0] event_note,
    input wire [6:0] event_velocity,input wire [15:0] pitch_ratio_q15,
    output reg signed [15:0] sample_out,output reg sample_valid,
    output wire [3:0] active_voices,
    output reg overrun
);
    reg [3:0] start,release_note;
    reg new_timbre;reg [4:0] new_note;reg [6:0] new_velocity;
    reg [4:0] owner[0:3];reg [31:0] age[0:3];reg [6:0] gain[0:3];
    wire [3:0] busy,held,valid,voice_overrun;
    wire [15:0] level[0:3];wire signed [15:0] audio[0:3];
    assign active_voices=busy;
    reg stealing;reg [1:0] steal_slot;reg [6:0] fade_left;
    reg [3:0] restore_gain;
    reg saved_timbre;reg [4:0] saved_note,saved_key;reg [6:0] saved_velocity;
    assign event_ready=!stealing;
    genvar v;
    generate for(v=0;v<4;v=v+1)begin:slots
        instrument_voice_slot #(.PIANO_ADSR_ENABLE(PIANO_ADSR_ENABLE),.TOM_ADSR_ENABLE(TOM_ADSR_ENABLE)) slot(.clk(clk),.rst_n(rst_n),.sample_tick(sample_tick),
            .start(start[v]),.release_note(release_note[v]),.new_timbre(new_timbre),
            .new_note(new_note),.new_velocity(new_velocity),.pitch_ratio_q15(pitch_ratio_q15),
            .output_gain(gain[v]),.busy(busy[v]),.held(held[v]),.level(level[v]),
            .sample_out(audio[v]),.sample_valid(valid[v]),.overrun(voice_overrun[v]));
    end endgenerate
    integer i,choice;
    reg found_free,found_released;
    reg [15:0] weakest;
    reg [31:0] oldest;
    always @*begin
        choice=0;found_free=0;found_released=0;weakest=65535;oldest=0;
        for(integer a=0;a<4;a=a+1)begin
            // start is included: another event may arrive before busy updates.
            if(!busy[a]&&!start[a]&&!found_free)begin choice=a;found_free=1;end
        end
        if(!found_free)begin
            for(integer b=0;b<4;b=b+1)begin
                if(!held[b]&&!start[b]&&(!found_released||level[b]<weakest))begin
                    choice=b;weakest=level[b];found_released=1;
                end
            end
            if(!found_released)begin
                for(integer c=0;c<4;c=c+1)begin
                    if(age[c]>=oldest)begin choice=c;oldest=age[c];end
                end
            end
        end
    end
    reg [3:0] ready_mask;
    reg frames_started,mix_pending;
    reg signed [15:0] buffer[0:3];
    wire signed [17:0] sum=$signed({{2{buffer[0][15]}},buffer[0]})+
        $signed({{2{buffer[1][15]}},buffer[1]})+$signed({{2{buffer[2][15]}},buffer[2]})+
        $signed({{2{buffer[3][15]}},buffer[3]});
    always @(posedge clk)begin
        if(!rst_n)begin
            start<=0;release_note<=0;new_timbre<=0;new_note<=0;new_velocity<=0;
            stealing<=0;steal_slot<=0;fade_left<=0;restore_gain<=0;saved_timbre<=0;saved_note<=0;saved_key<=0;saved_velocity<=0;
            ready_mask<=0;frames_started<=0;mix_pending<=0;sample_out<=0;sample_valid<=0;overrun<=0;
            for(i=0;i<4;i=i+1)begin owner[i]<=0;age[i]<=0;gain[i]<=64;buffer[i]<=0;end
        end else begin
            start<=0;release_note<=0;sample_valid<=0;mix_pending<=0;
            if(|voice_overrun)overrun<=1;
            if(sample_tick)begin
                for(i=0;i<4;i=i+1)if(restore_gain[i])begin gain[i]<=64;restore_gain[i]<=0;end
                if(frames_started&&ready_mask!=15)overrun<=1;
                ready_mask<=0;frames_started<=1;
                for(i=0;i<4;i=i+1)if(age[i]!=32'hffffffff)age[i]<=age[i]+1'b1;
                if(stealing)begin
                    if(fade_left!=0)begin fade_left<=fade_left-1'b1;gain[steal_slot]<=fade_left-1'b1;end
                    else begin
                        new_timbre<=saved_timbre;new_note<=saved_note;new_velocity<=saved_velocity;
                        owner[steal_slot]<=saved_key;age[steal_slot]<=0;start[steal_slot]<=1;
                        // Trigger reaches the core after this tick; keep the
                        // old frame muted and restore on the new note's tick.
                        restore_gain[steal_slot]<=1;stealing<=0;
                    end
                end
            end
            for(i=0;i<4;i=i+1)if(valid[i])begin buffer[i]<=audio[i];ready_mask[i]<=1;end
            if((|valid)&&((ready_mask|valid)==15))mix_pending<=1;
            if(mix_pending)begin sample_out<=sum>>>2;sample_valid<=1;end
            if(event_valid&&event_ready)begin
                if(!event_on)begin
                    for(i=0;i<4;i=i+1)if((busy[i]||start[i])&&owner[i]==event_key)release_note[i]<=1;
                end else if(found_free)begin
                    new_timbre<=event_timbre;new_note<=event_note;new_velocity<=event_velocity;
                    owner[choice]<=event_key;age[choice]<=0;gain[choice]<=64;start[choice]<=1;
                end else begin
                    stealing<=1;steal_slot<=choice;fade_left<=64;
                    saved_timbre<=event_timbre;saved_note<=event_note;saved_velocity<=event_velocity;saved_key<=event_key;
                end
            end
        end
    end
endmodule
