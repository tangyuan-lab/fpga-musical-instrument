`timescale 1ns/1ps
`default_nettype none
// 工作站顶层由 scripts/prepare_workstation.py 组合硬件与应用，修改应用请编辑 workstation_body.inc。
module instrument_workstation_top #(
    parameter integer KEY_COUNT = 16,
    parameter integer AUDIO_I2S = 0,
    parameter integer STARTUP_CYCLES = 5_000_000,
    parameter [11:0] PRESS_ON         = 12'd16,
    parameter [11:0] PRESS_OFF        = 12'd8,
    parameter [11:0] PRESS_FULL       = 12'd2048,
    // 0表示按压后ADC上升；接3.3V的裸FSR须在CHx端有到GND的分压电阻。
    parameter [KEY_COUNT-1:0] ACTIVE_LOW_MASK = 16'h0000,
    // 50 MHz 时钟：434=115200 baud；5208=9600 baud。应与屏幕设置一致。
    parameter integer SCREEN_CLKS_PER_BIT = 434,
    parameter integer SCREEN_STARTUP_CYCLES = 50_000_000,
    parameter integer SCREEN_UPDATE_CYCLES = 5_000_000
) (
    input  wire       sys_clk,
    input  wire       sys_rst_n,
    input  wire       uart_rx_i,
    output wire       uart_tx_o,
    input  wire       mode_key_n,
    input  wire       timbre_key_n,
    output wire [5:0] led_n,
    output wire       hp_bck,
    output wire       hp_ws,
    output wire       hp_din,
    output wire       pa_en,
    input  wire       screen_rx_i,
    output wire       screen_tx_o,
    output wire       mcp0_sclk,
    output wire       mcp0_mosi,
    output wire       mcp1_sclk,
    output wire       mcp1_mosi,
    output wire       mcp0_cs_n,
    output wire       mcp1_cs_n,
    input  wire       mcp0_miso,
    input  wire       mcp1_miso,
    output wire [2:0] tmds_p,
    output wire [2:0] tmds_n,
    output wire       tmds_clk_p,
    output wire       tmds_clk_n,
    output wire       hpd_en
);
    wire [2:0] app_mode;
    wire mode_changed,map_changed,performance_stop;
    localparam integer ACTIVE_COUNT_WIDTH = $clog2(KEY_COUNT+1);
    localparam integer ADC_BITS = 12;
    localparam integer ADC_BUS_WIDTH = KEY_COUNT * ADC_BITS;
    localparam integer BAR_BITS = 9;
    localparam integer BAR_BUS_WIDTH = KEY_COUNT * BAR_BITS;
    localparam integer FLAG_BASE = BAR_BUS_WIDTH + KEY_COUNT + ACTIVE_COUNT_WIDTH;
    localparam integer DISPLAY_WIDTH = FLAG_BASE + 12;

    wire rst_n;
    wire mode_pressed;
    wire timbre_pressed;
    wire midi_mode=app_mode==3;
    reg live_timbre;

    wire [95:0] mcp0_samples;
    wire [95:0] mcp1_samples;
    wire [ADC_BUS_WIDTH-1:0] adc_samples;
    wire sample_frame_valid;
    wire adc_ready;
    wire adc_fault;
    wire mcp_sclk_int;
    wire mcp_mosi_int;
    wire calibrated;
    wire [ADC_BUS_WIDTH-1:0] baseline_values;
    wire [ADC_BUS_WIDTH-1:0] pressure_values;
    wire [KEY_COUNT*8-1:0] velocity_values;
    wire [KEY_COUNT-1:0] key_down;
    wire [KEY_COUNT-1:0] key_on_pulse;
    wire [KEY_COUNT-1:0] key_off_pulse;
    wire [ACTIVE_COUNT_WIDTH-1:0] active_key_count;
    wire [KEY_COUNT-1:0] screen_touch_keys;
    wire [1:0] live_octave_shift;
    wire live_test_mode;
    wire [KEY_COUNT-1:0] live_keys;
    wire [KEY_COUNT-1:0] live_key_on;
    wire [KEY_COUNT-1:0] live_key_off;
    wire [KEY_COUNT*8-1:0] live_velocity;
    wire [ACTIVE_COUNT_WIDTH-1:0] live_active_key_count;

    wire live_audio_ready;
    wire live_sample_tick;
    wire signed [15:0] live_sample;
    wire [3:0] live_voice_gate;
    wire [3:0] live_voice_assigned;
    wire [15:0] live_voice_keys;
    wire [51:0] live_voice_levels;
    wire [31:0] live_timbre_blends;
    wire [127:0] live_voice_phase_steps;
    wire live_hp_bck;
    wire live_hp_ws;
    wire live_hp_din;
    wire live_pa_en;
    wire live_synth_rst_n = rst_n && !mode_changed && !map_changed && !performance_stop && app_mode>=1 && app_mode<=3;

    wire [7:0] midi_led_n;
    wire midi_hp_bck;
    wire midi_hp_ws;
    wire midi_hp_din;
    wire midi_pa_en;
    wire midi_audio_ready = live_audio_ready;
    wire midi_file_ready;
    wire midi_parser_busy;
    wire midi_playing;
    wire [3:0] midi_voice_gate = {4{midi_playing}} & ~midi_led_n[3:0];
    wire [3:0] midi_active_voice_count = {3'd0, midi_voice_gate[0]} +
                                       {3'd0, midi_voice_gate[1]} +
                                       {3'd0, midi_voice_gate[2]} +
                                       {3'd0, midi_voice_gate[3]};
    wire screen_rx_activity;

    reg [12:0] max_pressure;
    reg [6:0] pressure_bar;
    reg [24:0] blink_counter;
    reg [BAR_BUS_WIDTH-1:0] bar_levels_reg;
    integer key_index;
    integer bar_index;

    wire live_system_ready = adc_ready && calibrated && live_audio_ready && !adc_fault;
    wire selected_audio_ready = midi_mode ? midi_audio_ready : live_audio_ready;
    wire [7:0] live_led_n = adc_fault ? ~(blink_counter[24] ? 8'hAA : 8'h55) :
                                 live_system_ready ? ~{1'b1, pressure_bar} :
                                 ~(blink_counter[24] ? 8'h80 : 8'h00);

    // HDMI 1024x600 视频域和状态快照。
    wire pixel_clk;
    wire serial_clk;
    wire pll_locked;
    wire video_rst_n;
    wire [DISPLAY_WIDTH-1:0] display_data;
    wire display_update;
    reg  [DISPLAY_WIDTH-1:0] frame_data;
    wire [10:0] pixel_x;
    wire [9:0] pixel_y;
    wire video_de;
    wire hsync_n;
    wire vsync_n;
    wire frame_start;
    wire [23:0] video_rgb;
    reg video_de_d, hsync_n_d, vsync_n_d;
    reg video_de_d2, hsync_n_d2, vsync_n_d2;
    reg video_de_d3, hsync_n_d3, vsync_n_d3;

    wire cmd_valid,command_error;
    wire [7:0] cmd_op,cmd_value;
    assign performance_stop=cmd_valid && cmd_op==8'h02 && cmd_value==8'hff;
    wire [255:0] active_map;
    wire [2:0] edit_bank;wire [3:0] edit_key;wire [15:0] edit_descriptor;
    wire [6:0] piano_volume,drum_volume,midi_volume;
    wire midi_start,midi_stop,midi_error;
    wire boot_pending;
    wire [15:0] physical_piano_keys,screen_piano_keys,chord_keys;
    wire [95:0] physical_timbres;
    wire [127:0] physical_notes,drum_velocities;
    wire [15:0] manual_drum_triggers,beat_triggers;
    wire [15:0] physical_on,physical_off,physical_held;
    wire [127:0] physical_levels;
    wire [4:0] physical_count;
    wire signed [15:0] screen_sample,drum_sample,midi_sample,mixed_sample;
    wire signed [16:0] piano_sum=17'(live_sample)+17'(screen_sample);
    wire signed [15:0] piano_sample=16'(piano_sum>>>1);
    wire beat_running;wire [7:0] beat_bpm;wire [3:0] beat_step;
    wire [63:0] beat_patterns;wire [15:0] beat_sounds;
    wire [15:0] drum_requests=manual_drum_triggers | beat_triggers |
        ((cmd_valid && cmd_op==8'h06 && cmd_value<16 && (app_mode==1 || app_mode==3)) ? (16'b1<<cmd_value[3:0]) : 16'b0);
    reg [127:0] drum_levels;
    reg [15:0] drum_display;
    integer d;
    always @(*) begin
        drum_levels=drum_velocities;
        for(d=0;d<16;d=d+1) if(beat_triggers[d] ||
            (cmd_valid && cmd_op==8'h06 && cmd_value==d)) drum_levels[d*8+:8]=160;
    end
    always @(posedge sys_clk or negedge rst_n) begin
        if(!rst_n || mode_changed || performance_stop) drum_display<=0;
        // 每个鼓触发翻转事件位，避免持续伴奏使“保持位图”永久高亮。
        else drum_display<=drum_display ^ drum_requests;
    end
    assign hpd_en=1;
    assign mcp0_sclk=mcp_sclk_int;assign mcp1_sclk=mcp_sclk_int;
    assign mcp0_mosi=mcp_mosi_int;assign mcp1_mosi=mcp_mosi_int;
    assign hp_bck=live_hp_bck;assign hp_ws=live_hp_ws;assign hp_din=live_hp_din;assign pa_en=live_pa_en;
    assign led_n={~adc_fault,~calibrated,~midi_playing,~beat_running,~live_audio_ready,~screen_rx_activity};
    reset_sync reset_sync_inst(.clk(sys_clk),.arst_n(sys_rst_n),.rst_n(rst_n));
    button_filter mode_button(.clk(sys_clk),.rst_n(rst_n),.key_n(mode_key_n),.pressed(mode_pressed));
    button_filter timbre_button(.clk(sys_clk),.rst_n(rst_n),.key_n(timbre_key_n),.pressed(timbre_pressed));
    always @(posedge sys_clk or negedge rst_n) if(!rst_n) live_timbre<=0;
        else if(cmd_valid && cmd_op==8'h08 && cmd_value<=1) live_timbre<=cmd_value[0];
        else if(timbre_pressed) live_timbre<=~live_timbre;
    screen_touch_keys_rx #(.KEY_COUNT(16),.CLKS_PER_BIT(SCREEN_CLKS_PER_BIT),.POLYPHONIC(1),.PERFORMANCE_CONTROLS(1),.WORKSTATION_CONTROLS(1)) screen_touch_rx(
        .clk(sys_clk),.rst_n(rst_n),.screen_rx_i(screen_rx_i),.held_keys(screen_touch_keys),
        .octave_shift(live_octave_shift),.test_mode(live_test_mode),.rx_activity(screen_rx_activity),
        .frame_error(),.command_valid(cmd_valid),.command_op(cmd_op),.command_value(cmd_value));
    instrument_mode_control modes(.clk(sys_clk),.rst_n(rst_n),.cmd_valid(cmd_valid),.mode_pressed(mode_pressed),
        .cmd_op(cmd_op),.cmd_value(cmd_value),.mode(app_mode),.mode_changed(mode_changed),.map_changed(map_changed),
        .command_error(command_error),.active_map(active_map),.edit_bank(edit_bank),.edit_key(edit_key),
        .edit_descriptor(edit_descriptor),.piano_volume(piano_volume),.drum_volume(drum_volume),.midi_volume(midi_volume),
        .midi_start(midi_start),.midi_stop(midi_stop),.boot_pending(boot_pending));
    instrument_key_router router(.clk(sys_clk),.rst_n(rst_n),.mode_changed(mode_changed),.map_changed(map_changed || performance_stop),
        .mode(app_mode),.active_map(active_map),.physical_keys(key_down),.screen_keys(screen_touch_keys),
        .physical_velocity(velocity_values),.physical_piano_keys(physical_piano_keys),.physical_notes(physical_notes),
        .physical_timbres(physical_timbres),.screen_piano_keys(screen_piano_keys),.chord_keys(chord_keys),
        .drum_triggers(manual_drum_triggers),.drum_velocity(drum_velocities));
    live_touch_key_merge #(.KEY_COUNT(16)) physical_inputs(.clk(sys_clk),.rst_n(rst_n),.live_enable(live_synth_rst_n),
        .physical_keys(physical_piano_keys),.physical_velocity(velocity_values),.touch_keys(16'b0),
        .held_keys(physical_held),.key_on_pulse(physical_on),.key_off_pulse(physical_off),
        .velocity_values(physical_levels),.active_key_count(physical_count));
    live_touch_key_merge #(.KEY_COUNT(16)) screen_inputs(.clk(sys_clk),.rst_n(rst_n),.live_enable(live_synth_rst_n),
        .physical_keys(live_test_mode && app_mode==2 ? 16'h0891 : 16'b0),.physical_velocity({16{8'd176}}),
        .touch_keys(screen_piano_keys),.held_keys(live_keys),.key_on_pulse(live_key_on),.key_off_pulse(live_key_off),
        .velocity_values(live_velocity),.active_key_count(live_active_key_count));
    poly_synth_4voice #(.KEY_COUNT(16),.MIX_SHIFT(0),.ADSR_ENABLE(1),.PIPELINE_INPUTS(1),.OCTAVE_CONTROL(1),.PER_KEY_SOUND(1)) physical_synth(
        .clk(sys_clk),.rst_n(live_synth_rst_n),.sample_tick(live_sample_tick),.timbre(1'b0),.octave_shift(live_octave_shift),
        .key_on_pulse(physical_on),.key_off_pulse(physical_off),.velocity_values(physical_levels),
        .key_notes(physical_notes),.key_timbres(physical_timbres),.sample_out(live_sample),
        .voice_gate(live_voice_gate),.voice_assigned(live_voice_assigned),.voice_keys(live_voice_keys),
        .voice_levels(live_voice_levels),.timbre_blends(live_timbre_blends),.voice_phase_steps(live_voice_phase_steps));
    poly_synth_4voice #(.KEY_COUNT(16),.MIX_SHIFT(0),.ADSR_ENABLE(1),.PIPELINE_INPUTS(1),.OCTAVE_CONTROL(1)) screen_synth(
        .clk(sys_clk),.rst_n(live_synth_rst_n),.sample_tick(live_sample_tick),.timbre(live_timbre),.octave_shift(live_octave_shift),
        .key_on_pulse(live_key_on),.key_off_pulse(live_key_off),.velocity_values(live_velocity),
        .key_notes(128'b0),.key_timbres(96'b0),.sample_out(screen_sample),.voice_gate(),.voice_assigned(),
        .voice_keys(),.voice_levels(),.timbre_blends(),.voice_phase_steps());
    drum_sequencer beats(.clk(sys_clk),.rst_n(rst_n),.sample_tick(live_sample_tick),.stop_all(mode_changed || performance_stop),
        .enable(app_mode==1 || app_mode==3),.cmd_valid(cmd_valid),.cmd_op(cmd_op),.cmd_value(cmd_value),
        .running(beat_running),.bpm(beat_bpm),.step_index(beat_step),.triggers(beat_triggers),
        .patterns(beat_patterns),.track_sounds(beat_sounds));
    drum_synth drums(.clk(sys_clk),.rst_n(rst_n),.sample_tick(live_sample_tick),
        .clear(mode_changed || performance_stop || app_mode==0 || app_mode==4),.triggers(drum_requests),.velocities(drum_levels),.sample_out(drum_sample));
    midi_player_engine midi_core(.sys_clk(sys_clk),.sys_rst_n(sys_rst_n),.uart_rx_i(uart_rx_i),.uart_tx_o(uart_tx_o),
        .led_n(midi_led_n),.sample_tick_i(live_sample_tick),.audio_ready_i(live_audio_ready),.play_enable_i(app_mode==3),
        .external_play(midi_start),.external_stop(midi_stop || performance_stop),.pcm_out(midi_sample),.file_ready_o(midi_file_ready),
        .playing_o(midi_playing),.parser_busy_o(midi_parser_busy),.parser_error_o(midi_error));
    pcm_source_mixer #(.SOURCES(3)) mixer(.clk(sys_clk),.rst_n(rst_n),.sample_tick(live_sample_tick),
        .samples({midi_sample,drum_sample,piano_sample}),.volumes({midi_volume,drum_volume,piano_volume}),
        .enables({app_mode==3,(app_mode>=1 && app_mode<=3),(app_mode>=1 && app_mode<=3)}),.sample_out(mixed_sample));
    audio_startup #(.STARTUP_CYCLES(STARTUP_CYCLES)) startup(.clk(sys_clk),.rst_n(rst_n),.audio_ready(live_audio_ready),.pa_en(live_pa_en));
    generate if(AUDIO_I2S) begin:g_audio_i2s
        i2s_tx tx(.clk(sys_clk),.rst_n(rst_n),.sample_left(mixed_sample),.sample_right(mixed_sample),.sample_tick(live_sample_tick),
            .hp_bck(live_hp_bck),.hp_ws(live_hp_ws),.hp_din(live_hp_din));
    end else begin:g_audio_pt
        pt8211_tx tx(.clk(sys_clk),.rst_n(rst_n),.sample_left(mixed_sample),.sample_right(mixed_sample),.sample_tick(live_sample_tick),
            .hp_bck(live_hp_bck),.hp_ws(live_hp_ws),.hp_din(live_hp_din));
    end endgenerate
    workstation_screen_tx #(.CLKS_PER_BIT(SCREEN_CLKS_PER_BIT),.STARTUP_CYCLES(SCREEN_STARTUP_CYCLES)) screen_link(
        .clk(sys_clk),.rst_n(rst_n),.mode(app_mode),.keys(chord_keys),.drums(drum_display),.step_index(beat_step),
        .bpm(beat_bpm),.patterns(beat_patterns),.track_sounds(beat_sounds),.edit_bank(edit_bank),.edit_key(edit_key),
        .descriptor(edit_descriptor),.volumes({midi_volume,drum_volume,piano_volume}),
        .flags({boot_pending,command_error,midi_error,live_audio_ready,midi_parser_busy,midi_file_ready,midi_playing,beat_running}),
        .pressure_values(pressure_values),.screen_tx_o(screen_tx_o));
    mcp3208_dual_scan #(.HALF_PERIOD(25)) adc_spi (
        .clk(sys_clk), .rst_n(rst_n),
        .mcp0_miso(mcp0_miso), .mcp1_miso(mcp1_miso),
        .mcp_sclk(mcp_sclk_int), .mcp_mosi(mcp_mosi_int),
        .mcp0_cs_n(mcp0_cs_n), .mcp1_cs_n(mcp1_cs_n),
        .samples0(mcp0_samples), .samples1(mcp1_samples),
        .frame_valid(sample_frame_valid), .ready(adc_ready), .fault(adc_fault)
    );

    genvar bus_index;
    generate
        for (bus_index = 0; bus_index < 8; bus_index = bus_index + 1) begin : g_adc0_bus
            assign adc_samples[bus_index*ADC_BITS +: ADC_BITS] =
                mcp0_samples[bus_index*ADC_BITS +: ADC_BITS];
        end
        // 键 8..15 对应第二片 CH0..CH7；原 13 键工程丢弃的 CH5..CH7 现在接入。
        for (bus_index = 0; bus_index < KEY_COUNT-8; bus_index = bus_index + 1) begin : g_adc1_bus
            assign adc_samples[(bus_index+8)*ADC_BITS +: ADC_BITS] =
                mcp1_samples[bus_index*ADC_BITS +: ADC_BITS];
        end
    endgenerate

    pressure_key_matrix #(
        .KEY_COUNT(KEY_COUNT), .ADC_BITS(ADC_BITS), .CALIBRATION_SAMPLES(64),
        .FILTER_SHIFT(2), .PRESS_ON(PRESS_ON), .PRESS_OFF(PRESS_OFF),
        .PRESS_FULL(PRESS_FULL), .ACTIVE_LOW_MASK(ACTIVE_LOW_MASK)
    ) key_matrix (
        .clk(sys_clk), .rst_n(rst_n), .adc_ready(adc_ready),
        .sample_frame_valid(sample_frame_valid), .adc_samples(adc_samples),
        .calibrated(calibrated), .baseline_values(baseline_values),
        .pressure_values(pressure_values), .velocity_values(velocity_values),
        .key_down(key_down), .key_on_pulse(key_on_pulse),
        .key_off_pulse(key_off_pulse), .active_key_count(active_key_count)
    );

    always @(*) begin
        max_pressure = 13'd0;
        for (key_index = 0; key_index < KEY_COUNT; key_index = key_index + 1)
            if (pressure_values[key_index*ADC_BITS +: ADC_BITS] > max_pressure[11:0])
                max_pressure = {1'b0, pressure_values[key_index*ADC_BITS +: ADC_BITS]};

        if      (max_pressure >= 13'd224) pressure_bar = 7'b111_1111;
        else if (max_pressure >= 13'd144) pressure_bar = 7'b011_1111;
        else if (max_pressure >= 13'd96)  pressure_bar = 7'b001_1111;
        else if (max_pressure >= 13'd64)  pressure_bar = 7'b000_1111;
        else if (max_pressure >= 13'd48)  pressure_bar = 7'b000_0111;
        else if (max_pressure >= 13'd32)  pressure_bar = 7'b000_0011;
        else if (max_pressure >= 13'd16)  pressure_bar = 7'b000_0001;
        else                              pressure_bar = 7'b000_0000;
    end

    always @(posedge sys_clk or negedge rst_n) begin
        if (!rst_n) begin
            bar_levels_reg <= {BAR_BUS_WIDTH{1'b0}};
            blink_counter  <= 25'd0;
        end else begin
            blink_counter <= blink_counter + 1'b1;
            for (bar_index = 0; bar_index < KEY_COUNT; bar_index = bar_index + 1) begin
                if (pressure_values[bar_index*ADC_BITS +: ADC_BITS] >= 12'd467)
                    bar_levels_reg[bar_index*BAR_BITS +: BAR_BITS] <= 9'd350;
                else
                    bar_levels_reg[bar_index*BAR_BITS +: BAR_BITS] <=
                        pressure_values[bar_index*ADC_BITS + 8 -: 8] +
                        {2'b0, pressure_values[bar_index*ADC_BITS + 8 -: 7]};
            end
        end
    end

    snapshot_cdc #(.WIDTH(DISPLAY_WIDTH)) display_bridge (
        .src_clk(sys_clk), .src_rst_n(rst_n),
        .src_data({midi_voice_gate, midi_playing, midi_parser_busy,
                   midi_file_ready, midi_mode, adc_fault, selected_audio_ready,
                   calibrated, adc_ready, live_active_key_count, live_keys, bar_levels_reg}),
        .dst_clk(pixel_clk), .dst_rst_n(video_rst_n),
        .dst_data(display_data), .dst_valid(display_update)
    );

    video_pll video_clocks (
        .clkin(sys_clk), .reset(!sys_rst_n),
        .pixel_clk(pixel_clk), .serial_clk(serial_clk), .locked(pll_locked)
    );
    reset_sync video_reset (
        .clk(pixel_clk), .arst_n(sys_rst_n && pll_locked), .rst_n(video_rst_n)
    );
    video_timing raster (
        .clk(pixel_clk), .rst_n(video_rst_n), .x(pixel_x), .y(pixel_y),
        .de(video_de), .hs_n(hsync_n), .vs_n(vsync_n), .frame_start(frame_start)
    );

    always @(posedge pixel_clk or negedge video_rst_n) begin
        if (!video_rst_n)
            frame_data <= {DISPLAY_WIDTH{1'b0}};
        else if (frame_start)
            frame_data <= display_data;
    end

    instrument_ui_1024x600 #(.KEY_COUNT(KEY_COUNT)) ui (
        .clk(pixel_clk), .x(pixel_x), .y(pixel_y),
        .bar_levels(frame_data[BAR_BUS_WIDTH-1:0]),
        .key_down(frame_data[BAR_BUS_WIDTH +: KEY_COUNT]),
        .active_key_count(frame_data[BAR_BUS_WIDTH+KEY_COUNT +: ACTIVE_COUNT_WIDTH]),
        .scan_ready(frame_data[FLAG_BASE]), .calibrated(frame_data[FLAG_BASE+1]),
        .audio_ready(frame_data[FLAG_BASE+2]), .fault(frame_data[FLAG_BASE+3]),
        .midi_mode(frame_data[FLAG_BASE+4]), .midi_file_ready(frame_data[FLAG_BASE+5]),
        .midi_parser_busy(frame_data[FLAG_BASE+6]), .midi_playing(frame_data[FLAG_BASE+7]),
        .midi_voice_gate(frame_data[FLAG_BASE+8 +: 4]), .rgb(video_rgb)
    );

    always @(posedge pixel_clk or negedge video_rst_n) begin
        if (!video_rst_n) begin
            video_de_d <= 1'b0;  hsync_n_d <= 1'b1;  vsync_n_d <= 1'b1;
            video_de_d2 <= 1'b0; hsync_n_d2 <= 1'b1; vsync_n_d2 <= 1'b1;
            video_de_d3 <= 1'b0; hsync_n_d3 <= 1'b1; vsync_n_d3 <= 1'b1;
        end else begin
            video_de_d <= video_de;    hsync_n_d <= hsync_n;    vsync_n_d <= vsync_n;
            video_de_d2 <= video_de_d; hsync_n_d2 <= hsync_n_d; vsync_n_d2 <= vsync_n_d;
            video_de_d3 <= video_de_d2; hsync_n_d3 <= hsync_n_d2; vsync_n_d3 <= vsync_n_d2;
        end
    end

    DVI_TX_Top transmitter (
        .I_rst_n(video_rst_n), .I_serial_clk(serial_clk), .I_rgb_clk(pixel_clk),
        .I_rgb_vs(vsync_n_d3), .I_rgb_hs(hsync_n_d3), .I_rgb_de(video_de_d3),
        .I_rgb_r(video_rgb[23:16]), .I_rgb_g(video_rgb[15:8]), .I_rgb_b(video_rgb[7:0]),
        .O_tmds_clk_p(tmds_clk_p), .O_tmds_clk_n(tmds_clk_n),
        .O_tmds_data_p(tmds_p), .O_tmds_data_n(tmds_n)
    );

endmodule
`default_nettype wire
