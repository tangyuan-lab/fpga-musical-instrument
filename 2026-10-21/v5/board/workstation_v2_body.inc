    wire [7:0] usb_byte;wire usb_valid,usb_bad,frame_valid;
    wire [7:0] frame_type;wire [15:0] frame_seq,frame_length;wire [1055:0] frame_payload;
    wire response_valid,response_busy;wire [15:0] response_seq;wire [7:0] response_length;wire [767:0] response_payload;
    wire resource_frame_valid,resource_response_valid,resource_response_busy,emergency_stop,emergency_abort;
    wire [15:0] resource_response_seq;wire [7:0] resource_response_length;wire [767:0] resource_response_payload;
    wire host_valid,host_done;wire [7:0] host_op,host_result;wire [31:0] host_value,host_aux;
    wire [1:0] selected_song;wire [16:0] selected_size;wire [31:0] duration,position,song_ready_mask,directory_revision;
    wire [7:0] patch_ready_mask;wire selected_ready,paused,parser_error;wire [4:0] section;
    wire [15:0] file_address;wire [7:0] file_data;wire [6:0] section_address;wire [191:0] section_data;wire [5:0] section_count;
    wire table_write,parameter_write;wire [10:0] table_address;wire signed [15:0] table_data;
    wire [3:0] parameter_bank;wire [47:0] envelope_parameters,current_envelope;
    wire [3:0] live_patch,screen_patch;wire signed [13:0] bend;wire [7:0] vibrato_depth,vibrato_rate;wire signed [6:0] live_transpose;
    wire [6:0] delay_mix,reverb_mix,feedback;wire [11:0] delay_time;wire player_panic;
    wire loop_enabled;wire [31:0] loop_a,loop_b;
    wire player_event_valid,player_event_ready;wire [1:0] player_event_op,player_event_source;wire [15:0] player_event_id;
    wire [6:0] player_note,player_velocity;wire [3:0] player_timbre;
    wire [15:0] player_drums,guide_keys;wire [127:0] player_drum_velocities;
    wire [5:0] voices;wire [31:0] voice_mask;wire deadline_error;
    wire [175:0] runtime_data;wire [111:0] command_feedback;
    wire validation_start,validation_release,validation_done;wire [31:0] validation_duration;
    wire signed [15:0] synth_pcm,drum_pcm,effects_pcm;wire signed [16:0] mixed_wide=17'(synth_pcm)+17'(drum_pcm);
    wire signed [15:0] dry_pcm=mixed_wide>32767 ? 16'sd32767 : mixed_wide< -32768 ? -16'sd32768: mixed_wide[15:0];
    wire [7:0] screen_op,screen_value;wire screen_valid;
    wire app_valid;wire [7:0] app_op;wire [31:0] app_value,app_aux;
    wire [7:0] legacy_op,legacy_value;wire legacy_valid;
    wire map_valid,adsr_valid,adsr_done;wire [15:0] map_descriptor;wire [31:0] adsr_value,adsr_aux;wire [7:0] adsr_result,screen_result;
    wire [255:0] active_map;wire [2:0] edit_bank;wire [3:0] edit_key;wire [15:0] edit_descriptor;
    wire [6:0] piano_volume,drum_volume,midi_volume;wire midi_start,midi_stop,boot_pending,command_error;
    wire [15:0] physical_piano_keys,screen_piano_keys,chord_keys,manual_drums;wire [127:0] physical_notes,manual_velocities;
    wire [95:0] physical_timbres;wire [15:0] beat_drums;wire [63:0] beat_patterns;wire [15:0] beat_sounds;
    wire beat_running;wire [7:0] beat_bpm;wire [3:0] beat_step;
    wire player_done;wire [7:0] player_result;
    reg [4:0] scan_key;reg [31:0] applied;reg [7:0] applied_velocity[0:31];reg [6:0] applied_note[0:31];
    // 映射快照、移调、差异检测分周期执行，切断命令到音源使能的长组合路径。
    reg [1:0] scan_phase;
    reg sampled_down;reg [7:0] sampled_offset,sampled_velocity;reg [3:0] sampled_timbre;
    reg signed [6:0] sampled_transpose;reg [1:0] sampled_octave;
    reg signed [10:0] target_pitch;
    wire [6:0] target_note=target_pitch<0 ? 7'd0:target_pitch>127 ? 7'd127:target_pitch[6:0];
    reg realtime_valid;reg [1:0] realtime_op,realtime_source;reg [15:0] realtime_id;reg [6:0] realtime_note,realtime_velocity;reg [3:0] realtime_timbre;
    wire synth_ready;wire [31:0] input_keys={screen_piano_keys,physical_piano_keys};
    wire synth_panic=player_panic || mode_changed || map_changed || performance_stop || emergency_stop;
    wire [127:0] all_drum_velocities;
    genvar drum_index;generate for(drum_index=0;drum_index<16;drum_index=drum_index+1) begin:g_drum_velocity
        wire [7:0] physical_level=manual_drums[drum_index] ? manual_velocities[drum_index*8+:8]:8'd0;
        wire [7:0] song_level=player_drums[drum_index] ? player_drum_velocities[drum_index*8+:8]:8'd0;
        wire [7:0] level=physical_level>song_level ? physical_level:song_level;
        assign all_drum_velocities[drum_index*8+:8]=beat_drums[drum_index] && level<112 ? 8'd112:level;
    end endgenerate
    wire [15:0] all_drums=manual_drums|player_drums|beat_drums;
    wire [11:0] pressure_max_value;
    assign max_pressure={1'b0,pressure_max_value};
    pressure_max16 #(.KEY_COUNT(KEY_COUNT),.ADC_BITS(ADC_BITS)) pressure_statistics(
        .clk(sys_clk),.rst_n(rst_n),.values(pressure_values),.maximum(pressure_max_value));
    wire [223:0] status_data={7'd0,deadline_error,7'd0,loop_enabled,loop_a,chord_keys,4'd0,max_pressure[11:0],
        directory_revision,duration,position,{2'd0,voices},{3'd0,section},{4'd0,live_patch},{6'd0,selected_song},
        {4'd0,parser_error,midi_parser_busy,paused,midi_playing},{5'd0,app_mode}};
    assign hpd_en=1;assign mcp0_sclk=mcp_sclk_int;assign mcp1_sclk=mcp_sclk_int;
    assign mcp0_mosi=mcp_mosi_int;assign mcp1_mosi=mcp_mosi_int;
    assign hp_bck=live_hp_bck;assign hp_ws=live_hp_ws;assign hp_din=live_hp_din;assign pa_en=live_pa_en;
    assign led_n={~adc_fault,~calibrated,~midi_playing,~(|guide_keys),~live_audio_ready,~deadline_error};
    assign live_keys=chord_keys;assign live_active_key_count=active_key_count;
    assign midi_file_ready=selected_ready;assign midi_led_n=~{2'b0,voices};
    assign performance_stop=legacy_valid && legacy_op==2 && legacy_value==255;
    reset_sync reset_sync_inst(.clk(sys_clk),.arst_n(sys_rst_n),.rst_n(rst_n));
    button_filter mode_button(.clk(sys_clk),.rst_n(rst_n),.key_n(mode_key_n),.pressed(mode_pressed));
    button_filter timbre_button(.clk(sys_clk),.rst_n(rst_n),.key_n(timbre_key_n),.pressed(timbre_pressed));
    uart_rx usb_rx(.clk(sys_clk),.rst_n(rst_n),.rx(uart_rx_i),.data(usb_byte),.valid(usb_valid),.framing_error(usb_bad));
    uart_frame_protocol frames(.clk(sys_clk),.rst_n(rst_n),.rx_data(usb_byte),.rx_valid(usb_valid),
        .frame_valid(frame_valid),.bad_frame(),.frame_type(frame_type),.frame_seq(frame_seq),.frame_length(frame_length),.frame_payload(frame_payload));
    uart_frame_tx_v2 responses(.clk(sys_clk),.rst_n(rst_n),.response_valid(response_valid),.response_type(8'h81),
        .response_seq(response_seq),.response_length(response_length),.response_payload(response_payload),.tx(uart_tx_o),.busy(response_busy));
    wire [3:0] catalog_index;wire [255:0] catalog_name;wire catalog_ready;wire [31:0] catalog_duration;wire [5:0] catalog_sections;
    workstation_v2_emergency emergency(.clk(sys_clk),.rst_n(rst_n),.frame_valid(frame_valid),.frame_type(frame_type),.frame_seq(frame_seq),.frame_length(frame_length),.payload(frame_payload),
        .normal_frame_valid(resource_frame_valid),.panic(emergency_stop),.abort_upload(emergency_abort),
        .normal_response_valid(resource_response_valid),.normal_response_seq(resource_response_seq),.normal_response_length(resource_response_length),.normal_response_payload(resource_response_payload),.normal_response_busy(resource_response_busy),
        .response_valid(response_valid),.response_seq(response_seq),.response_length(response_length),.response_payload(response_payload),.response_busy(response_busy));
    workstation_v2_resources #(.ENABLE_EMERGENCY(1)) resources(.clk(sys_clk),.rst_n(rst_n),.frame_valid(resource_frame_valid),.frame_type(frame_type),.frame_seq(frame_seq),.frame_length(frame_length),.payload(frame_payload),
        .emergency_abort(emergency_abort),.response_valid(resource_response_valid),.response_seq(resource_response_seq),.response_length(resource_response_length),.response_payload(resource_response_payload),.response_busy(resource_response_busy),
        .control_valid(host_valid),.control_op(host_op),.control_value(host_value),.control_aux(host_aux),.control_done(host_done),.control_result(host_result),.status_data(status_data),
        .runtime_data(runtime_data),.command_feedback(command_feedback),.validation_start(validation_start),.validation_release(validation_release),
        .validation_done(validation_done),.validation_busy(midi_parser_busy),.validation_error(parser_error),.validation_duration(validation_duration),
        .selected_song(selected_song),.song_read_address(file_address),.song_read_data(file_data),.selected_size(selected_size),.selected_ready(selected_ready),.selected_duration(duration),
        .song_ready_mask(song_ready_mask),.patch_ready_mask(patch_ready_mask),.table_write(table_write),.table_address(table_address),.table_data(table_data),
        .parameter_write(parameter_write),.parameter_bank(parameter_bank),.envelope_parameters(envelope_parameters),.envelope_read_bank(live_patch),.envelope_read_data(current_envelope),
        .external_adsr_valid(adsr_valid),.external_adsr_value(adsr_value),.external_adsr_aux(adsr_aux),.external_adsr_done(adsr_done),.external_adsr_result(adsr_result),
        .section_read_address(section_address),.section_data(section_data),.selected_sections(section_count),
        .catalog_index(catalog_index),.catalog_name(catalog_name),.catalog_ready(catalog_ready),.catalog_duration(catalog_duration),.catalog_sections(catalog_sections),.directory_revision(directory_revision));
    screen_touch_keys_rx #(.KEY_COUNT(16),.POLYPHONIC(1),.PERFORMANCE_CONTROLS(1),.WORKSTATION_CONTROLS(1)) touch(
        .clk(sys_clk),.rst_n(rst_n),.screen_rx_i(screen_rx_i),.held_keys(screen_touch_keys),.octave_shift(live_octave_shift),
        .test_mode(),.rx_activity(screen_rx_activity),.frame_error(),.command_valid(screen_valid),.command_op(screen_op),.command_value(screen_value));
    workstation_v2_commands commands(.clk(sys_clk),.rst_n(rst_n),
        .emergency_stop(emergency_stop),
        .host_valid(host_valid),.host_op(host_op),.host_value(host_value),.host_aux(host_aux),.host_done(host_done),.host_result(host_result),
        .screen_valid(screen_valid),.screen_op(screen_op),.screen_value(screen_value),
        .safety_stop(performance_stop||mode_changed||(frame_valid && frame_type==8'h32)),.timbre_pressed(timbre_pressed),.live_patch(live_patch),
        .app_valid(app_valid),.app_op(app_op),.app_value(app_value),.app_aux(app_aux),.app_done(player_done),.app_result(player_result),
        .legacy_valid(legacy_valid),.legacy_op(legacy_op),.legacy_value(legacy_value),.legacy_error(command_error),
        .map_valid(map_valid),.map_descriptor(map_descriptor),.adsr_valid(adsr_valid),.adsr_value(adsr_value),.adsr_aux(adsr_aux),
        .adsr_done(adsr_done),.adsr_result(adsr_result),.screen_result(screen_result),.command_feedback(command_feedback));
    instrument_mode_control_v2 #(.MODE_SLOTS(4)) modes(.clk(sys_clk),.rst_n(rst_n),.cmd_valid(legacy_valid),.mode_pressed(mode_pressed),
        .direct_valid(map_valid),.direct_descriptor(map_descriptor),
        .cmd_op(legacy_op),.cmd_value(legacy_value),.mode(app_mode),.mode_changed(mode_changed),.map_changed(map_changed),
        .command_error(command_error),.active_map(active_map),.edit_bank(edit_bank),.edit_key(edit_key),.edit_descriptor(edit_descriptor),
        .piano_volume(piano_volume),.drum_volume(drum_volume),.midi_volume(midi_volume),.midi_start(midi_start),.midi_stop(midi_stop),.boot_pending(boot_pending));
    workstation_v2_router router(.clk(sys_clk),.rst_n(rst_n),.mode_changed(mode_changed),.map_changed(map_changed||performance_stop||player_panic),
        .mode(app_mode),.active_map(active_map),.physical_keys(key_down),.screen_keys(screen_touch_keys),.physical_velocity(velocity_values),
        .physical_piano_keys(physical_piano_keys),.physical_notes(physical_notes),.physical_timbres(physical_timbres),
        .screen_piano_keys(screen_piano_keys),.chord_keys(chord_keys),.drum_triggers(manual_drums),.drum_velocity(manual_velocities));
    workstation_v2_player player(.clk(sys_clk),.rst_n(rst_n),.emergency_stop(emergency_stop),.emergency_abort(emergency_abort),.command_valid(app_valid),.command_op(app_op),.command_value(app_value),.command_aux(app_aux),
        .validation_start(validation_start),.validation_release(validation_release),.validation_done(validation_done),.validation_duration(validation_duration),.runtime_data(runtime_data),
        .command_done(player_done),.command_result(player_result),.song_ready_mask(song_ready_mask),.patch_ready_mask(patch_ready_mask),
        .selected_song(selected_song),.selected_ready(selected_ready),.selected_size(selected_size),.duration(duration),
        .file_read_address(file_address),.file_read_data(file_data),.section_count(section_count),.section_address(section_address),.section_data(section_data),
        .playing(midi_playing),.paused(paused),.parser_busy(midi_parser_busy),.parser_error(parser_error),.tick(position),.section(section),
        .loop_enabled(loop_enabled),.loop_a(loop_a),.loop_b(loop_b),.live_timbre(live_patch),.screen_timbre(screen_patch),.live_transpose(live_transpose),
        .bend(bend),.vibrato_depth(vibrato_depth),.vibrato_rate(vibrato_rate),.delay_mix(delay_mix),.reverb_mix(reverb_mix),.feedback(feedback),.delay_time(delay_time),.panic(player_panic),
        .event_valid(player_event_valid),.event_ready(player_event_ready),.event_op(player_event_op),.event_source(player_event_source),.event_id(player_event_id),.event_note(player_note),.event_velocity(player_velocity),.event_timbre(player_timbre),
        .drum_triggers(player_drums),.drum_velocities(player_drum_velocities),.guide_keys(guide_keys));
    assign player_event_ready=synth_ready && !realtime_valid;
    always @(posedge sys_clk) begin
        if(!rst_n || synth_panic) begin scan_key<=0;scan_phase<=0;sampled_down<=0;sampled_offset<=0;sampled_velocity<=0;sampled_timbre<=0;sampled_transpose<=0;sampled_octave<=0;target_pitch<=0;applied<=0;realtime_valid<=0;realtime_op<=0;realtime_source<=0;realtime_id<=0;realtime_note<=0;realtime_velocity<=0;realtime_timbre<=0;end
        else if(realtime_valid) begin if(synth_ready) begin realtime_valid<=0;scan_key<=scan_key+1'b1;scan_phase<=0;end end
        else if(scan_phase==0) begin
            sampled_down<=input_keys[scan_key];
            sampled_offset<=scan_key<16 ? physical_notes[scan_key*8+:8]:{4'd0,scan_key[3:0]};
            sampled_velocity<=scan_key<16 ? velocity_values[scan_key*8+:8]:8'd200;
            sampled_timbre<=scan_key<16 ? (physical_timbres[scan_key*6+:6]<10 ? physical_timbres[scan_key*6+:4]:live_patch):screen_patch;
            sampled_transpose<=live_transpose;sampled_octave<=live_octave_shift;scan_phase<=1;
        end else if(scan_phase==1) begin
            // 范围 -76..390，11位有符号数足够，保留越界音高的饱和处理。
            target_pitch<=11'sd60+$signed({3'd0,sampled_offset})+
                (sampled_octave==1 ? 11'sd12:sampled_octave==2 ? -11'sd12:11'sd0)+sampled_transpose;
            scan_phase<=2;
        end else begin
            if(sampled_down!=applied[scan_key] || (sampled_down && (applied_note[scan_key]!=target_note || (scan_key<16 && applied_velocity[scan_key]!=sampled_velocity)))) begin
                realtime_valid<=1;realtime_source<=scan_key<16 ? 0:1;realtime_id<={12'd0,scan_key[3:0]};
                realtime_op<=!sampled_down ? 0 : applied[scan_key[4:0]] ? 3:1;
                realtime_note<=target_note;applied_note[scan_key]<=target_note;
                // 有效按压的8位力度1不能被右移量化成静音；7位音源输入至少保留1。
                realtime_velocity<=sampled_velocity[7:1]==0 ? 7'd1:sampled_velocity[7:1];
                realtime_timbre<=sampled_timbre;
                applied[scan_key]<=sampled_down;
                if(scan_key<16) applied_velocity[scan_key]<=sampled_velocity;
            end else begin scan_key<=scan_key+1'b1;scan_phase<=0;end
        end
    end
    synth32 engine(.clk(sys_clk),.rst_n(rst_n),.sample_tick(live_sample_tick),.panic(synth_panic),
        .command_valid(realtime_valid||player_event_valid),.command_ready(synth_ready),
        .command_op(realtime_valid ? realtime_op:player_event_op),.command_source(realtime_valid ? realtime_source:player_event_source),
        .command_id(realtime_valid ? realtime_id:player_event_id),.command_note(realtime_valid ? realtime_note:player_note),
        .command_velocity(realtime_valid ? realtime_velocity:player_velocity),.command_timbre(realtime_valid ? realtime_timbre:player_timbre),.custom_ready(patch_ready_mask),
        .bend(bend),.vibrato_depth(vibrato_depth),.vibrato_rate(vibrato_rate),.table_write(table_write),.table_address(table_address),.table_data(table_data),
        .parameter_write(parameter_write),.parameter_bank(parameter_bank),.attack_step(envelope_parameters[11:0]),.decay_step(envelope_parameters[23:12]),
        .sustain_level(envelope_parameters[35:24]),.release_step(envelope_parameters[47:36]),.pcm(synth_pcm),.voice_count(voices),.active_mask(voice_mask),.deadline_error(deadline_error));
    drum_sequencer beats(.clk(sys_clk),.rst_n(rst_n),.sample_tick(live_sample_tick),.stop_all(synth_panic),.enable(app_mode==1||app_mode==3),
        .cmd_valid(legacy_valid),.cmd_op(legacy_op),.cmd_value(legacy_value),.running(beat_running),.bpm(beat_bpm),.step_index(beat_step),.triggers(beat_drums),.patterns(beat_patterns),.track_sounds(beat_sounds));
    drum_synth drums(.clk(sys_clk),.rst_n(rst_n),.sample_tick(live_sample_tick),.clear(synth_panic),.triggers(all_drums),.velocities(all_drum_velocities),.sample_out(drum_pcm));
    audio_effects effects(.clk(sys_clk),.rst_n(rst_n),.sample_tick(live_sample_tick),.clear(synth_panic),.dry(dry_pcm),
        .delay_mix(delay_mix),.reverb_mix(reverb_mix),.feedback(feedback),.delay_samples(delay_time),.wet(effects_pcm));
    audio_startup startup(.clk(sys_clk),.rst_n(rst_n),.audio_ready(live_audio_ready),.pa_en(live_pa_en));
    i2s_tx audio_output(.clk(sys_clk),.rst_n(rst_n),.sample_left(effects_pcm),.sample_right(effects_pcm),.sample_tick(live_sample_tick),
        .hp_bck(live_hp_bck),.hp_ws(live_hp_ws),.hp_din(live_hp_din));
    workstation_v2_screen display(.clk(sys_clk),.rst_n(rst_n),.status_data(status_data),.directory_revision(directory_revision),.envelope_data(current_envelope),
        .runtime_data(runtime_data),.command_feedback(command_feedback),
        .catalog_index(catalog_index),.catalog_name(catalog_name),.catalog_ready(catalog_ready),.catalog_duration(catalog_duration),.catalog_sections(catalog_sections),.tx(screen_tx_o));
