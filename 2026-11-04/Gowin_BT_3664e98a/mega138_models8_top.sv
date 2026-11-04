`timescale 1ns/1ps
`include "rtl/workstation_build_identity.vh"

`default_nettype none

// r7整机顶层：50 MHz控制与合成，48 kHz音频；汇接压力、播放器、效果、DDR及串口屏。

module mega138_models8_top #(

    parameter integer KEY_COUNT = 16,

    parameter [1:0] ADC_PRESENT_MASK = 2'b11,

    parameter [15:0] KEY_ENABLE_MASK = 16'hffff,

    parameter [31:0] BUILD_ID = `WORKSTATION_BUILD_ID,

    parameter [6:0] MIN_LIVE_VELOCITY = 7'd8,

    parameter integer ONBOARD_DAC = 1,

    parameter [1:0] HEADPHONE_BOOST = 2'd2,

    parameter integer SCREEN_V2 = 0,

    parameter integer USB_CLKS_PER_BIT = 434,

    parameter integer BT_CLKS_PER_BIT = 5208,

    parameter integer CALIBRATION_SAMPLES = 64,

    parameter integer STARTUP_CYCLES = 5_000_000,

    parameter [11:0] PRESS_ON         = 12'd16,

    parameter [11:0] PRESS_OFF        = 12'd8,

    // 力度在整个12位基线差值范围内变化，不在半量程2048提前封顶。

    parameter [11:0] PRESS_FULL       = 12'd4095,

    // 0表示按压后ADC上升；接3.3V的裸FSR须在CHx端有到GND的分压电阻。

    parameter [KEY_COUNT-1:0] ACTIVE_LOW_MASK = 16'h0000,

    // 屏幕与USB均为115200/8N1；增量扫描减少图形流量，收发共用434分频。

    parameter integer SCREEN_CLKS_PER_BIT = 434,

    parameter integer SCREEN_STARTUP_CYCLES = 50_000_000,

    parameter integer SCREEN_UPDATE_CYCLES = 5_000_000

) (

    input  wire       sys_clk,

    input  wire       sys_rst_n,

    input  wire       uart_rx_i,

    output wire       uart_tx_o,

    input wire bt_rx_i,
    output wire bt_tx_o,

    input  wire       mode_key_n,

    input  wire       timbre_key_n,

    output wire [7:0] led_n,

    output wire       hp_bck,

    output wire       hp_ws,

    output wire       hp_din,

    output wire       pa_en,

    input  wire       screen_rx_i,

    output wire       screen_tx_o,

    output wire       mcp0_sclk,

    output wire       mcp1_sclk,

    output wire       mcp0_mosi,

    output wire       mcp1_mosi,

    output wire       mcp0_cs_n,

    output wire       mcp1_cs_n,

    input  wire       mcp0_miso,

    input  wire       mcp1_miso,

    output wire       hpd_en,

    output wire [14:0] ddr_addr,output wire [2:0] ddr_bank,

    output wire ddr_cs,ddr_ras,ddr_cas,ddr_we,ddr_ck,ddr_ck_n,ddr_cke,ddr_odt,ddr_reset_n,

    output wire [3:0] ddr_dm,inout wire [31:0] ddr_dq,inout wire [3:0] ddr_dqs,ddr_dqs_n

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

    wire rst_n,reference_rst_n;
    // CLKOUT1已配置为800MHz/16=50MHz，使用PLL专用输出驱动应用时钟树。
    // 参考域仅启动PLL/DDR；其复位不能依赖PLL锁定，否则会构成启动自锁。
    (* syn_keep=1 *) wire system_clk;
    reset_sync reference_reset_sync(.clk(sys_clk),.arst_n(sys_rst_n),.rst_n(reference_rst_n));

    wire ddr_user_clk,ddr_user_rst_n,ddr_calibrated,storage_ready,ddr_reinit,ddr_pll_locked;

    wire engine_sample_valid;wire [399:0] hardware_status;wire [63:0] chord_status;

    wire ddr_req_valid,ddr_req_ready,ddr_req_write,ddr_resp_valid,ddr_resp_ready,ddr_resp_error;

    wire [31:0] ddr_req_address,ddr_req_mask;wire [255:0] ddr_req_data,ddr_resp_data;

    wire [2:0] ddr_cmd;wire [28:0] ddr_ip_address;

    wire ddr_cmd_en,ddr_cmd_ready,ddr_wr_en,ddr_wr_end,ddr_wr_ready,ddr_rd_valid,ddr_rd_end;

    wire [255:0] ddr_wr_data,ddr_rd_data;wire [31:0] ddr_wr_mask;

    workstation_ddr_phy ddr(.fabric_clk50(system_clk),.clk50(sys_clk),.rst_n(reference_rst_n),.reinit_request(ddr_reinit),

        .user_clk(ddr_user_clk),.user_rst_n(ddr_user_rst_n),.calibrated(ddr_calibrated),.pll_locked(ddr_pll_locked),

        .cmd(ddr_cmd),.cmd_en(ddr_cmd_en),.cmd_ready(ddr_cmd_ready),.addr(ddr_ip_address),

        .wr_data(ddr_wr_data),.wr_data_mask(ddr_wr_mask),.wr_data_en(ddr_wr_en),.wr_data_end(ddr_wr_end),.wr_data_rdy(ddr_wr_ready),

        .rd_data(ddr_rd_data),.rd_data_valid(ddr_rd_valid),.rd_data_end(ddr_rd_end),

        .ddr_addr(ddr_addr),.ddr_bank(ddr_bank),.ddr_cs(ddr_cs),.ddr_ras(ddr_ras),.ddr_cas(ddr_cas),.ddr_we(ddr_we),

        .ddr_ck(ddr_ck),.ddr_ck_n(ddr_ck_n),.ddr_cke(ddr_cke),.ddr_odt(ddr_odt),.ddr_reset_n(ddr_reset_n),

        .ddr_dm(ddr_dm),.ddr_dq(ddr_dq),.ddr_dqs(ddr_dqs),.ddr_dqs_n(ddr_dqs_n));

    workstation_ddr_bridge storage_bridge(.app_clk(system_clk),.app_rst_n(rst_n),.mem_clk(ddr_user_clk),.mem_rst_n(ddr_user_rst_n),

        .calibrated(ddr_calibrated),.ready(storage_ready),.reinit_request(ddr_reinit),

        .req_valid(ddr_req_valid),.req_ready(ddr_req_ready),.req_write(ddr_req_write),.req_address(ddr_req_address),

        .req_data(ddr_req_data),.req_mask(ddr_req_mask),.resp_valid(ddr_resp_valid),.resp_ready(ddr_resp_ready),.resp_error(ddr_resp_error),.resp_data(ddr_resp_data),

        .cmd(ddr_cmd),.cmd_en(ddr_cmd_en),.cmd_ready(ddr_cmd_ready),.addr(ddr_ip_address),

        .wr_data(ddr_wr_data),.wr_data_mask(ddr_wr_mask),.wr_data_en(ddr_wr_en),.wr_data_end(ddr_wr_end),.wr_data_rdy(ddr_wr_ready),

        .rd_data(ddr_rd_data),.rd_data_valid(ddr_rd_valid),.rd_data_end(ddr_rd_end));

    (* syn_maxfan=64 *) reg synth_panic;

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

    wire pressure_frame_overrun;

    wire pressure_frame_busy;

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

    wire live_system_ready = adc_ready && calibrated && live_audio_ready && !adc_fault && !pressure_frame_overrun;

    wire selected_audio_ready = midi_mode ? midi_audio_ready : live_audio_ready;

    wire [7:0] live_led_n = adc_fault ? ~(blink_counter[24] ? 8'hAA : 8'h55) :

                                 live_system_ready ? ~{1'b1, pressure_bar} :

                                 ~(blink_counter[24] ? 8'h80 : 8'h00);

    wire [7:0] usb_byte;wire usb_valid,usb_bad,frame_valid;

    wire [7:0] frame_type;wire [15:0] frame_seq,frame_length;wire [1055:0] frame_payload;

    wire response_valid,response_busy;wire [15:0] response_seq;wire [7:0] response_length;wire [767:0] response_payload;

    wire resource_frame_valid,resource_response_valid,resource_response_busy,emergency_stop,emergency_abort;

    wire [15:0] resource_response_seq;wire [7:0] resource_response_length;wire [767:0] resource_response_payload;

    wire host_valid,host_done;wire [7:0] host_op,host_result;wire [31:0] host_value,host_aux;
    wire raw_resource_frame_valid,usb_emergency_stop,bt_emergency,bt_lease,bt_claim_idle;
    wire bt_command_valid,bt_command_ready,bt_command_done,bt_command_cancel;
    wire [7:0] bt_command_op,bt_command_result;
    wire [31:0] bt_command_value,bt_command_aux,bt_accepted_commands;
    wire merged_host_valid,merged_host_done,merged_host_cancel,remote_command_idle,resource_idle;
    wire [7:0] merged_host_op,merged_host_result;
    wire [31:0] merged_host_value,merged_host_aux;
    wire bt_usb_reject_valid,bt_usb_reject_selected;
    wire [15:0] bt_usb_reject_seq;wire [7:0] bt_usb_reject_type;
    wire [255:0] bt_status;
    assign emergency_stop=usb_emergency_stop || bt_emergency;


    wire [1:0] selected_song;wire [16:0] selected_size;wire [31:0] duration,position,song_ready_mask,directory_revision;

    wire [7:0] patch_ready_mask;wire selected_ready,paused,parser_error;wire [4:0] section;

    wire [15:0] file_address;wire [7:0] file_data;wire [6:0] section_address;wire [191:0] section_data;wire [5:0] section_count;

    wire table_write,parameter_write;wire [10:0] table_address;wire signed [15:0] table_data;

    wire [4:0] parameter_bank;wire [47:0] envelope_parameters,current_envelope;

    wire signed [13:0] bend;wire [7:0] vibrato_depth,vibrato_rate;wire [7:0] chorus_mix;

    wire signed [13:0] bend_unused;wire [7:0] vdepth_unused,vrate_unused;

    wire signed [6:0] transpose_unused;wire [6:0] delay_mix_unused,reverb_mix_unused,feedback_unused;wire [11:0] delay_time_unused;

    wire signed [6:0] live_transpose;wire [7:0] delay_mix,reverb_mix,feedback;wire [14:0] delay_time;wire [2:0] fx_preview;

    wire [7:0] chorus_depth,chorus_rate;

    wire [11:0] env_a,env_d,env_s,env_r;wire env_write_pulse;
    wire [95:0] damping_settings;
    wire [1:0] velocity_tone_setting;
    wire [10:0] pressure_touch_settings;
    reg [10:0] sampled_touch_settings;
    reg sampled_physical;
    wire [6:0] touch_velocity;

    wire player_panic;

    wire loop_enabled;wire [31:0] loop_a,loop_b;

    wire player_event_valid,player_event_ready;wire [1:0] player_event_op,player_event_source;wire [31:0] player_event_id;

    wire [3:0] player_track;wire [255:0] player_track_gains;

    wire [6:0] player_note,player_velocity;wire [4:0] player_timbre;

    wire [63:0] player_channel_map;wire [127:0] player_track_timbres,player_track_volumes;wire [15:0] player_track_mutes,player_track_solos;

    wire [15:0] player_drums,guide_keys;wire [127:0] player_drum_velocities;

    wire [5:0] voices;wire [31:0] voice_mask;wire deadline_error;wire engine_deadline_error;

    assign deadline_error=engine_deadline_error|pressure_frame_overrun;

    wire [175:0] runtime_data;wire [111:0] command_feedback;

    wire validation_start,validation_release,validation_done;wire [31:0] validation_duration;

    wire signed [15:0] chorus_pcm,output_pcm;
    reg signed [15:0] output_frame_pcm;

    wire master_clipped;wire [1:0] master_boost;
    wire [7:0] live_fx_target,song_fx_target,live_fx_gain,song_fx_gain;
    wire limiter_enabled;wire [1:0] limiter_release;wire [15:0] limiter_gain;
    wire gain_stats_clear,master_valid,master_limited,send_valid,send_clipped,effects_valid,effects_clipped,chorus_valid,chorus_clipped;
    wire [18:0] master_peak_in,master_peak_out;wire [223:0] gain_stats;
    wire signed [22:0] source_raw,source_live,source_song;
    wire signed [15:0] effects_input,effects_send_pcm;
    wire signed [15:0] delay_component,reverb_component,chorus_component;

    wire signed [15:0] synth_pcm,effects_pcm;

    wire signed [15:0] dry_pcm=synth_pcm; // 所有琴鼓共用32槽混音，不再并行叠加旧鼓。

    wire [7:0] screen_op,screen_value;wire screen_valid;

    wire diagnostic_control_valid;wire [7:0] diagnostic_op,diagnostic_value;

    wire [6:0] piano_volume,drum_volume,midi_volume;wire midi_start,midi_stop,boot_pending,command_error;

    wire [7:0] cmd_op=screen_valid ? screen_op:diagnostic_op;

    wire [7:0] cmd_value=screen_valid ? screen_value:diagnostic_value;

    wire cmd_valid=screen_valid||diagnostic_control_valid;

    wire [4:0] player_live_patch,player_screen_patch;

    reg [4:0] live_patch,last_player_patch;wire [4:0] screen_patch=player_screen_patch;

    wire select_builtin=cmd_valid&&cmd_op==8'h0c;

    wire builtin_changed=timbre_pressed||(select_builtin&&(cmd_value==10||cmd_value==19||cmd_value==20)&&live_patch!=cmd_value[4:0]);

    reg route_parameter_error;

    always @(posedge system_clk)begin

        if(!rst_n)begin live_patch<=5'd10;last_player_patch<=5'd10;end

        else if(timbre_pressed)live_patch<=live_patch==10 ? 5'd19:live_patch==19 ? 5'd20:5'd10;

        else if(select_builtin&&(cmd_value==10||cmd_value==19||cmd_value==20))live_patch<=cmd_value[4:0];

        else if(player_live_patch!=last_player_patch)begin live_patch<=player_live_patch;last_player_patch<=player_live_patch;end

    end

    wire performance_parameter=(cmd_op>=8'h40 && cmd_op<=8'h44)||(cmd_op>=8'h46 && cmd_op<=8'h49)||(cmd_op>=8'h50 && cmd_op<=8'h56);

    wire parameter_error,synth_clipped,audio_parameter_error,engine_parameter_error;

    wire engine_command_done;wire [2:0] engine_command_result;

    reg realtime_valid;reg [1:0] realtime_op,realtime_source;reg [31:0] realtime_id;reg [6:0] realtime_note,realtime_velocity;reg [4:0] realtime_timbre;

    wire test_active,test_event_valid;

    wire synth_ready;

    reg engine_command_error;reg [1:0] accepted_engine_op;

    assign parameter_error=audio_parameter_error|engine_parameter_error|route_parameter_error|engine_command_error;

    always @(posedge system_clk)begin

        if(!rst_n||synth_panic)begin engine_command_error<=0;accepted_engine_op<=0;end

        else begin

            if(synth_ready&&(test_active ? test_event_valid:(realtime_valid||player_event_valid)))

                accepted_engine_op<=test_active ? 2'd1:realtime_valid ? realtime_op:player_event_op;

            // 被抢占的旧松键/持续更新返回未命中，是所有权保护，不是参数错误。

            if(engine_command_done&&engine_command_result!=0&&!(engine_command_result==1&&accepted_engine_op!=1))engine_command_error<=1;

        end

    end

    wire [15:0] enabled_keys;wire mask_changed,tone_active,tone_changed;

    wire [15:0] effective_keys=key_down & enabled_keys;

    wire unused_response_valid;wire [15:0] unused_response_seq;wire [7:0] unused_response_length;wire [767:0] unused_response_payload;

    wire diagnostic_response_valid;wire [15:0] diagnostic_response_seq;wire [7:0] diagnostic_response_length;wire [767:0] diagnostic_response_payload;

    wire diagnostic_frame=frame_type==8'h01||frame_type>=8'he0;

    // 紧急仲裁器延后向UART发出valid，诊断valid的一拍脉冲不能直接充当数据选择。
    // 记住最后产生ACK的模块，直到下一份ACK到达；发送期间两份缓冲均由busy保护。
    reg diagnostic_response_owner;
    always @(posedge system_clk)begin
        if(!rst_n)diagnostic_response_owner<=1'b0;
        else if(diagnostic_response_valid)diagnostic_response_owner<=1'b1;
        else if(unused_response_valid)diagnostic_response_owner<=1'b0;
    end
    wire diagnostic_response_selected=diagnostic_response_valid ||
        (diagnostic_response_owner && !unused_response_valid);

    assign resource_response_valid=bt_usb_reject_valid||diagnostic_response_valid||unused_response_valid;

    assign resource_response_seq=bt_usb_reject_selected ? bt_usb_reject_seq:diagnostic_response_selected ? diagnostic_response_seq:unused_response_seq;

    assign resource_response_length=bt_usb_reject_selected ? 8'd2:diagnostic_response_selected ? diagnostic_response_length:unused_response_length;

    assign resource_response_payload=bt_usb_reject_selected ? {752'd0,8'd3,bt_usb_reject_type}:diagnostic_response_selected ? diagnostic_response_payload:unused_response_payload;

    // 138K统一测试、观察和LED平台；测试声源显式选择，不隐藏在普通键扫描中。

    wire [3:0] ui_view,led_self_test;wire [2:0] test_kind;wire test_panic;

    wire [1:0] graph_kind;wire freeze_graph,right_channel;wire [5:0] solo;
    reg liss_fx_pair;reg [1:0] liss_stride;wire [7:0] graph_config;
    reg [47:0] dry_history;reg signed [15:0] aligned_dry_frame;


    wire [7:0] test_result;wire [31:0] test_event_id,test_session;wire [6:0] test_event_note;wire [4:0] test_event_timbre;

    field_test_models8_control test_center(.clk(system_clk),.rst_n(rst_n),.command_valid(cmd_valid),.command_op(cmd_op),.command_value(cmd_value),

        .external_stop(emergency_stop||mode_pressed||performance_stop||mode_changed),.event_ready(synth_ready),

        .view(ui_view),.test_kind(test_kind),.test_active(test_active),.panic(test_panic),.result(test_result),

        .graph_kind(graph_kind),.freeze_graph(freeze_graph),.right_channel(right_channel),.solo(solo),.led_self_test(led_self_test),

        .event_valid(test_event_valid),.event_id(test_event_id),.event_note(test_event_note),.event_timbre(test_event_timbre),.session(test_session));

    wire diagnostic_audio=test_kind==1||test_kind==5||test_kind==6;

    wire signed [15:0] diagnostic_left,diagnostic_right;

    wire [31:0] diagnostic_active;wire diagnostic_deadline;

    diagnostic_dds32 test_tones(.clk(system_clk),.rst_n(rst_n),.sample_tick(live_sample_tick),.clear(synth_panic),.kind(test_kind),.solo(solo),

        .left(diagnostic_left),.right(diagnostic_right),.active(diagnostic_active),.deadline_error(diagnostic_deadline));

    wire signed [15:0] dac_left=diagnostic_audio ? diagnostic_left:output_frame_pcm;

    wire signed [15:0] dac_right=diagnostic_audio ? diagnostic_right:output_frame_pcm;

    wire [31:0] display_voice_mask=diagnostic_audio ? diagnostic_active:voice_mask;

    // 观察声部数采用五层平衡树，避免32次串行累加直达状态回包；无新增采样延迟。
    wire [5:0] display_voices;
    workstation_voice_count display_counter(.mask(display_voice_mask),.count(display_voices));

    reg [5:0] peak_voices;reg [31:0] timeout_count;reg old_deadline;

    always @(posedge system_clk)begin

        if(!rst_n||test_panic)begin peak_voices<=0;timeout_count<=0;old_deadline<=0;end

        else begin

            if(display_voices>peak_voices)peak_voices<=display_voices;

            old_deadline<=deadline_error||diagnostic_deadline;

            if((deadline_error||diagnostic_deadline)&&!old_deadline)timeout_count<=timeout_count+1'b1;

        end

    end

    workstation_hw_status #(.BUILD_ID(BUILD_ID)) hardware_monitor(
        .app_clk(system_clk),.rst_n(rst_n),.mem_clk(ddr_user_clk),.mem_rst_n(ddr_user_rst_n),
        .pll_locked(ddr_pll_locked),.calibrated(ddr_calibrated),.storage_ready(storage_ready),
        .request_fire(ddr_req_valid&&ddr_req_ready),.response_fire(ddr_resp_valid&&ddr_resp_ready),.response_error(ddr_resp_error),
        .command_fire(ddr_cmd_en&&ddr_cmd_ready),.command_write(ddr_cmd==0),.reinit(ddr_reinit),
        .sample_tick(live_sample_tick),.sample_valid(engine_sample_valid),.voices(voices),.peak_voices(peak_voices),
        .deadline_error(deadline_error),.parameter_error(parameter_error),.timeout_count(timeout_count),.status(hardware_status));
    wire graph_ready,graph_lock_granted,screen_graph_lock,host_graph_lock,fft_busy;

    wire [5:0] graph_address,host_graph_address;wire [15:0] graph_data,host_graph_data;

    wire [31:0] graph_revision;wire [63:0] peak_bins,peak_magnitudes;

    audio_observer observer(.aligned_dry(aligned_dry_frame),.effect_output(output_frame_pcm),.liss_fx_pair(liss_fx_pair),.liss_stride(liss_stride),.graph_config(graph_config),.clk(system_clk),.rst_n(rst_n),.clear(synth_panic),.sample_tick(live_sample_tick),.left(dac_left),.right(dac_right),

        .graph_kind(graph_kind),.freeze_graph(freeze_graph),.right_channel(right_channel),

        .read_lock(screen_graph_lock||host_graph_lock),.read_address(graph_address),.host_address(host_graph_address),

        .read_data(graph_data),.host_data(host_graph_data),.lock_granted(graph_lock_granted),.revision(graph_revision),

        .peak_bins(peak_bins),.peak_magnitudes(peak_magnitudes),.ready(graph_ready),.fft_busy(fft_busy));

    wire [431:0] runtime_snapshot;

    assign runtime_snapshot={test_session,effective_keys,peak_magnitudes,peak_bins,8'd0,test_result,

        {4'd0,graph_ready,right_channel,freeze_graph,test_active},{6'd0,graph_kind},graph_revision,timeout_count,

        display_voice_mask,{2'd0,peak_voices},{2'd0,display_voices},{4'd0,ui_view},{5'd0,test_kind},

        32'h0000007f,32'd48000,BUILD_ID};

    wire app_valid;wire [7:0] app_op;wire [31:0] app_value,app_aux;

    wire player_done;wire [7:0] player_result;

    mega138_models8_diagnostics #(.BUILD_ID(BUILD_ID),.ADC_PRESENT_MASK(ADC_PRESENT_MASK),.KEY_ENABLE_MASK(KEY_ENABLE_MASK),.HEADPHONE_BOOST(HEADPHONE_BOOST)) diagnostics(

        .clk(system_clk),.rst_n(rst_n),.frame_valid(resource_frame_valid&&diagnostic_frame),.frame_type(frame_type),.frame_seq(frame_seq),.frame_length(frame_length),.payload(frame_payload),

        .response_busy(resource_response_busy),.response_valid(diagnostic_response_valid),.response_seq(diagnostic_response_seq),.response_length(diagnostic_response_length),.response_payload(diagnostic_response_payload),

        .clear_tone(emergency_stop||mode_changed||performance_stop),.mode(app_mode),.voices(voices),.calibrated(calibrated),.adc_ready(adc_ready),.deadline_error(deadline_error),.clipped(synth_clipped||master_clipped),.param_error(parameter_error),

        .keys(effective_keys),.adc(adc_samples),.baseline(baseline_values),.pressure(pressure_values),.master_boost(master_boost),.key_enable(enabled_keys),.mask_changed(mask_changed),.tone_active(tone_active),.tone_changed(tone_changed),
        .live_volume(piano_volume),.song_volume(midi_volume),.live_fx_target(live_fx_target),.song_fx_target(song_fx_target),
        .live_fx_gain(live_fx_gain),.song_fx_gain(song_fx_gain),.limiter_enabled(limiter_enabled),.limiter_release(limiter_release),
        .bus_valid(player_done&&player_result==0&&app_op==52),.bus_setting(app_value[2:0]),.bus_value(app_aux[7:0]),
        .limiter_gain(limiter_gain),.gain_stats(gain_stats),.gain_stats_clear(gain_stats_clear),

        .control_valid(diagnostic_control_valid),.control_op(diagnostic_op),.control_value(diagnostic_value),

        .runtime(runtime_snapshot),.graph_ready(graph_ready),.graph_revision(graph_revision),

        .graph_lock(host_graph_lock),.graph_address(host_graph_address),.graph_data(host_graph_data),.lock_granted(graph_lock_granted));


    wire player_service_done,pitch_done,lesson_done;wire [7:0] player_service_result,pitch_result,lesson_result;
    wire lesson_request=app_valid&&app_op==49;
    wire lesson_invalid=lesson_request&&(app_value>5||app_aux>15);
    wire lesson_active,lesson_prepare,lesson_reader_enable,lesson_quiet,lesson_parsed;
    wire [10:0] lesson_reader_index;wire [11:0] lesson_event_count;
    wire [31:0] lesson_event_start,lesson_event_end;wire [6:0] lesson_event_note;wire [3:0] lesson_event_track;
    wire [15:0] lesson_guide;wire [111:0] lesson_pitch_map;wire [15:0] lesson_enabled;
    wire [511:0] demo_audio_status,demo_fx_status;
    wire [127:0] demo_note_status;
    wire [255:0] demo_lesson_status;
    wire [5:0] rendered_voices;wire [4:0] engine_command_slot;
    wire offset_write;wire [4:0] offset_key;wire [31:0] offset_id;wire signed [6:0] offset_value;
    reg [1:0] accepted_source;reg [4:0] accepted_key;reg [31:0] accepted_id;reg [6:0] accepted_note;
    assign player_done=player_service_done||pitch_done||lesson_done||lesson_invalid;
    assign player_result=lesson_invalid ? 8'd1:lesson_done ? lesson_result:pitch_done ? pitch_result:player_service_result;
    always @(posedge system_clk)begin
        if(!rst_n)begin liss_fx_pair<=0;liss_stride<=1;end
        else if(player_done&&player_result==0&&app_op==51)begin liss_fx_pair<=app_value[0];liss_stride<=app_aux[1:0];end
        // 效果/合唱/总增益各使用前帧结果；干声同步延迟3帧，保留效果本身的延迟。
        if(!rst_n||synth_panic)begin dry_history<=0;aligned_dry_frame<=0;end
        else if(live_sample_tick)begin dry_history<={dry_history[31:0],dry_pcm};aligned_dry_frame<=dry_history[47:32];end
    end

    wire [7:0] piano_vol_s,drum_vol_s;

    audio_params params(.clk(system_clk),.rst_n(rst_n),.sample_tick(live_sample_tick),

        .cmd_valid(cmd_valid),.cmd_op(cmd_op),.cmd_value(cmd_value),

        .app_valid(player_done&&player_result==0),.app_op(app_op),.app_value(app_value),.app_aux(app_aux),
        .damping_settings(damping_settings),
        .velocity_tone_setting(velocity_tone_setting),

        .piano_volume_in({1'b0,piano_volume}),.drum_volume_in({1'b0,drum_volume}),

        .bend(bend),.transpose(live_transpose),.vibrato_depth(vibrato_depth),.vibrato_rate(vibrato_rate),

        .chorus_mix(chorus_mix),.chorus_depth(chorus_depth),.chorus_rate(chorus_rate),

        .delay_mix(delay_mix),.reverb_mix(reverb_mix),.feedback(feedback),.delay_samples(delay_time),.fx_preview(fx_preview),

        .env_a(env_a),.env_d(env_d),.env_s(env_s),.env_r(env_r),.env_write(env_write_pulse),.command_error(audio_parameter_error),

        .piano_volume(piano_vol_s),.drum_volume(drum_vol_s));

    wire [7:0] legacy_op,legacy_value;wire legacy_valid;

    wire map_valid,adsr_valid,adsr_done;wire [15:0] map_descriptor;wire [31:0] adsr_value,adsr_aux;wire [7:0] adsr_result,screen_result;

    wire [255:0] active_map;wire [2:0] edit_bank;wire [3:0] edit_key;wire [15:0] edit_descriptor;

    wire [15:0] physical_piano_keys,screen_piano_keys,chord_keys,manual_drums;wire [127:0] physical_notes,manual_velocities;

    wire [95:0] physical_timbres;wire [15:0] beat_drums;wire [63:0] beat_patterns;wire [15:0] beat_sounds;

    wire beat_running;wire [7:0] beat_bpm;wire [3:0] beat_step;

    reg [4:0] scan_key;reg [31:0] applied;reg [7:0] applied_velocity[0:31];reg [6:0] applied_note[0:31];

    // 映射快照、移调、差异检测分周期执行，切断命令到音源使能的长组合路径。

    reg [1:0] scan_phase;

    reg sampled_down;reg [7:0] sampled_offset,sampled_velocity;reg [4:0] sampled_timbre;
    pressure_touch_curve pressure_touch(.raw_velocity(sampled_velocity[7:1]),
        .sensitivity(sampled_touch_settings[1:0]),.curve(sampled_touch_settings[3:2]),
        .minimum_velocity(sampled_touch_settings[10:4]),.velocity(touch_velocity));

    // 键映射先锁存原始音色与跟随预设，下一拍译码；音高计算再后一拍，避免命令译码直达宽选择器。
    reg [5:0] sampled_raw_timbre;reg [4:0] sampled_follow;
    reg sampled_tone,sampled_drum;reg [2:0] sampled_drum_index;

    reg signed [6:0] sampled_transpose;reg [1:0] sampled_octave;

    reg signed [10:0] target_pitch;

    reg [223:0] live_offsets;
    wire signed [11:0] adjusted_target=$signed(target_pitch)+$signed(applied[scan_key] ? live_offsets[scan_key*7+:7]:7'sd0);
    wire [6:0] target_note=adjusted_target<0 ? 7'd0:adjusted_target>127 ? 7'd127:adjusted_target[6:0];

    // 16个屏幕键保留原独立表：[15:14]类型、[13:8]音色、[7:0]音阶偏移0..15；本版只接收旋律音色10/19/20或跟随63。

    // 以下旧鼓号转换函数仅保留源码兼容，当前无鼓路由不接受打击乐请求。

    // 历史编号转换保持原样，不把保留函数计为已实现的鼓功能。

    function automatic [4:0] builtin_drum(input [2:0] index);

        case(index)

            0:builtin_drum=14;1:builtin_drum=11;2:builtin_drum=12;3:builtin_drum=13;

            4:builtin_drum=15;5:builtin_drum=16;6:builtin_drum=17;7:builtin_drum=18;

        endcase

    endfunction

    function automatic [4:0] resolve_timbre(input [5:0] raw,input [4:0] follow);

        // 63是映射层哨兵，必须先在6位域判定；它从不进入5位引擎端口。

        if(raw==6'd63)resolve_timbre=follow;

        else if((raw==10||raw==19||raw==20))resolve_timbre=raw[4:0];

        else resolve_timbre=5'd31; // 无效编号显式拒绝，不能别名为钢琴或另一种鼓。

    endfunction

    reg [15:0] screen_map[0:15];reg [7:0] screen_vel[0:15];reg [3:0] screen_sel;

    reg [15:0] screen_drum_fire,screen_prev,screen_blocked;reg [127:0] screen_drum_vel;

    wire performing=app_mode>=1 && app_mode<=3;

    wire [15:0] accepted_screen_keys=performing && !synth_panic ? screen_touch_keys & ~screen_blocked:16'd0;

    integer si;

    always @(posedge system_clk)begin

        if(!rst_n)begin

            for(si=0;si<16;si=si+1)begin screen_map[si]<=16'h3f00|16'(si);screen_vel[si]<=8'd100;end

            screen_sel<=0;route_parameter_error<=0;screen_drum_fire<=0;screen_prev<=0;screen_blocked<=16'hffff;screen_drum_vel<=0;

        end else begin

            screen_drum_fire<=0;

            screen_blocked<=!performing || synth_panic ? screen_touch_keys:screen_blocked & screen_touch_keys;

            route_parameter_error<=0;

            if(select_builtin&&(cmd_value<10||cmd_value>20))route_parameter_error<=1;

            if(cmd_valid)case(cmd_op)

                8'h30: if(cmd_value<16) screen_sel<=cmd_value[3:0];else route_parameter_error<=1;

                8'h31: if(cmd_value==0)screen_map[screen_sel]<={cmd_value[1:0],screen_map[screen_sel][13:0]};else route_parameter_error<=1;

                8'h32: screen_map[screen_sel]<={screen_map[screen_sel][15:8],cmd_value[7:0]};

                8'h33: screen_vel[screen_sel]<=cmd_value[7:0];

                8'h34: if(((cmd_value==10||cmd_value==19||cmd_value==20))||cmd_value==63)

                    screen_map[screen_sel]<={screen_map[screen_sel][15:14],cmd_value[5:0],screen_map[screen_sel][7:0]};

                    else route_parameter_error<=1;

                default:;

            endcase

            screen_prev<=accepted_screen_keys;

            for(si=0;si<16;si=si+1) if(accepted_screen_keys[si]&&!screen_prev[si]&&screen_map[si][15:14]==1) begin

                screen_drum_fire[screen_map[si][3:0]]<=1'b1;

                screen_drum_vel[screen_map[si][3:0]*8+:8]<=screen_vel[si];

            end

        end

    end

    wire [15:0] screen_note_keys;

    genvar sgi;generate for(sgi=0;sgi<16;sgi=sgi+1) begin:g_screen_note

        assign screen_note_keys[sgi]=accepted_screen_keys[sgi]&&

            (screen_map[sgi][15:14]==0||(screen_map[sgi][15:14]==1&&screen_map[sgi][7:0]<8));

    end endgenerate

    wire [31:0] input_keys=test_active ? 32'd0:tone_active ? 32'd1:{screen_note_keys,physical_piano_keys};

    // 安全请求先寄存再送入音频/路由，切断legacy命令译码到整机清音的长组合路径。

    // 额外一拍为20ns，不改变停止、换模式或回首页的清音语义。

    always @(posedge system_clk)begin

        if(!rst_n)synth_panic<=1'b1;

        else synth_panic<=mode_changed || map_changed || performance_stop || emergency_stop || mask_changed || tone_changed || test_panic || builtin_changed;

    end

    wire [127:0] all_drum_velocities;

    genvar drum_index;generate for(drum_index=0;drum_index<16;drum_index=drum_index+1) begin:g_drum_velocity

        wire [7:0] physical_level=manual_drums[drum_index] ? manual_velocities[drum_index*8+:8]:8'd0;

        wire [7:0] song_level=player_drums[drum_index] ? player_drum_velocities[drum_index*8+:8]:8'd0;

        wire [7:0] screen_level=screen_drum_fire[drum_index] ? screen_drum_vel[drum_index*8+:8]:8'd0;

        wire [7:0] level=screen_level!=0 ? screen_level : (physical_level>song_level ? physical_level:song_level);

        assign all_drum_velocities[drum_index*8+:8]=beat_drums[drum_index] && level<112 ? 8'd112:level;

    end endgenerate

    wire [15:0] all_drums=tone_active ? 16'd0:manual_drums|player_drums|beat_drums|screen_drum_fire;

    // 压力统计已移除：状态页总压力字段固定为 0，不进入声音路径。

    assign max_pressure=13'd0;

    wire [223:0] status_data={7'd0,deadline_error,7'd0,loop_enabled,loop_a,chord_keys,4'd0,max_pressure[11:0],

        directory_revision,duration,position,{2'd0,voices},{3'd0,section},{3'd0,live_patch},{6'd0,selected_song},

        {4'd0,parser_error,midi_parser_busy,paused,midi_playing},{5'd0,app_mode}};

    assign hpd_en=1;assign mcp0_sclk=mcp_sclk_int;assign mcp1_sclk=mcp_sclk_int;

    assign mcp0_mosi=mcp_mosi_int;assign mcp1_mosi=mcp_mosi_int;

    assign hp_bck=live_hp_bck;assign hp_ws=live_hp_ws;assign hp_din=live_hp_din;
    // PA_EN低有效；复位时强制关闭功放，不能用rst_n与门把它拉低。
    assign pa_en=(!rst_n)||(!ONBOARD_DAC)||live_pa_en;

    led8_guide guide_leds(.clk(system_clk),.rst_n(rst_n),.guide_keys(lesson_active ? lesson_guide:guide_keys),.self_test(led_self_test),.led_n(led_n));   // 低电平点亮，指引当前应弹的键

    assign live_keys=chord_keys;assign live_active_key_count=active_key_count;

    assign midi_file_ready=selected_ready;assign midi_led_n=~{2'b0,voices};

    assign performance_stop=legacy_valid && legacy_op==2 && legacy_value==255;

    reset_sync reset_sync_inst(.clk(system_clk),.arst_n(reference_rst_n&&ddr_pll_locked),.rst_n(rst_n));

    button_filter mode_button(.clk(system_clk),.rst_n(rst_n),.key_n(mode_key_n),.pressed(mode_pressed));

    button_filter timbre_button(.clk(system_clk),.rst_n(rst_n),.key_n(timbre_key_n),.pressed(timbre_pressed));

    uart_rx #(.CLKS_PER_BIT(USB_CLKS_PER_BIT)) usb_rx(.clk(system_clk),.rst_n(rst_n),.rx(uart_rx_i),.data(usb_byte),.valid(usb_valid),.framing_error(usb_bad));

    uart_frame_protocol frames(.clk(system_clk),.rst_n(rst_n),.rx_data(usb_byte),.rx_valid(usb_valid),

        .frame_valid(frame_valid),.bad_frame(),.frame_type(frame_type),.frame_seq(frame_seq),.frame_length(frame_length),.frame_payload(frame_payload));

    uart_frame_tx_v2 #(.CLKS_PER_BIT(USB_CLKS_PER_BIT)) responses(.clk(system_clk),.rst_n(rst_n),.response_valid(response_valid),.response_type(8'h81),

        .response_seq(response_seq),.response_length(response_length),.response_payload(response_payload),.tx(uart_tx_o),.busy(response_busy));

    wire [3:0] catalog_index;wire [255:0] catalog_name;wire catalog_ready;wire [31:0] catalog_duration;wire [5:0] catalog_sections;

    workstation_v2_emergency emergency(.clk(system_clk),.rst_n(rst_n),.frame_valid(frame_valid),.frame_type(frame_type),.frame_seq(frame_seq),.frame_length(frame_length),.payload(frame_payload),

        .normal_frame_valid(raw_resource_frame_valid),.panic(usb_emergency_stop),.abort_upload(emergency_abort),

        .normal_response_valid(resource_response_valid),.normal_response_seq(resource_response_seq),.normal_response_length(resource_response_length),.normal_response_payload(resource_response_payload),.normal_response_busy(resource_response_busy),

        .response_valid(response_valid),.response_seq(response_seq),.response_length(response_length),.response_payload(response_payload),.response_busy(response_busy));

    workstation_cut123_resources #(.ENABLE_EMERGENCY(1),.BUILTIN_PIANO(1)) resources(.remote_idle(resource_idle),.pressure_touch_settings(pressure_touch_settings),.velocity_tone_setting(velocity_tone_setting),.damping_settings(damping_settings),.chord_status(chord_status),.clk(system_clk),.rst_n(rst_n),.hardware_status(hardware_status),.demo_audio_status(demo_audio_status),.demo_fx_status(demo_fx_status),.demo_note_status(demo_note_status),.demo_lesson_status(demo_lesson_status),.frame_valid(resource_frame_valid&&!diagnostic_frame),.frame_type(frame_type),.frame_seq(frame_seq),.frame_length(frame_length),.payload(frame_payload),

        .emergency_abort(emergency_abort),.storage_ready(storage_ready),

        .ddr_req_valid(ddr_req_valid),.ddr_req_ready(ddr_req_ready),.ddr_req_write(ddr_req_write),.ddr_req_address(ddr_req_address),.ddr_req_data(ddr_req_data),.ddr_req_mask(ddr_req_mask),

        .ddr_resp_valid(ddr_resp_valid),.ddr_resp_ready(ddr_resp_ready),.ddr_resp_error(ddr_resp_error),.ddr_resp_data(ddr_resp_data),

        .response_valid(unused_response_valid),.response_seq(unused_response_seq),.response_length(unused_response_length),.response_payload(unused_response_payload),.response_busy(resource_response_busy),

        .control_valid(host_valid),.control_op(host_op),.control_value(host_value),.control_aux(host_aux),.control_done(host_done),.control_result(host_result),.status_data(status_data),

        .runtime_data(runtime_data),.command_feedback(command_feedback),.track_gains(player_track_gains),

        .track_timbres(player_track_timbres),.track_volumes(player_track_volumes),.track_mutes(player_track_mutes),.track_solos(player_track_solos),.channel_map(player_channel_map),

        .validation_start(validation_start),.validation_release(validation_release),

        .validation_done(validation_done),.validation_busy(midi_parser_busy),.validation_error(parser_error),.validation_duration(validation_duration),

        .selected_song(selected_song),.song_read_address(file_address),.song_read_data(file_data),.selected_size(selected_size),.selected_ready(selected_ready),.selected_duration(duration),

        .song_ready_mask(song_ready_mask),.patch_ready_mask(patch_ready_mask),.table_write(table_write),.table_address(table_address),.table_data(table_data),

        .parameter_write(parameter_write),.parameter_bank(parameter_bank),.envelope_parameters(envelope_parameters),.envelope_read_bank(live_patch),.envelope_read_data(current_envelope),

        .external_adsr_valid(adsr_valid),.external_adsr_value(adsr_value),.external_adsr_aux(adsr_aux),.external_adsr_done(adsr_done),.external_adsr_result(adsr_result),

        .section_read_address(section_address),.section_data(section_data),.selected_sections(section_count),

        .catalog_index(catalog_index),.catalog_name(catalog_name),.catalog_ready(catalog_ready),.catalog_duration(catalog_duration),.catalog_sections(catalog_sections),.directory_revision(directory_revision));

    screen_touch_keys_rx #(.CLKS_PER_BIT(SCREEN_CLKS_PER_BIT),.KEY_COUNT(16),.POLYPHONIC(1),.PERFORMANCE_CONTROLS(1),.WORKSTATION_CONTROLS(1)) touch(

        .clk(system_clk),.rst_n(rst_n),.screen_rx_i(screen_rx_i),.held_keys(screen_touch_keys),.octave_shift(live_octave_shift),

        .test_mode(),.rx_activity(screen_rx_activity),.frame_error(),.command_valid(screen_valid),.command_op(screen_op),.command_value(screen_value));

    // 原USB普通事务与蓝牙租约互斥；急停仍由上游0x3B专用路径处理。
    r7_bt_usb_guard bt_usb_guard(.clk(system_clk),.rst_n(rst_n),.lease_active(bt_lease),
        .external_cancel(usb_emergency_stop||emergency_abort),.frame_valid(raw_resource_frame_valid),
        .frame_type(frame_type),.frame_seq(frame_seq),.response_busy(resource_response_busy),
        .ordinary_tx_fire(response_valid&&!response_busy&&response_payload[7:0]!=8'h3b),
        .resources_idle(resource_idle),.remote_idle(remote_command_idle),.any_usb_frame(frame_valid),
        .any_response(response_valid||response_busy||resource_response_valid),
        .forward_valid(resource_frame_valid),.claim_idle(bt_claim_idle),.reject_valid(bt_usb_reject_valid),
        .reject_seq(bt_usb_reject_seq),.reject_type(bt_usb_reject_type),.reject_selected(bt_usb_reject_selected));
    // 32字节小端快照：仅封装实际寄存器，不由电脑草稿推断设备状态。
    assign bt_status={5'd0,limiter_release,limiter_enabled,song_fx_target,live_fx_target,{2'd0,voices},
        song_ready_mask,position,directory_revision,
        {3'd0,(synth_clipped||master_clipped),deadline_error,paused,midi_playing,storage_ready},
        {1'b0,delay_time},feedback,chorus_rate,chorus_depth,chorus_mix,reverb_mix,delay_mix,
        {6'd0,master_boost},{1'b0,midi_volume},{1'b0,piano_volume},{3'd0,screen_patch},{3'd0,live_patch},{5'd0,app_mode},8'd1};
    r7_bt_uart_link #(.CLKS_PER_BIT(BT_CLKS_PER_BIT),.BUILD_ID(BUILD_ID)) bt_link(
        .clk(system_clk),.rst_n(rst_n),.bt_rx_i(bt_rx_i),.bt_tx_o(bt_tx_o),
        .usb_idle(bt_claim_idle),.external_cancel(usb_emergency_stop||emergency_abort),.status_data(bt_status),
        .lease_active(bt_lease),.command_valid(bt_command_valid),.command_op(bt_command_op),
        .command_value(bt_command_value),.command_aux(bt_command_aux),.command_ready(bt_command_ready),
        .command_done(bt_command_done),.command_result(bt_command_result),.command_cancel(bt_command_cancel),
        .emergency(bt_emergency),.accepted_commands(bt_accepted_commands),.bad_frame());
    r7_bt_host_bridge remote_bridge(.clk(system_clk),.rst_n(rst_n),.global_stop(emergency_stop),
        .usb_valid(host_valid),.usb_op(host_op),.usb_value(host_value),.usb_aux(host_aux),
        .usb_done(host_done),.usb_result(host_result),.bt_valid(bt_command_valid),.bt_op(bt_command_op),
        .bt_value(bt_command_value),.bt_aux(bt_command_aux),.bt_ready(bt_command_ready),
        .bt_done(bt_command_done),.bt_result(bt_command_result),.bt_cancel(bt_command_cancel),
        .host_valid(merged_host_valid),.host_op(merged_host_op),.host_value(merged_host_value),.host_aux(merged_host_aux),
        .host_done(merged_host_done),.host_result(merged_host_result),.host_cancel(merged_host_cancel),.remote_idle(remote_command_idle));

    workstation_cut123_commands commands(.clk(system_clk),.rst_n(rst_n),

        .emergency_stop(emergency_stop),.host_cancel(merged_host_cancel),

        .host_valid(merged_host_valid),.host_op(merged_host_op),.host_value(merged_host_value),.host_aux(merged_host_aux),.host_done(merged_host_done),.host_result(merged_host_result),

        .screen_valid(cmd_valid&&((!performance_parameter&&cmd_op<8'h60&&cmd_op!=8'h0c)||(cmd_op>=8'h70&&cmd_op<=8'h77)||cmd_op>=8'h80)),.screen_op(cmd_op),.screen_value(cmd_value),

        .safety_stop(performance_stop||mode_changed),.timbre_pressed(1'b0),.live_patch(live_patch),

        .app_valid(app_valid),.app_op(app_op),.app_value(app_value),.app_aux(app_aux),.app_done(player_done),.app_result(player_result),

        .legacy_valid(legacy_valid),.legacy_op(legacy_op),.legacy_value(legacy_value),.legacy_error(command_error),

        .map_valid(map_valid),.map_descriptor(map_descriptor),.adsr_valid(adsr_valid),.adsr_value(adsr_value),.adsr_aux(adsr_aux),

        .adsr_done(adsr_done),.adsr_result(adsr_result),.screen_result(screen_result),.command_feedback(command_feedback));

    instrument_models8_modes #(.MODE_SLOTS(4)) modes(.clk(system_clk),.rst_n(rst_n),.cmd_valid(legacy_valid),.mode_pressed(mode_pressed),

        .direct_valid(map_valid),.direct_descriptor(map_descriptor),

        .cmd_op(legacy_op),.cmd_value(legacy_value),.mode(app_mode),.mode_changed(mode_changed),.map_changed(map_changed),

        .command_error(command_error),.active_map(active_map),.edit_bank(edit_bank),.edit_key(edit_key),.edit_descriptor(edit_descriptor),

        .piano_volume(piano_volume),.drum_volume(drum_volume),.midi_volume(midi_volume),.midi_start(midi_start),.midi_stop(midi_stop),.boot_pending(boot_pending));

    workstation_models8_router router(.clk(system_clk),.rst_n(rst_n),.mode_changed(mode_changed),.map_changed(map_changed||performance_stop||emergency_stop||mask_changed||builtin_changed),

        .mode(app_mode),.active_map(active_map),.physical_keys(effective_keys),.screen_keys(screen_touch_keys),.physical_velocity(velocity_values),

        .physical_piano_keys(physical_piano_keys),.physical_notes(physical_notes),.physical_timbres(physical_timbres),

        .screen_piano_keys(screen_piano_keys),.chord_keys(chord_keys),.drum_triggers(manual_drums),.drum_velocity(manual_velocities));

    workstation_cut123_player player(.clk(system_clk),.rst_n(rst_n),.emergency_stop(emergency_stop),.emergency_abort(emergency_abort),.command_valid(app_valid&&app_op!=48&&app_op!=49),.command_op(app_op),.command_value(app_value),.command_aux(app_aux),

        .validation_start(validation_start),.validation_release(validation_release),.validation_done(validation_done),.validation_duration(validation_duration),.runtime_data(runtime_data),

        .command_done(player_service_done),.command_result(player_service_result),.song_ready_mask(song_ready_mask),.patch_ready_mask(patch_ready_mask),

        .selected_song(selected_song),.selected_ready(selected_ready),.selected_size(selected_size),.duration(duration),

        .file_read_address(file_address),.file_read_data(file_data),.section_count(section_count),.section_address(section_address),.section_data(section_data),

        .playing(midi_playing),.paused(paused),.parser_busy(midi_parser_busy),.parser_error(parser_error),.tick(position),.section(section),

        .loop_enabled(loop_enabled),.loop_a(loop_a),.loop_b(loop_b),.live_timbre(player_live_patch),.screen_timbre(player_screen_patch),.live_transpose(transpose_unused),

        .bend(bend_unused),.vibrato_depth(vdepth_unused),.vibrato_rate(vrate_unused),.delay_mix(delay_mix_unused),.reverb_mix(reverb_mix_unused),.feedback(feedback_unused),.delay_time(delay_time_unused),.panic(player_panic),

        .event_valid(player_event_valid),.event_ready(player_event_ready),.event_op(player_event_op),.event_source(player_event_source),.event_id(player_event_id),.event_note(player_note),.event_velocity(player_velocity),.event_timbre(player_timbre),

        .event_track(player_track),.track_gains(player_track_gains),.channel_map(player_channel_map),

        .track_timbres(player_track_timbres),.track_volumes(player_track_volumes),.track_mutes(player_track_mutes),.track_solos(player_track_solos),

        .drum_triggers(player_drums),.drum_velocities(player_drum_velocities),.guide_keys(guide_keys),
        .lesson_begin(lesson_request&&!lesson_invalid&&(app_value==1||app_value==2)),.lesson_prepare(lesson_prepare),
        .lesson_hold(lesson_active),.lesson_reader_enable(lesson_reader_enable),.lesson_reader_index(lesson_reader_index),
        .lesson_quiet(lesson_quiet),.lesson_parsed(lesson_parsed),.lesson_event_count(lesson_event_count),
        .lesson_event_start(lesson_event_start),.lesson_event_end(lesson_event_end),.lesson_event_note(lesson_event_note),.lesson_event_track(lesson_event_track));

    // 每次新的按下分配32位音符ID；松开/压力更新沿用该键的ID，尾音未结束也能重弹。

    reg [31:0] next_realtime_id;reg [1023:0] key_note_ids;integer token_index;

    always @(posedge system_clk)begin

        if(!rst_n)begin next_realtime_id<=1;key_note_ids<=0;end

        else if(!synth_panic&&!realtime_valid&&scan_phase==3&&sampled_down&&!applied[scan_key])begin

            next_realtime_id<=next_realtime_id+1'b1;

            for(token_index=0;token_index<32;token_index=token_index+1)

                if(scan_key==token_index)key_note_ids[token_index*32+:32]<=next_realtime_id;

        end

    end

    assign player_event_ready=synth_ready && !realtime_valid && !test_active;

    always @(posedge system_clk) begin

        if(!rst_n || synth_panic) begin scan_key<=0;scan_phase<=0;sampled_down<=0;sampled_offset<=0;sampled_velocity<=0;sampled_timbre<=0;sampled_transpose<=0;sampled_octave<=0;target_pitch<=0;applied<=0;realtime_valid<=0;realtime_op<=0;realtime_source<=0;realtime_id<=0;realtime_note<=0;realtime_velocity<=0;realtime_timbre<=0;
            sampled_raw_timbre<=0;sampled_follow<=10;sampled_tone<=0;sampled_drum<=0;sampled_drum_index<=0;
            sampled_physical<=0;sampled_touch_settings<=11'd261;
        end

        else if(realtime_valid) begin if(synth_ready) begin realtime_valid<=0;scan_key<=scan_key+1'b1;scan_phase<=0;end end

        else if(scan_phase==0) begin

            sampled_down<=input_keys[scan_key];

            sampled_offset<=tone_active ? 8'd0:scan_key<16 ? physical_notes[scan_key*8+:8]:

                screen_map[scan_key-16][15:14]==1 ? 8'd0:screen_map[scan_key-16][7:0];

            sampled_velocity<=tone_active ? 8'd200:scan_key<16 ? velocity_values[scan_key*8+:8]:screen_vel[scan_key-16];
            sampled_physical<=!tone_active&&scan_key<16;
            sampled_touch_settings<=pressure_touch_settings;

            sampled_raw_timbre<=scan_key<16 ? physical_timbres[scan_key*6+:6]:screen_map[scan_key-16][13:8];
            sampled_follow<=scan_key<16 ? live_patch:screen_patch;
            sampled_tone<=tone_active;sampled_drum<=scan_key>=16&&screen_map[scan_key-16][15:14]==1;
            sampled_drum_index<=scan_key<16 ? 3'd0:screen_map[scan_key-16][2:0];

            sampled_transpose<=tone_active ? 7'sd0:live_transpose;sampled_octave<=tone_active ? 2'd0:live_octave_shift;scan_phase<=1;

        end else if(scan_phase==1) begin

            // 只改变实体压力键；屏幕力度、伴奏MIDI、诊断测试与原有音色精度保持原路。
            // 与本键输入一起锁存设置，避免一次扫描混合两份配置；加压仅发连续更新。
            if(sampled_physical)sampled_velocity<={touch_velocity,1'b0};

            sampled_timbre<=sampled_tone ? 5'd10:sampled_drum ? builtin_drum(sampled_drum_index):resolve_timbre(sampled_raw_timbre,sampled_follow);
            scan_phase<=2;

        end else if(scan_phase==2) begin

            // 范围 -76..390，11位有符号数足够，保留越界音高的饱和处理。

            target_pitch<=(sampled_timbre>=11&&sampled_timbre<=18) ? 11'sd60:11'sd57+$signed({3'd0,sampled_offset})+

                (sampled_octave==1 ? 11'sd12:sampled_octave==2 ? -11'sd12:11'sd0)+sampled_transpose;

            scan_phase<=3;

        end else begin

            if(sampled_down!=applied[scan_key] || (sampled_down && (applied_note[scan_key]!=target_note || (scan_key<16 && applied_velocity[scan_key]!=sampled_velocity)))) begin

                realtime_valid<=1;realtime_source<=scan_key<16 ? 0:1;realtime_id<=sampled_down&&!applied[scan_key] ? next_realtime_id:key_note_ids[scan_key*32+:32];

                realtime_op<=!sampled_down ? 0 : applied[scan_key[4:0]] ? 3:1;

                realtime_note<=target_note;applied_note[scan_key]<=target_note;

                // 有效按压保留可配置的ppp下限，避免32音固定余量下轻按被16位量化为静音；ADC压力显示不变。

                realtime_velocity<=sampled_velocity[7:1]<MIN_LIVE_VELOCITY ? MIN_LIVE_VELOCITY:sampled_velocity[7:1];

                realtime_timbre<=sampled_timbre;

                applied[scan_key]<=sampled_down;

                if(scan_key<16) applied_velocity[scan_key]<=sampled_velocity;

            end else begin scan_key<=scan_key+1'b1;scan_phase<=0;end

        end

    end

    wire source_mix_valid,source_mix_ready,source_mix_done,source_mix_error;

    wire [4:0] source_mix_track;wire [15:0] source_mix_gain,source_drum_gain;

    workstation_track_mix source_mixer(.clk(system_clk),.rst_n(rst_n),.piano_volume(piano_vol_s[6:0]),.midi_volume(midi_volume),.song_gains(player_track_gains),

        .command_valid(source_mix_valid),.command_ready(source_mix_ready),.command_done(source_mix_done),.command_error(source_mix_error),

        .command_owner(source_mix_track),.command_gain(source_mix_gain),.error());

    // 真实资源/播放器已接入；ADSR写当前5位音色，轨道增益作用于持续音与尾音。

    wire [47:0] env_eff={env_r,env_s,env_d,env_a};

    unified_models8_32 #(.DAMPING_ENABLE(1),.VELOCITY_TONE_ENABLE(1)) engine(.velocity_tone_setting(velocity_tone_setting),.damping_settings(damping_settings),.chord_status(chord_status),.clk(system_clk),.rst_n(rst_n),.sample_tick(live_sample_tick),.panic(synth_panic),

        .command_valid(test_active ? test_event_valid:(realtime_valid||player_event_valid)),.command_ready(synth_ready),

        .command_op(test_active ? 2'd1:realtime_valid ? realtime_op:player_event_op),.command_source(test_active ? 2'd3:realtime_valid ? realtime_source:player_event_source),

        .command_track(test_active ? 5'd18:realtime_valid ? (realtime_source==0 ? 5'd16:5'd17):{1'b0,player_track}),

        .command_id(test_active ? test_event_id:realtime_valid ? realtime_id:player_event_id),.command_note(test_active ? test_event_note:realtime_valid ? realtime_note:player_note),

        .command_velocity(test_active ? 7'd100:realtime_valid ? realtime_velocity:player_velocity),.command_timbre(test_active ? test_event_timbre:realtime_valid ? realtime_timbre:player_timbre),.custom_ready(patch_ready_mask),

        .bend(bend),.vibrato_depth(vibrato_depth),.vibrato_rate(vibrato_rate),.table_write(table_write),.table_address(table_address),.table_data(table_data),

        .parameter_write(parameter_write|env_write_pulse),.parameter_bank(env_write_pulse ? live_patch:parameter_bank),.attack_step(env_eff[11:0]),.decay_step(env_eff[23:12]),

        .sustain_level(env_eff[35:24]),.release_step(env_eff[47:36]),.mix_valid(source_mix_valid),.mix_track(source_mix_track),.mix_gain(source_mix_gain),.mix_ready(source_mix_ready),.mix_done(source_mix_done),.mix_error(source_mix_error),.percussion_gain(source_drum_gain),

        .sample_valid(engine_sample_valid),.clipped(synth_clipped),.parameter_error(engine_parameter_error),.command_done(engine_command_done),.command_result(engine_command_result),.pcm(synth_pcm),
        .raw_mix(source_raw),.raw_live(source_live),.raw_song(source_song),.voice_count(voices),.active_mask(voice_mask),.deadline_error(engine_deadline_error),.rendered_voices(rendered_voices),.command_slot(engine_command_slot));

    // 无鼓版本禁用打击乐触发；保留的屏幕步进/BPM/图样兼容字段保持静态。

    assign beat_drums=16'd0;assign beat_running=1'b0;assign beat_bpm=8'd0;assign beat_step=4'd0;

    assign beat_patterns=64'd0;assign beat_sounds=16'd0;

    pcm_source_sends source_sends(.clk(system_clk),.rst_n(rst_n),.clear(synth_panic),.sample_tick(engine_sample_valid),
        .raw_mix(source_raw),.raw_live(source_live),.raw_song(source_song),.live_target(live_fx_target),.song_target(song_fx_target),
        .live_gain(live_fx_gain),.song_gain(song_fx_gain),.pcm(effects_input),.valid(send_valid),.clipped(send_clipped));
    audio_effects #(.SEPARATE_SEND(1)) effects(.clk(system_clk),.rst_n(rst_n),.sample_tick(live_sample_tick),.clear(synth_panic),.dry(dry_pcm),.send_in(effects_input),

        .delay_mix(delay_mix[6:0]),.reverb_mix(reverb_mix[6:0]),.feedback(feedback[6:0]),.delay_samples(delay_time),.wet(effects_pcm),
        .send_chain(effects_send_pcm),.clipped(effects_clipped),.valid(effects_valid),.delay_component(delay_component),.reverb_component(reverb_component));

    audio_chorus #(.SEPARATE_SEND(1)) chorus(.clk(system_clk),.rst_n(rst_n),.clear(synth_panic),.sample_tick(live_sample_tick),.dry(effects_pcm),.send_in(effects_send_pcm),
        .mix(chorus_mix),.depth(chorus_depth),.rate(chorus_rate),.out(chorus_pcm),.clipped(chorus_clipped),.valid(chorus_valid),.wet_component(chorus_component));

    // 耳机增益独立于模型及32声部混音；128帧平滑，饱和事件进入USB诊断。

    pcm_master_gain #(.LIMITER_CAPABLE(1)) master_output(.clk(system_clk),.rst_n(rst_n),.clear(synth_panic),.sample_tick(live_sample_tick),

        .sample_in(chorus_pcm),.boost(master_boost),.sample_out(output_pcm),.clipped(master_clipped),.gain_q8(),
        .limiter_enabled(limiter_enabled),.limiter_release(limiter_release),.limiter_gain(limiter_gain),.limited(master_limited),
        .valid(master_valid),.peak_in(master_peak_in),.peak_out(master_peak_out));
    pcm_gain_stats gain_monitor(.clk(system_clk),.rst_n(rst_n),.clear(gain_stats_clear),.voice_clip(engine_sample_valid&&synth_clipped),
        .fx_clip((send_valid&&send_clipped)||(effects_valid&&effects_clipped)||(chorus_valid&&chorus_clipped)),
        .master_clip(master_clipped),.output_valid(master_valid),.limited(master_limited),.peak_in(master_peak_in),.peak_out(master_peak_out),.snapshot(gain_stats));

    // Publish the previous frame at a fixed boundary. Serial limiting needs up
    // to 34 clocks; the DAC latches only 8/16 clocks after frame_tick. Without
    // this buffer, small and overloaded samples would reach different frames.
    always @(posedge system_clk)begin
        if(!rst_n||synth_panic)output_frame_pcm<=0;
        else if(live_sample_tick)output_frame_pcm<=output_pcm;
    end

    audio_startup #(.STARTUP_CYCLES(STARTUP_CYCLES)) startup(.clk(system_clk),.rst_n(rst_n),.audio_ready(live_audio_ready),.pa_en(live_pa_en));

    generate if(ONBOARD_DAC)begin:g_onboard

        pt8211_48_stereo output_tx(.clk(system_clk),.rst_n(rst_n),.sample_left(dac_left),.sample_right(dac_right),

            .bck(live_hp_bck),.ws(live_hp_ws),.din(live_hp_din),.frame_tick(live_sample_tick));

    end else begin:g_i2s

        i2s48_stereo output_tx(.clk(system_clk),.rst_n(rst_n),.sample_left(dac_left),.sample_right(dac_right),

            .bck(live_hp_bck),.ws(live_hp_ws),.din(live_hp_din),.frame_tick(live_sample_tick));

    end endgenerate

    assign catalog_index=0;

    wire [6:0] scope_available;wire [23:0] scope_pair;wire scope_overflow,scope_pop,scope_clear,scope_capture_enable;
    screen_scope_capture scope_capture(.clk(system_clk),.rst_n(rst_n),.clear(scope_clear),.enable(scope_capture_enable),
        .sample_tick(live_sample_tick),.right_channel(right_channel),.pop(scope_pop),.left(dac_left),.right(dac_right),
        .pair_data(scope_pair),.available(scope_available),.overflow(scope_overflow));
    wire [479:0] screen_telemetry;
    screen_status_mux screen_status(.view(ui_view),.fx_status(demo_fx_status),.audio_status(demo_audio_status),
        .note_status(demo_note_status),.lesson_status(demo_lesson_status),.physical_pitch_map(lesson_pitch_map),
        .physical_down(effective_keys),.enabled_keys(lesson_enabled),.envelope(env_eff),
        .live_patch(live_patch),.screen_patch(screen_patch),.transpose(live_transpose),.bend(bend),
        .vibrato_depth(vibrato_depth),.vibrato_rate(vibrato_rate),.voices(voices),
        .track_timbres(player_track_timbres),.track_volumes(player_track_volumes),.track_mutes(player_track_mutes),.track_solos(player_track_solos),
        .live_volume(piano_volume),.song_volume(midi_volume),.master_boost(master_boost),.limiter_enabled(limiter_enabled),
        .limiter_release(limiter_release),.live_send(live_fx_target),.song_send(song_fx_target),
        .command_feedback(command_feedback),.telemetry(screen_telemetry));
    mega138_screen_tx #(.CLKS_PER_BIT(SCREEN_CLKS_PER_BIT),.STARTUP_CYCLES(SCREEN_STARTUP_CYCLES),.UPDATE_CYCLES(SCREEN_UPDATE_CYCLES),.STREAM_SUPPORT(1),.TELEMETRY_SUPPORT(1)) display(

        .clk(system_clk),.rst_n(rst_n),.view(ui_view),.mode(app_mode),.test_kind(test_kind),.build_id(BUILD_ID),

        .voice_mask(display_voice_mask),.timeout_count(timeout_count),.revision(graph_revision),.voices(display_voices),.peak_voices(peak_voices),

        .keys(effective_keys),.flags({8'd0,3'd0,parameter_error,synth_clipped|master_clipped,deadline_error,calibrated,adc_ready}),

        .pressure(pressure_values),.telemetry(screen_telemetry),.graph_config(graph_config),.result(test_result),.song_status(status_data),.song_ready(selected_ready),.ddr_ready(storage_ready),

        .command_feedback(command_feedback),.peaks(peak_bins),.graph_ready(graph_ready),.lock_granted(graph_lock_granted),

        .graph_data(graph_data),.graph_lock(screen_graph_lock),.graph_address(graph_address),.tx(screen_tx_o),
        .graph_kind(graph_kind),.freeze_graph(freeze_graph),.right_channel(right_channel),
        .scope_command_valid(screen_valid),.scope_command_op(screen_op),.scope_command_value(screen_value),
        .scope_available(scope_available),.scope_pair(scope_pair),.scope_overflow(scope_overflow),
        .scope_pop(scope_pop),.scope_clear(scope_clear),.scope_capture_enable(scope_capture_enable));

    mcp3208_dual_scan #(.HALF_PERIOD(25),.ADC_PRESENT_MASK(ADC_PRESENT_MASK)) adc_spi (

        .clk(system_clk), .rst_n(rst_n),

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

    pressure_key_matrix_serial #(

        .KEY_COUNT(KEY_COUNT), .ADC_BITS(ADC_BITS), .CALIBRATION_SAMPLES(CALIBRATION_SAMPLES),

        .FILTER_SHIFT(2), .PRESS_ON(PRESS_ON), .PRESS_OFF(PRESS_OFF),

        .PRESS_FULL(PRESS_FULL), .ACTIVE_LOW_MASK(ACTIVE_LOW_MASK)

    ) key_matrix (

        .clk(system_clk), .rst_n(rst_n), .adc_ready(adc_ready),

        .sample_frame_valid(sample_frame_valid), .adc_samples(adc_samples),.key_enable(enabled_keys),

        .calibrated(calibrated), .baseline_values(baseline_values),

        .pressure_values(pressure_values), .velocity_values(velocity_values),

        .key_down(key_down), .key_on_pulse(key_on_pulse),

        .key_off_pulse(key_off_pulse), .active_key_count(active_key_count),

        .frame_busy(pressure_frame_busy), .frame_overrun(pressure_frame_overrun)

    );

    always @(*) begin

        if      (max_pressure >= 13'd224) pressure_bar = 7'b111_1111;

        else if (max_pressure >= 13'd144) pressure_bar = 7'b011_1111;

        else if (max_pressure >= 13'd96)  pressure_bar = 7'b001_1111;

        else if (max_pressure >= 13'd64)  pressure_bar = 7'b000_1111;

        else if (max_pressure >= 13'd48)  pressure_bar = 7'b000_0111;

        else if (max_pressure >= 13'd32)  pressure_bar = 7'b000_0011;

        else if (max_pressure >= 13'd16)  pressure_bar = 7'b000_0001;

        else                              pressure_bar = 7'b000_0000;

    end

    always @(posedge system_clk or negedge rst_n) begin

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


    // 声部提交通知与起始接受元数据配对，不能把收到请求当作音高已经生效。
    always @(posedge system_clk)begin
        if(!rst_n||synth_panic)begin accepted_source<=0;accepted_key<=0;accepted_id<=0;accepted_note<=0;end
        else if(synth_ready&&(test_active ? test_event_valid:(realtime_valid||player_event_valid)))begin
            accepted_source<=test_active ? 2'd3:realtime_valid ? realtime_source:player_event_source;
            accepted_key<=realtime_valid&&!test_active ? scan_key:5'd0;
            accepted_id<=test_active ? test_event_id:realtime_valid ? realtime_id:player_event_id;
            accepted_note<=test_active ? test_event_note:realtime_valid ? realtime_note:player_note;
        end
        if(!rst_n||synth_panic)live_offsets<=0;
        else begin
            if(offset_write&&applied[offset_key]&&key_note_ids[offset_key*32+:32]==offset_id)
                live_offsets[offset_key*7+:7]<=offset_value;
            if(!test_active&&realtime_valid&&synth_ready&&realtime_op==1)
                live_offsets[scan_key*7+:7]<=0;
        end
    end
    live_note_pitch pitch_control(.clk(system_clk),.rst_n(rst_n),.clear(synth_panic),
        .request(app_valid&&app_op==48),.requested_offset($signed(app_value)),.pressed((tone_active||test_active)?32'd0:input_keys),
        .event_valid(engine_command_done),.event_op(accepted_engine_op),.event_source(accepted_source),
        .event_key(accepted_key),.event_id(accepted_id),.event_note(accepted_note),.event_result(engine_command_result),.event_slot(engine_command_slot),.active_slots(voice_mask),
        .offset_write(offset_write),.offset_key(offset_key),.offset_id(offset_id),.offset_value(offset_value),
        .done(pitch_done),.result(pitch_result),.status(demo_note_status));
    audio_runtime_metrics runtime_metrics(.clk(system_clk),.rst_n(rst_n),.clear(synth_panic),
        .sample_tick(live_sample_tick),.sample_valid(engine_sample_valid),
        .completed_voices(rendered_voices),.active_voices(voices),.snapshot(demo_audio_status));
    reg [15:0] dry_peak,delay_peak,reverb_peak,chorus_peak;reg [31:0] effect_clip_count;
    function automatic [15:0] abs_pcm(input signed [15:0] x);
        abs_pcm=x[15] ? 16'(-x):x;
    endfunction
    always @(posedge system_clk)begin
        if(!rst_n||synth_panic)begin dry_peak<=0;delay_peak<=0;reverb_peak<=0;chorus_peak<=0;effect_clip_count<=0;end
        else begin
            if(live_sample_tick)begin
                dry_peak<=abs_pcm(dry_pcm)>dry_peak ? abs_pcm(dry_pcm):dry_peak==0 ? 16'd0:dry_peak-1'b1;
                if(delay_peak!=0)delay_peak<=delay_peak-1'b1;
                if(reverb_peak!=0)reverb_peak<=reverb_peak-1'b1;
                if(chorus_peak!=0)chorus_peak<=chorus_peak-1'b1;
            end
            if(effects_valid)begin
                if(abs_pcm(delay_component)>delay_peak)delay_peak<=abs_pcm(delay_component);
                if(abs_pcm(reverb_component)>reverb_peak)reverb_peak<=abs_pcm(reverb_component);
            end
            if(chorus_valid&&abs_pcm(chorus_component)>chorus_peak)chorus_peak<=abs_pcm(chorus_component);
            if((effects_valid&&effects_clipped)||(chorus_valid&&chorus_clipped))effect_clip_count<=effect_clip_count+1'b1;
        end
    end
    assign demo_fx_status={24'd0,graph_config,effect_clip_count,16'd0,limiter_gain,
        16'd0,chorus_peak,16'd0,reverb_peak,16'd0,delay_peak,16'd0,dry_peak,
        16'd0,song_fx_gain,live_fx_gain,29'd0,fx_preview,24'd0,chorus_rate,
        24'd0,chorus_depth,24'd0,feedback,24'd0,chorus_mix,24'd0,reverb_mix,
        24'd0,delay_mix,17'd0,delay_time};


    genvar lesson_k;
    reg signed [6:0] previous_lesson_transpose;reg [1:0] previous_lesson_octave;
    always @(posedge system_clk)begin
        if(!rst_n)begin previous_lesson_transpose<=0;previous_lesson_octave<=0;end
        else begin previous_lesson_transpose<=live_transpose;previous_lesson_octave<=live_octave_shift;end
    end
    wire lesson_tuning_changed=previous_lesson_transpose!=live_transpose||previous_lesson_octave!=live_octave_shift;
    generate for(lesson_k=0;lesson_k<16;lesson_k=lesson_k+1)begin:g_lesson_map
        wire [5:0] mapped_kind=active_map[lesson_k*16+8+:6];
        wire [4:0] actual_kind=mapped_kind==63 ? live_patch:mapped_kind[4:0];
        wire signed [10:0] pitch=11'sd57+
            $signed({3'd0,active_map[lesson_k*16+:8]})+$signed(live_transpose)+
            (live_octave_shift==1 ? 11'sd12:live_octave_shift==2 ? -11'sd12:11'sd0);
        assign lesson_pitch_map[lesson_k*7+:7]=pitch<0 ? 7'd0:pitch>127 ? 7'd127:pitch[6:0];
        assign lesson_enabled[lesson_k]=enabled_keys[lesson_k]&&active_map[lesson_k*16+14+:2]==0&&
            (actual_kind==10||actual_kind==19||actual_kind==20);
    end endgenerate
    pressure_lesson lesson(.clk(system_clk),.rst_n(rst_n),
        .clear(synth_panic||map_changed||mask_changed||builtin_changed||lesson_tuning_changed||validation_start||validation_release),
        .request(lesson_request&&!lesson_invalid),.action(app_value[2:0]),.selected_track(app_aux[3:0]),
        .source_available(selected_ready),.source_quiet(lesson_quiet),.parser_ready(lesson_parsed),
        .parser_busy(midi_parser_busy),.parser_error(parser_error),.event_count(lesson_event_count),
        .event_start(lesson_event_start),.event_end(lesson_event_end),.event_note(lesson_event_note),.event_track(lesson_event_track),
        .physical_pitch_map(lesson_pitch_map),.enabled_keys(lesson_enabled),.transpose(live_transpose),
        .physical_down(effective_keys),.screen_down(accepted_screen_keys),.accepted_valid(engine_command_done&&!tone_active&&!test_active),.accepted_op(accepted_engine_op),
        .accepted_source(accepted_source),.accepted_key(accepted_key),.accepted_id(accepted_id),
        .accepted_note(accepted_note),.accepted_result(engine_command_result),.prepare_parser(lesson_prepare),
        .reader_enable(lesson_reader_enable),.reader_index(lesson_reader_index),.done(lesson_done),.result(lesson_result),
        .active(lesson_active),.guide_keys(lesson_guide),.status(demo_lesson_status));

endmodule

`default_nettype wire

