    wire [2:0] app_mode;
    wire cmd_valid,mode_changed,map_changed,command_error;
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
