module piano_drums_rimshot_single_top #(
    parameter integer KEY_FILTER_MAX=250000,
    parameter integer POR_CYCLES=50000
)(
    input wire sys_clk,key2_n,key3_n,
    output wire HP_BCK,HP_WS,HP_DIN,PA_EN
);
    reg [19:0] por_count=0;
    always @(posedge sys_clk)if(por_count<POR_CYCLES)por_count<=por_count+1'b1;
    wire rst_n=por_count==POR_CYCLES;
    wire frame_tick,event_valid,event_ready,event_on,event_timbre,selected,queue_overflow;
    wire [4:0] event_key,event_note;wire [6:0] event_velocity;
    wire signed [15:0] audio;wire sample_valid,active,overrun;
    // The reusable controller's first key selects and second key triggers.
    // Physical board mapping: K2/AB13 selects, K3/Y12 triggers.
    rimshot_audition_controller #(.KEY_FILTER_MAX(KEY_FILTER_MAX)) controls(
        .clk(sys_clk),.rst_n(rst_n),.key1_n(key2_n),.key2_n(key3_n),
        .event_valid(event_valid),.event_ready(event_ready),.event_on(event_on),
        .event_key(event_key),.event_timbre(event_timbre),.event_note(event_note),
        .event_velocity(event_velocity),.selected_timbre(selected),.overflow(queue_overflow));
    instrument_rimshot_single_engine engine(.clk(sys_clk),.rst_n(rst_n),.sample_tick(frame_tick),
        .event_valid(event_valid),.event_ready(event_ready),.event_on(event_on),.event_timbre(event_timbre),
        .event_note(event_note),.event_velocity(event_velocity),.pitch_ratio_q15(16'd32768),
        .sample_out(audio),.sample_valid(sample_valid),.active(active),.overrun(overrun));
    pt8211_tx output_tx(.clk(sys_clk),.rst_n(rst_n),.sample_in(audio),
        .bck(HP_BCK),.ws(HP_WS),.din(HP_DIN),.frame_tick(frame_tick));
    reg [10:0] startup_frames=0;
    always @(posedge sys_clk)begin
        if(!rst_n)startup_frames<=0;
        else if(frame_tick&&startup_frames!=1024)startup_frames<=startup_frames+1'b1;
    end
    assign PA_EN=!rst_n||startup_frames!=1024;
endmodule
