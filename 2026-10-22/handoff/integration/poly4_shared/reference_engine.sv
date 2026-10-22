// Four parallel logical voice slots. Events are accepted using valid/ready.
// A 64-frame (1.33 ms) fade precedes stealing an occupied slot.
module instrument_reference4_engine #(
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
    assign event_ready=(&voice_reset)&&!stealing;
    wire [3:0] pp_request,pp_ready,pp_valid;
    wire [43:0] pp_address;wire [511:0] pp_data;
    wire [3:0] ps_request,ps_ready,ps_valid;
    wire [39:0] ps_address;wire [63:0] ps_data;
    wire [3:0] tp_request,tp_ready,tp_valid;
    wire [31:0] tp_address;wire [1023:0] tp_data;
    wire [3:0] ts_request,ts_ready,ts_valid;
    wire [47:0] ts_address;wire [63:0] ts_data;
    wire [3:0] tn_request,tn_ready,tn_valid;
    wire [15:0] tn_address;wire [511:0] tn_data;
    shared_rom_4 #(.ADDR_WIDTH(11),.DATA_WIDTH(128),.INIT_FILE("src/mem/piano_accepted_coefficients.mem")) pp_rom(
        .clk(clk),.rst_n(rst_n),.request(pp_request),.ready(pp_ready),
        .address(pp_address),.response_valid(pp_valid),.response_data(pp_data));
    shared_rom_4 #(.ADDR_WIDTH(10),.DATA_WIDTH(16),.INIT_FILE("src/mem/modal_sine_1024x16.mem")) ps_rom(
        .clk(clk),.rst_n(rst_n),.request(ps_request),.ready(ps_ready),
        .address(ps_address),.response_valid(ps_valid),.response_data(ps_data));
    shared_rom_4 #(.ADDR_WIDTH(8),.DATA_WIDTH(256),.INIT_FILE("src/refit_v2/tom_modal_coefficients.mem")) tp_rom(
        .clk(clk),.rst_n(rst_n),.request(tp_request),.ready(tp_ready),
        .address(tp_address),.response_valid(tp_valid),.response_data(tp_data));
    shared_rom_4 #(.ADDR_WIDTH(12),.DATA_WIDTH(16),.INIT_FILE("src/mem/tom_sine_4096x16.mem")) ts_rom(
        .clk(clk),.rst_n(rst_n),.request(ts_request),.ready(ts_ready),
        .address(ts_address),.response_valid(ts_valid),.response_data(ts_data));
    shared_rom_4 #(.ADDR_WIDTH(4),.DATA_WIDTH(128),.INIT_FILE("src/refit_v2/tom_noise_coefficients.mem")) tn_rom(
        .clk(clk),.rst_n(rst_n),.request(tn_request),.ready(tn_ready),
        .address(tn_address),.response_valid(tn_valid),.response_data(tn_data));
    wire [3:0] cp_request,cp_ready,cp_valid;
    wire [31:0] cp_address;wire [1151:0] cp_data;wire [11:0] cp_bank;
    reference_parameters cp_rom(
        .clk(clk),.rst_n(rst_n),.request(cp_request),.ready(cp_ready),
        .bank(cp_bank),.address(cp_address),.response_valid(cp_valid),.response_data(cp_data));
    reg [3:0] voice_reset=0 /* synthesis syn_dont_touch=1 */;
    always @(posedge clk)voice_reset<={4{rst_n}};
    genvar v;
    generate for(v=0;v<4;v=v+1)begin:slots
        instrument_rimshot_slot #(.PIANO_ADSR_ENABLE(PIANO_ADSR_ENABLE),.TOM_ADSR_ENABLE(TOM_ADSR_ENABLE)) slot(.clk(clk),.rst_n(rst_n),.sample_tick(sample_tick),
            .pp_request(pp_request[v]),.pp_ready(pp_ready[v]),.pp_valid(pp_valid[v]),.pp_address(pp_address[v*11+:11]),.pp_data(pp_data[v*128+:128]),
            .ps_request(ps_request[v]),.ps_ready(ps_ready[v]),.ps_valid(ps_valid[v]),.ps_address(ps_address[v*10+:10]),.ps_data(ps_data[v*16+:16]),
            .tp_request(tp_request[v]),.tp_ready(tp_ready[v]),.tp_valid(tp_valid[v]),.tp_address(tp_address[v*8+:8]),.tp_data(tp_data[v*256+:256]),
            .ts_request(ts_request[v]),.ts_ready(ts_ready[v]),.ts_valid(ts_valid[v]),.ts_address(ts_address[v*12+:12]),.ts_data(ts_data[v*16+:16]),
            .tn_request(tn_request[v]),.tn_ready(tn_ready[v]),.tn_valid(tn_valid[v]),.tn_address(tn_address[v*4+:4]),.tn_data(tn_data[v*128+:128]),

            .cp_bank(cp_bank[v*3+:3]),.cp_request(cp_request[v]),.cp_ready(cp_ready[v]),.cp_valid(cp_valid[v]),.cp_address(cp_address[v*8+:8]),.cp_data(cp_data[v*288+:288]),
            .start(start[v]),.release_note(release_note[v]),.new_timbre(new_timbre),
            .new_note(new_note),.new_velocity(new_velocity),.pitch_ratio_q15(pitch_ratio_q15),
            .output_gain(gain[v]),.busy(busy[v]),.held(held[v]),.level(level[v]),
            .sample_out(audio[v]),.sample_valid(valid[v]),.overrun(voice_overrun[v]));
    end endgenerate
    integer i,choice;
    reg found_free,found_released;
    wire [3:0] available=~busy&~start;
    wire [3:0] released=~held&~start;
    wire [1:0] weak01=!released[0]?1:!released[1]?0:level[0]<=level[1]?0:1;
    wire [1:0] weak23=!released[2]?3:!released[3]?2:level[2]<=level[3]?2:3;
    wire [1:0] weak_pair=!(|released[1:0])?weak23:!(|released[3:2])?weak01:
                         level[weak01]<=level[weak23]?weak01:weak23;
    wire [1:0] old01=age[0]>age[1]?0:1;
    wire [1:0] old23=age[2]>age[3]?2:3;
    wire [1:0] oldest_pair=age[old01]>age[old23]?old01:old23;
    always @*begin
        found_free=|available;found_released=|released;
        if(found_free)choice=available[0]?0:available[1]?1:available[2]?2:3;
        else if(found_released)choice=weak_pair;
        else choice=oldest_pair;
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
