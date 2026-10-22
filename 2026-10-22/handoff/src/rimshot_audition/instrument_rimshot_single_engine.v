// One logical voice only. Retriggers replace the previous voice after a
// 64-output-sample fade. Full accepted C synthesis is retained.
module instrument_rimshot_single_engine(
    input wire clk,rst_n,sample_tick,
    input wire event_valid,output wire event_ready,
    input wire event_on,event_timbre,input wire [4:0] event_note,
    input wire [6:0] event_velocity,input wire [15:0] pitch_ratio_q15,
    output wire signed [15:0] sample_out,output wire sample_valid,
    output wire active,output reg overrun
);
    wire pp_request,pp_ready,pp_valid,ps_request,ps_ready,ps_valid;
    wire tp_request,tp_ready,tp_valid,ts_request,ts_ready,ts_valid;
    wire tn_request,tn_ready,tn_valid,cp_request,cp_ready,cp_valid;
    wire [10:0] pp_address;wire [127:0] pp_data;
    wire [9:0] ps_address;wire [15:0] ps_data;
    wire [7:0] tp_address;wire [255:0] tp_data;
    wire [11:0] ts_address;wire [15:0] ts_data;
    wire [3:0] tn_address;wire [127:0] tn_data;
    wire [7:0] cp_address;wire [287:0] cp_data;wire [2:0] cp_bank;
    rimshot_shared_parameter_port #(.ADDR_WIDTH(11),.DATA_WIDTH(128),.INIT_FILE("src/mem/piano_accepted_coefficients.mem")) pp(
        .clk(clk),.rst_n(rst_n),.request(pp_request),.ready(pp_ready),.address(pp_address),.response_valid(pp_valid),.response_data(pp_data));
    rimshot_shared_parameter_port #(.ADDR_WIDTH(10),.DATA_WIDTH(16),.INIT_FILE("src/mem/modal_sine_1024x16.mem")) ps(
        .clk(clk),.rst_n(rst_n),.request(ps_request),.ready(ps_ready),.address(ps_address),.response_valid(ps_valid),.response_data(ps_data));
    rimshot_shared_parameter_port #(.ADDR_WIDTH(8),.DATA_WIDTH(256),.INIT_FILE("src/refit_v2/tom_modal_coefficients.mem")) tp(
        .clk(clk),.rst_n(rst_n),.request(tp_request),.ready(tp_ready),.address(tp_address),.response_valid(tp_valid),.response_data(tp_data));
    rimshot_shared_parameter_port #(.ADDR_WIDTH(12),.DATA_WIDTH(16),.INIT_FILE("src/mem/tom_sine_4096x16.mem")) ts(
        .clk(clk),.rst_n(rst_n),.request(ts_request),.ready(ts_ready),.address(ts_address),.response_valid(ts_valid),.response_data(ts_data));
    rimshot_shared_parameter_port #(.ADDR_WIDTH(4),.DATA_WIDTH(128),.INIT_FILE("src/refit_v2/tom_noise_coefficients.mem")) tn(
        .clk(clk),.rst_n(rst_n),.request(tn_request),.ready(tn_ready),.address(tn_address),.response_valid(tn_valid),.response_data(tn_data));
    rimshot_parameter_port cp(.clk(clk),.rst_n(rst_n),.request(cp_request),.ready(cp_ready),
        .bank(cp_bank),.address(cp_address),.response_valid(cp_valid),.response_data(cp_data));

    reg start,release_note,new_timbre,fading,restore_gain;
    reg [4:0] new_note,saved_note;
    reg [6:0] new_velocity,saved_velocity,gain,fade_left;
    reg saved_timbre;
    wire held,slot_overrun;wire [15:0] level;
    assign event_ready=!fading;
    // Exactly one instance; no allocator or four-way synthesis generate loop.
    instrument_rimshot_slot slot(.cp_bank(cp_bank),.clk(clk),.rst_n(rst_n),.sample_tick(sample_tick),
        .pp_request(pp_request),.pp_ready(pp_ready),.pp_valid(pp_valid),.pp_address(pp_address),.pp_data(pp_data),
        .ps_request(ps_request),.ps_ready(ps_ready),.ps_valid(ps_valid),.ps_address(ps_address),.ps_data(ps_data),
        .tp_request(tp_request),.tp_ready(tp_ready),.tp_valid(tp_valid),.tp_address(tp_address),.tp_data(tp_data),
        .ts_request(ts_request),.ts_ready(ts_ready),.ts_valid(ts_valid),.ts_address(ts_address),.ts_data(ts_data),
        .tn_request(tn_request),.tn_ready(tn_ready),.tn_valid(tn_valid),.tn_address(tn_address),.tn_data(tn_data),
        .cp_request(cp_request),.cp_ready(cp_ready),.cp_valid(cp_valid),.cp_address(cp_address),.cp_data(cp_data),
        .start(start),.release_note(release_note),.new_timbre(new_timbre),.new_note(new_note),
        .new_velocity(new_velocity),.pitch_ratio_q15(pitch_ratio_q15),.output_gain(gain),
        .busy(active),.held(held),.level(level),.sample_out(sample_out),.sample_valid(sample_valid),.overrun(slot_overrun));
    reg frame_started,frame_ready;
    always @(posedge clk)begin
        if(!rst_n)begin
            start<=0;release_note<=0;new_timbre<=0;new_note<=16;new_velocity<=112;
            fading<=0;restore_gain<=0;gain<=64;fade_left<=0;
            saved_note<=0;saved_velocity<=0;saved_timbre<=0;
            overrun<=0;frame_started<=0;frame_ready<=0;
        end else begin
            start<=0;release_note<=0;
            if(slot_overrun)overrun<=1;
            if(sample_valid)frame_ready<=1;
            if(sample_tick)begin
                if(frame_started&&!frame_ready)overrun<=1;
                frame_started<=1;frame_ready<=0;
                if(restore_gain)begin gain<=64;restore_gain<=0;end
                if(fading)begin
                    if(fade_left!=0)begin fade_left<=fade_left-1'b1;gain<=fade_left-1'b1;end
                    else begin
                        new_note<=saved_note;new_velocity<=saved_velocity;new_timbre<=saved_timbre;
                        start<=1;restore_gain<=1;fading<=0;
                    end
                end
            end
            if(event_valid&&event_ready)begin
                if(!event_on)release_note<=1;
                else if(!active)begin
                    new_note<=event_note;new_timbre<=event_timbre;new_velocity<=event_velocity;gain<=64;start<=1;
                end else begin
                    saved_note<=event_note;saved_timbre<=event_timbre;saved_velocity<=event_velocity;
                    fading<=1;fade_left<=64;
                end
            end
        end
    end
endmodule
