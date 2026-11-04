`timescale 1ns/1ps
`default_nettype none
// 统一32声部引擎：钢琴10、吉他19与Bass20共享32槽身份及调度；本版不启用鼓。
// 各音色按活动掩码复用共享模态后端，声部总数始终为32，不能相加统计。
// 兼容旧工作站命令0释音/1起音/3连续更新；新模型原生包络默认开启。
module unified_models8_32 #(parameter integer DAMPING_ENABLE=0,parameter integer VELOCITY_TONE_ENABLE=0)(
    input wire clk,rst_n,sample_tick,panic,
    input wire [95:0] damping_settings,
    input wire [1:0] velocity_tone_setting,
    input wire command_valid,output wire command_ready,
    input wire [1:0] command_op,command_source,input wire [31:0] command_id,
    input wire [4:0] command_track,
    input wire [6:0] command_note,command_velocity,input wire [4:0] command_timbre,
    input wire [7:0] custom_ready,input wire signed [13:0] bend,
    input wire [7:0] vibrato_depth,vibrato_rate,
    input wire table_write,input wire [10:0] table_address,input wire signed [15:0] table_data,
    input wire parameter_write,input wire [4:0] parameter_bank,
    input wire [11:0] attack_step,decay_step,sustain_level,release_step,
    input wire mix_valid,input wire [4:0] mix_track,input wire [15:0] mix_gain,
    output wire mix_ready,mix_done,mix_error,output wire [15:0] percussion_gain,
    output wire signed [15:0] pcm,output wire signed [22:0] raw_mix,raw_live,raw_song,output wire [5:0] voice_count,
    output wire [31:0] active_mask,output wire deadline_error,output wire [5:0] rendered_voices,
    output wire [4:0] command_slot,
    output wire [63:0] chord_status,
    output wire sample_valid,clipped,parameter_error,output reg command_done,output reg [2:0] command_result
);
    // Isolate the DAC fractional-divider decode from gain/LFO/frame enables.
    // One local clock of scheduling latency, with no change to sample cadence.
    (* syn_preserve=1 *) reg sample_tick_local;
    always @(posedge clk)begin
        if(!rst_n||panic)sample_tick_local<=0;else sample_tick_local<=sample_tick;
    end
    wire shared_busy,shared_valid,shared_error,shared_parameter_error,shared_alignment_error,shared_failed;
    wire mixed_valid;wire signed [15:0] mixed_pcm;
    wire signed [22:0] mixed_raw,mixed_live,mixed_song;
    // 每种内置模型各自保存ADSR；参数在新起音时由统一控制器复制到该声部。
    reg [47:0] model_parameters[0:2];reg [2:0] model_adsr_enabled;integer bank_index;
    always @(posedge clk)begin
        if(!rst_n)begin
            model_adsr_enabled<=0;
            for(bank_index=0;bank_index<3;bank_index=bank_index+1)model_parameters[bank_index]<={12'd32,12'd3072,12'd8,12'd64};
        end else if(parameter_write&&(parameter_bank==10||parameter_bank==19||parameter_bank==20))begin
            model_parameters[parameter_bank==10 ? 0:parameter_bank==19 ? 1:2]<={release_step==0 ? 12'd1:release_step,sustain_level,
                decay_step==0 ? 12'd1:decay_step,attack_step==0 ? 12'd1:attack_step};
            model_adsr_enabled[parameter_bank==10 ? 0:parameter_bank==19 ? 1:2]<=1;
        end
    end
    wire gain_initialized,gain_frame,gain_deadline;wire [4:0] gain_owner;wire [15:0] track_gain;
    track_gain_bank_packed #(.OWNERS(19)) gains(.clk(clk),.rst_n(rst_n),.sample_tick(sample_tick_local&&gain_initialized),
        .command_valid(mix_valid),.command_ready(mix_ready),.command_owner(mix_track),.command_gain(mix_gain),
        .command_done(mix_done),.command_error(mix_error),.read_owner(gain_owner),.read_gain(track_gain),
        .initialized(gain_initialized),.frame_done(gain_frame),.deadline_error(gain_deadline),.percussion_gain(percussion_gain));
    reg [2:0] event_state;reg update_pressure;reg [15:0] saved_key;reg [31:0] saved_id;reg [6:0] saved_pressure;
    wire ctl_ready,ctl_ack,control_envelope_busy;wire [2:0] ctl_result;wire [31:0] active,held,modal;
    wire [511:0] generations;wire [223:0] notes,velocities,pressures;
    wire [159:0] banks,tracks;wire [159:0] timbres;wire [1023:0] ratios;wire [479:0] envelopes;
    wire [31:0] finished,piano_finished,tom_finished,exc_finished;wire [511:0] finished_generation,piano_finished_generation,tom_finished_generation,exc_finished_generation;
    wire input_accept=command_valid&&command_ready;
    assign command_ready=event_state==0&&ctl_ready&&rst_n&&!panic;
    wire valid_patch=(command_timbre==10||command_timbre==19||command_timbre==20);
    wire [1:0] selected_bank=command_timbre==19 ? 2'd1:command_timbre==20 ? 2'd2:2'd0;
    wire [47:0] selected_parameters=model_parameters[selected_bank];
    wire [2:0] input_op=command_op==1 ? 3'd0:command_op==0 ? 3'd1:command_op==3 ? 3'd4:3'd7;
    model_voice_control_models8_32 #(.TIMBRE_ROUTING(1)) control(.clk(clk),.rst_n(rst_n),.sample_tick(gain_frame),.panic(panic),
        .test_mode(command_source==3),.event_valid(input_accept||event_state==2),.event_ready(ctl_ready),
        .event_op(event_state==2 ? 3'd2:input_op),.event_realtime(command_source<2),
        .event_key(event_state==2 ? saved_key:{14'd0,command_source}),.event_id(event_state==2 ? saved_id:command_id),
        .event_note(command_note),.event_velocity(command_velocity),.event_pressure(event_state==2 ? saved_pressure:command_velocity),
        .event_track(command_track),.event_ratio(32'h10000000),.event_timbre(valid_patch ? command_timbre:5'd31),
        .adsr_enable(model_adsr_enabled[selected_bank]),.attack_step({selected_parameters[11:0],3'd0}),
        .decay_step({selected_parameters[23:12],3'd0}),.sustain_level({selected_parameters[35:24],3'd0}),
        .release_step({selected_parameters[47:36],3'd0}),.finished(finished),.finished_generation(finished_generation),
        .event_ack(ctl_ack),.event_result(ctl_result),.event_slot(command_slot),.active(active),.held(held),.generation(generations),
        .notes(notes),.velocities(velocities),.pressures(pressures),.banks(banks),.tracks(tracks),.timbres(timbres),.modal_mask(modal),
        .ratios(ratios),.envelopes(envelopes),.active_count(voice_count),.stolen_count(),.env_busy(control_envelope_busy));
    always @(posedge clk)begin
        if(!rst_n||panic)begin event_state<=0;update_pressure<=0;saved_key<=0;saved_id<=0;saved_pressure<=0;command_done<=0;command_result<=0;end
        else begin
            command_done<=0;
            case(event_state)
                0:if(input_accept)begin event_state<=1;update_pressure<=command_op==3;saved_key<={14'd0,command_source};
                    saved_id<=command_id;saved_pressure<=command_velocity;end
                1:if(ctl_ack)begin
                    if(update_pressure&&ctl_result==0)event_state<=2;
                    else begin event_state<=0;command_done<=1;command_result<=ctl_result;end
                end
                2:if(ctl_ready)event_state<=3;
                3:if(ctl_ack)begin event_state<=0;command_done<=1;command_result<=ctl_result;end
                default:event_state<=0;
            endcase
        end
    end
    // 全局弯音和三角颤音在帧边界锁存，逐槽乘法，避免展开32个宽乘法器。
    reg [31:0] lfo;wire [31:0] bend_factor;
    wire [7:0] magnitude=lfo[30] ? ~lfo[29:22]:lfo[29:22];
    wire signed [8:0] triangle=lfo[31] ? -$signed({1'b0,magnitude}):$signed({1'b0,magnitude});
    wire signed [17:0] vibrato_product=triangle*$signed({1'b0,vibrato_depth});
    wire signed [15:0] total_bend=16'($signed(bend))+16'($signed(vibrato_product)>>>4);
    wire [10:0] factor_address=total_bend < -8192 ? 0:total_bend>8192 ? 1024:11'(($signed(total_bend)+8192)>>>4);
    (* syn_maxfan=64 *) reg start_frame;
    reg [10:0] factor_address_q;
    reg factor_capture_q;
    always @(posedge clk)begin
        factor_address_q<=factor_address;
        if(!rst_n||panic)factor_capture_q<=0;else factor_capture_q<=start_frame;
    end
    bend_factor_rom factor_rom(.clk(clk),.address(factor_address_q),.data(bend_factor));
    reg render_start,mod_busy;reg [4:0] mod_slot;reg [1:0] mod_state;
    reg [95:0] frame_damping;
    reg [767:0] voice_damping;
    reg [1:0] frame_velocity_tone;reg [63:0] voice_velocity_tone;
    reg [31:0] frame_active,frame_held,frame_modal,frame_factor;
    workstation_voice_count rendered_count(.mask(frame_active),.count(rendered_voices));
    reg [511:0] frame_generations;reg [223:0] frame_notes,frame_velocities,frame_pressure;
    reg [159:0] frame_banks,frame_tracks;reg [159:0] frame_timbres;reg [479:0] frame_envelopes;
    reg [63:0] ratio_product;
    // 帧比例快照改 32×32 RAM：start_frame 后 32 拍逐槽采集，调制循环再逐槽读。
    reg [31:0] ratio_ram[0:31];
    reg [4:0] cap_slot;reg cap_busy;
    // 每帧调制结果放 RAM：写口来自调制循环，读口由钢琴给出的槽号驱动。
    reg [31:0] mod_ram[0:31];reg [31:0] pitch_word;wire [4:0] pitch_addr;
    reg [511:0] tom_pitch;reg [15:0] frame_drum_gain;wire [31:0] mod_value=32'(ratio_product>>28);
    always @(posedge clk) pitch_word<=mod_ram[pitch_addr];
    reg frame_open,frame_deadline;
    reg [7:0] gain_wait;reg gain_waiting,gain_arrived;
    reg envelope_pending,frame_envelope_ready;
    always @(posedge clk)begin
        if(!rst_n||panic)begin
            lfo<=0;start_frame<=0;render_start<=0;mod_busy<=0;mod_slot<=0;mod_state<=0;ratio_product<=0;
            
            
            frame_open<=0;frame_deadline<=0;cap_busy<=0;cap_slot<=0;
            gain_wait<=0;gain_waiting<=0;gain_arrived<=0;envelope_pending<=0;frame_envelope_ready<=0;
        end else begin
            start_frame<=0;render_start<=0;
            if(gain_frame)gain_arrived<=1;
            // 16 gain owners need32 scan cycles plus a bounded in-flight command.
            // Start at a fixed48-cycle boundary; ADSR RAM scanning overlaps rendering.
            if(gain_waiting)begin
                if(gain_wait==0)begin
                    gain_waiting<=0;start_frame<=1;
                    if(!gain_arrived&&!gain_frame)frame_deadline<=1;
                end else gain_wait<=gain_wait-1'b1;
            end
            if(sample_tick_local&&gain_initialized)begin
                lfo<=lfo+32'(vibrato_rate*32'd89478);
                if(frame_open)frame_deadline<=1;frame_open<=1;
                gain_wait<=47;gain_waiting<=1;gain_arrived<=0;frame_envelope_ready<=0;
            end
            if(start_frame)begin
                envelope_pending<=1;
                
                
                
                cap_busy<=1;cap_slot<=0;
            end
            // Ownership transactions are frozen throughout env_busy. Identity is
            // captured before it ends; latch levels at completion, before the
            // next owner commit can replace a voice. Mixer waits for this latch.
            if(envelope_pending&&!control_envelope_busy)begin
                frame_envelopes<=envelopes;envelope_pending<=0;frame_envelope_ready<=1;
            end
            if(cap_busy)begin
                ratio_ram[cap_slot]<=ratios[cap_slot*32+:32];
                if(cap_slot==31)begin cap_busy<=0;mod_busy<=1;mod_slot<=0;mod_state<=0;end
                else cap_slot<=cap_slot+1'b1;
            end
            if(mod_busy)case(mod_state)
                0:begin ratio_product<=ratio_ram[mod_slot]*frame_factor;mod_state<=1;end
                1:begin
                    mod_ram[mod_slot]<=mod_value;
                    tom_pitch[mod_slot*16+:16]<=mod_value<32'd8192||mod_value>=32'h20000000 ? 16'd0:mod_value[28:13];
                    if(mod_slot==31)begin mod_busy<=0;render_start<=1;end else begin mod_slot<=mod_slot+1'b1;mod_state<=0;end
                end
                default:mod_busy<=0;
            endcase
            if(sample_valid||shared_failed)frame_open<=0;
        end
    end
    // 每个槽的比例和属性在同一拍采集，避免32拍读取比例时混入另一代音符。
    // 32槽全部采完才render_start；当前渲染结束前不改动这份快照。
    always @(posedge clk)begin
        if(start_frame)begin
            frame_drum_gain<=percussion_gain;
            frame_damping<=damping_settings;
            frame_velocity_tone<=velocity_tone_setting;
        end
        // ROM地址新增一级，系数快照随之晚一拍；仍采原来的弯音时刻，早于逐槽乘法。
        if(factor_capture_q)frame_factor<=bend_factor;
    end
    genvar capture_index;
    generate for(capture_index=0;capture_index<32;capture_index=capture_index+1)begin:g_capture
        reg damping_valid;
        always @(posedge clk)begin
            if(!rst_n||panic)damping_valid<=0;
            else if(cap_busy&&cap_slot==capture_index)begin
                damping_valid<=active[capture_index];
                if(active[capture_index]&&(!damping_valid || frame_generations[capture_index*16+:16]!=generations[capture_index*16+:16]))begin
                    voice_damping[capture_index*24+:24]<=timbres[capture_index*5+:5]==10 ? frame_damping[23:0]:
                        timbres[capture_index*5+:5]==20 ? frame_damping[87:64]:frame_damping[55:32];
                    voice_velocity_tone[capture_index*2+:2]<=timbres[capture_index*5+:5]==10 ? frame_velocity_tone:2'd0;
                end
            end
        end
        always @(posedge clk)if(cap_busy && cap_slot==capture_index)begin
            frame_active[capture_index]<=active[capture_index];
            frame_held[capture_index]<=held[capture_index];
            frame_modal[capture_index]<=modal[capture_index];
            frame_generations[capture_index*16+:16]<=generations[capture_index*16+:16];
            frame_notes[capture_index*7+:7]<=notes[capture_index*7+:7];
            frame_velocities[capture_index*7+:7]<=velocities[capture_index*7+:7];
            frame_pressure[capture_index*7+:7]<=pressures[capture_index*7+:7];
            frame_banks[capture_index*5+:5]<=banks[capture_index*5+:5];
            frame_tracks[capture_index*5+:5]<=tracks[capture_index*5+:5];
            frame_timbres[capture_index*5+:5]<=timbres[capture_index*5+:5];
        end
    end endgenerate
    workstation_chord chord(.clk(clk),.rst_n(rst_n),.panic(panic),.start(render_start),
        .active(frame_active),.held(frame_held),.notes(frame_notes),.tracks(frame_tracks),
        .result(chord_status),.busy());
    wire piano_valid,tom_valid,exc_valid,piano_error,tom_error,exc_error,post_error,transition_error;
    wire [511:0] piano_pcm,tom_pcm,exc_pcm,merged_pcm,transition_pcm;
    reg [2:0] backend_done;reg transition_requested;
    wire transition_start=(&(backend_done|{exc_valid,tom_valid,piano_valid}))&&frame_envelope_ready&&!transition_requested&&!shared_failed;
    wire transition_valid;
    always @(posedge clk)begin
        if(!rst_n||panic||render_start||shared_failed)begin backend_done<=0;transition_requested<=0;end
        else begin
            backend_done<=backend_done|{exc_valid,tom_valid,piano_valid};
            if(transition_start)transition_requested<=1;
        end
    end
    // 模型原始力度只在输出端做整数增益：持续压力更新同一增益，初始力度另存。
    // 后级保持单位压力，禁止再乘一次压力造成轻按平方衰减；相位和原生包络均不重启。
    wire [31:0] tom_mask,exc_mask,drum_mask;
    wire [223:0] tom_indices,exc_indices;wire tom_parameter_error,exc_parameter_error;
    genvar type_slot;generate for(type_slot=0;type_slot<32;type_slot=type_slot+1)begin:g_type
        wire [4:0] kind=frame_timbres[type_slot*5+:5];
        assign tom_mask[type_slot]=frame_active[type_slot]&&(kind==11||kind==12);
        assign exc_mask[type_slot]=frame_active[type_slot]&&kind>=13&&kind<=18;
        assign drum_mask[type_slot]=tom_mask[type_slot]||exc_mask[type_slot];
        assign tom_indices[type_slot*7+:7]=kind==12 ? 7'd2:7'd1;
        assign exc_indices[type_slot*7+:7]=kind==13 ? 7'd0:7'(kind-5'd11);
        assign finished[type_slot]=piano_finished[type_slot]||tom_finished[type_slot]||exc_finished[type_slot];
        assign finished_generation[type_slot*16+:16]=frame_modal[type_slot] ? piano_finished_generation[type_slot*16+:16]:
            tom_mask[type_slot] ? tom_finished_generation[type_slot*16+:16]:exc_finished_generation[type_slot*16+:16];
    end endgenerate
    shared_models8_render32 #(.COMPACT_SCHEDULER(1),.REGISTER_INPUTS(0),.DAMPING_ENABLE(DAMPING_ENABLE),.VELOCITY_TONE_ENABLE(VELOCITY_TONE_ENABLE)) render(
        .clk(clk),.rst_n(rst_n),.sample_tick(render_start),.panic(panic),
        .damping_settings(voice_damping),.active(frame_active),.held(frame_held),.generation(frame_generations),
        .velocity_tone_profiles(voice_velocity_tone),.velocities(frame_velocities),
        .timbres(frame_timbres),.pressures(frame_pressure),.piano_banks(frame_banks),
        .piano_pitch_word(pitch_word),.piano_pitch_addr(pitch_addr),.drum_pitch_ratios(tom_pitch),
        .busy(shared_busy),.sample_valid(shared_valid),.deadline_error(shared_error),
        .parameter_error(shared_parameter_error),.alignment_error(shared_alignment_error),
        .frame_failed(shared_failed),
        .piano_valid(piano_valid),.tom_valid(tom_valid),.exc_valid(exc_valid),
        .piano_pcm(piano_pcm),.tom_pcm(tom_pcm),.exc_pcm(exc_pcm),
        .piano_finished(piano_finished),.tom_finished(tom_finished),.exc_finished(exc_finished),
        .piano_finished_generation(piano_finished_generation),.tom_finished_generation(tom_finished_generation),
        .exc_finished_generation(exc_finished_generation),.frame_cycles(),.max_frame_cycles());
    assign piano_error=shared_error;
    assign tom_error=1'b0;
    assign exc_error=1'b0;
    // 外部诊断字段不变：内部事务/所有权不一致归入参数错误，不能伪装为采样超时。
    assign tom_parameter_error=shared_parameter_error|shared_alignment_error;
    assign exc_parameter_error=1'b0;
    genvar g;generate for(g=0;g<32;g=g+1)begin:voice_selection
        assign merged_pcm[g*16+:16]=frame_modal[g] ? piano_pcm[g*16+:16]:tom_mask[g] ? tom_pcm[g*16+:16]:exc_mask[g] ? exc_pcm[g*16+:16]:16'd0;
    end endgenerate
    // 统一跨模型64采样过渡只做一次；钢琴候选已关闭自己的重复去爆音。
    voice_transition32 #(.REGISTER_INPUTS(0)) transition(.clk(clk),.rst_n(rst_n),.panic(panic||shared_failed),.start(transition_start),
        .active32(frame_active),.generation512(frame_generations),.timbres160(frame_timbres),.voice_pcm512(merged_pcm),
        .busy(),.valid(transition_valid),.deadline_error(transition_error),.pcm_out512(transition_pcm));
    voice_postmix_models8_32 #(.REGISTER_INPUTS(0)) mixer(.clk(clk),.rst_n(rst_n),.panic(panic||shared_failed),.start(transition_valid),.voice_pcm(transition_pcm),.percussion_mask(drum_mask),.percussion_gain(frame_drum_gain),.envelopes(frame_envelopes),
        .pressures({32{7'd127}}),.tracks(frame_tracks),.gain_owner(gain_owner),.track_gain(track_gain),.busy(),.valid(mixed_valid),
        .clipped(clipped),.deadline_error(post_error),.pcm(mixed_pcm),.raw_mix(mixed_raw),.raw_live(mixed_live),.raw_song(mixed_song),.voice_scaled());
    reg failed_output;
    always @(posedge clk)begin
        if(!rst_n||panic)failed_output<=0;
        else if(shared_failed)failed_output<=1;
        else if(mixed_valid)failed_output<=0;
    end
    assign pcm=(shared_failed||(failed_output&&!mixed_valid)) ? 16'sd0:mixed_pcm;
    assign raw_mix=(shared_failed||(failed_output&&!mixed_valid)) ? 23'sd0:mixed_raw;
    assign raw_live=(shared_failed||(failed_output&&!mixed_valid)) ? 23'sd0:mixed_live;
    assign raw_song=(shared_failed||(failed_output&&!mixed_valid)) ? 23'sd0:mixed_song;
    assign sample_valid=mixed_valid||shared_failed;
    assign active_mask=active;
    assign deadline_error=gain_deadline|piano_error|tom_error|exc_error|transition_error|post_error|frame_deadline;
    // 音高比越界与计算超时分别报告，不能把非法参数计成采样超时。
    assign parameter_error=tom_parameter_error|exc_parameter_error;
endmodule
`default_nettype wire
