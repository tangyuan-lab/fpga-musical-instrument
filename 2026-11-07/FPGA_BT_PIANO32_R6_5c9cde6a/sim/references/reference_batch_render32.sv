`timescale 1ns/1ps
`default_nettype none
// 三类模型实际渲染：一个四lane共享模态后端、独立Tom噪声、原Exc片段/噪声/FIR与48k调度。
// 输入在接受沿冻结。钢琴比例由父层同步RAM单口提供，本层不展开1024位比例快照。
// 这里只输出各模型原生PCM；跨模型过渡、ADSR及混音由父层各做一次。
module reference_batch_render32 #(parameter integer COMPACT_SCHEDULER=1,parameter integer REGISTER_INPUTS=1,parameter integer DAMPING_ENABLE=0,parameter integer VELOCITY_TONE_ENABLE=0)(
    input wire clk,rst_n,sample_tick,panic,
    input wire [31:0] active,held,
    input wire [767:0] damping_settings,
    input wire [63:0] velocity_tone_profiles,
    input wire [223:0] velocities,
    input wire [511:0] generation,
    input wire [159:0] timbres,piano_banks,
    input wire [223:0] pressures,
    input wire [31:0] piano_pitch_word,
    output wire [4:0] piano_pitch_addr,
    input wire [511:0] drum_pitch_ratios,
    output reg busy,sample_valid,deadline_error,parameter_error,alignment_error,
    output reg frame_failed,
    output reg piano_valid,tom_valid,
    output wire exc_valid,
    output reg [511:0] piano_pcm,tom_pcm,
    output wire [511:0] exc_pcm,
    output reg [31:0] piano_finished,tom_finished,
    output wire [31:0] exc_finished,
    output reg [511:0] piano_finished_generation,tom_finished_generation,
    output wire [511:0] exc_finished_generation,
    output reg [10:0] frame_cycles,max_frame_cycles
);
    wire [767:0] frame_damping;
    wire [63:0] frame_tone_profiles;wire [223:0] frame_velocities;

    wire [31:0] frame_active;
    wire [31:0] frame_held;
    wire [511:0] frame_generation;
    wire [511:0] frame_drum_pitch;
    wire [159:0] frame_timbres;
    wire [159:0] frame_banks;
    wire [223:0] frame_pressure;
    reg [511:0] piano_work,tom_work;
    reg [31:0] piano_finished_work,tom_finished_work;
    wire [31:0] input_exc_mask,piano_mask,tom_mask;
    wire [223:0] input_exc_indices,tom_indices;
    wire [63:0] modal_kinds;
    wire [31:0] modal_start_active;
    wire [223:0] modal_start_drums;
    wire accept=sample_tick&&!busy;
    generate if(REGISTER_INPUTS!=0)begin:g_damping_snapshot
        reg [767:0] data;
        reg [63:0] tone;reg [223:0] initial_velocity;
        assign frame_damping=data;
        assign frame_tone_profiles=tone;assign frame_velocities=initial_velocity;
        always @(posedge clk)if(rst_n&&!panic&&accept)begin data<=damping_settings;tone<=velocity_tone_profiles;initial_velocity<=velocities;end
    end else begin:g_damping_parent
        assign frame_damping=damping_settings;
        assign frame_tone_profiles=velocity_tone_profiles;assign frame_velocities=velocities;
    end endgenerate

    // REGISTER_INPUTS=0由父层保证accept前至busy结束数据稳定；仿真检查同一份接口契约。
    // 数据快照无整体复位。上电/清音后只有新accept产生有效任务，所有权逻辑仍有同步复位。
    generate if(REGISTER_INPUTS!=0)begin:g_private_snapshot
        reg [31:0] q_frame_active;assign frame_active=q_frame_active;
        reg [31:0] q_frame_held;assign frame_held=q_frame_held;
        reg [511:0] q_frame_generation;assign frame_generation=q_frame_generation;
        reg [511:0] q_frame_drum_pitch;assign frame_drum_pitch=q_frame_drum_pitch;
        reg [159:0] q_frame_timbres;assign frame_timbres=q_frame_timbres;
        reg [159:0] q_frame_banks;assign frame_banks=q_frame_banks;
        reg [223:0] q_frame_pressure;assign frame_pressure=q_frame_pressure;
        always @(posedge clk)if(rst_n&&!panic&&accept)begin
            q_frame_active<=active;
            q_frame_held<=held;
            q_frame_generation<=generation;
            q_frame_drum_pitch<=drum_pitch_ratios;
            q_frame_timbres<=timbres;
            q_frame_banks<=piano_banks;
            q_frame_pressure<=pressures;
        end
    end else begin:g_parent_snapshot
        assign frame_active=active;
        assign frame_held=held;
        assign frame_generation=generation;
        assign frame_drum_pitch=drum_pitch_ratios;
        assign frame_timbres=timbres;
        assign frame_banks=piano_banks;
        assign frame_pressure=pressures;
        // synthesis translate_off
        reg [1631:0] checked_frame;
        reg [287:0] checked_tone;
        always @(posedge clk)if(rst_n&&!panic)begin
            if(accept)checked_frame<={active,held,generation,drum_pitch_ratios,timbres,piano_banks,pressures};
            else if(busy&&checked_frame!=={active,held,generation,drum_pitch_ratios,timbres,piano_banks,pressures})$fatal(1,"shared_models8_render32 parent snapshot changed while busy");
            if(accept)checked_tone<={velocity_tone_profiles,velocities};
            else if(VELOCITY_TONE_ENABLE&&busy&&checked_tone!=={velocity_tone_profiles,velocities})$fatal(1,"renderer velocity-tone snapshot changed while busy");
        end
        // synthesis translate_on
    end endgenerate

    wire watchdog=busy&&frame_cycles>=599;
    wire cancel=panic||watchdog;
    wire modal_start,modal_busy,modal_done,modal_late,modal_bad,modal_alignment;
    wire [31:0] exc_modal_active,exc_modal_step;
    wire [511:0] exc_modal_generation,exc_modal_pitch;
    wire [223:0] exc_modal_drums;
    wire [543:0] exc_modal_ages,modal_ages;
    wire modal_raw_valid,modal_raw_quiet;
    wire [15:0] modal_raw_quiet_bound;
    reg [31:0] plucked_owned;
    reg [15:0] plucked_generation[0:31];
    reg [9:0] plucked_release[0:31];
    reg [17:0] release_age[0:31];
    reg [1:0] quiet_frames[0:31];
    wire [31:0] enhanced;
    genvar d;
    generate for(d=0;d<32;d=d+1)begin:g_damping
        wire [23:0] cfg=frame_damping[d*24+:24];
        assign enhanced[d]=DAMPING_ENABLE && cfg[23:22]!=0;
    end endgenerate
    wire [4:0] modal_raw_slot;
    wire [1:0] modal_raw_kind;
    wire [15:0] modal_raw_generation;
    wire signed [63:0] modal_raw_sum;
    wire exc_busy,exc_late,exc_bad;
    wire noise_busy,noise_done,noise_late,noise_bad,noise_valid,noise_voice_quiet;
    wire [4:0] noise_slot;
    wire [15:0] noise_generation;
    wire signed [55:0] noise_sum;
    // 代号/模型/活动身份均匹配才消费返回；报错本身不能阻止旧结果污染新PCM。
    wire [31:0] raw_slot_identity;
    wire raw_identity_ok=|raw_slot_identity;
    // synthesis translate_off
    wire raw_identity_indexed_reference=modal_raw_generation==frame_generation[modal_raw_slot*16+:16]&&
        modal_raw_kind==modal_kinds[modal_raw_slot*2+:2]&&frame_active[modal_raw_slot];
    always @(posedge clk)if(rst_n&&!cancel&&modal_raw_valid&&busy)
        if(raw_identity_ok!==raw_identity_indexed_reference)$fatal(1,"distributed raw identity differs from indexed reference");
    // synthesis translate_on
    wire accepted_raw=modal_raw_valid&&busy&&!cancel&&raw_identity_ok;
    genvar quiet_slot;
    generate for(quiet_slot=0;quiet_slot<32;quiet_slot=quiet_slot+1)begin:g_quiet_confirm
        wire clear_frame=accept&&(!active[quiet_slot]||!plucked_owned[quiet_slot]||
            plucked_generation[quiet_slot]!=generation[quiet_slot*16+:16]);
        // Compare each constant slot locally. Routing a 32:1 generation/kind mux
        // back into all 32 quiet counters creates an avoidable serial path.
        (* syn_keep=1 *) wire local_identity_ok=modal_raw_generation==frame_generation[quiet_slot*16+:16]&&
            modal_raw_kind==modal_kinds[quiet_slot*2+:2]&&frame_active[quiet_slot];
        assign raw_slot_identity[quiet_slot]=local_identity_ok&&modal_raw_slot==quiet_slot;
        wire observe=modal_raw_valid&&busy&&!cancel&&local_identity_ok&&enhanced[quiet_slot]&&modal_raw_slot==quiet_slot;
        // synthesis translate_off
        always @(posedge clk)if(rst_n&&!panic&&modal_raw_valid&&busy&&!cancel)
            if(observe!==(accepted_raw&&enhanced[quiet_slot]&&modal_raw_slot==quiet_slot))$fatal(1,"local quiet identity differs from indexed reference");
        // synthesis translate_on
        (* syn_keep=1 *) wire update_enable=!rst_n||panic||clear_frame||observe;
        always @(posedge clk)if(update_enable)begin
            if(!rst_n||panic)quiet_frames[quiet_slot]<=0;
            else if(observe)begin
                if(!frame_held[quiet_slot]&&modal_ages[quiet_slot*17+:17]>16&&modal_raw_quiet_bound<32768)begin
                    if(quiet_frames[quiet_slot]!=3)quiet_frames[quiet_slot]<=quiet_frames[quiet_slot]+1'b1;
                end else quiet_frames[quiet_slot]<=0;
            end else quiet_frames[quiet_slot]<=0;
        end
    end endgenerate
    wire noise_identity_ok=noise_generation==frame_generation[noise_slot*16+:16];
    wire accepted_noise=noise_valid&&busy&&!cancel&&noise_identity_ok&&tom_mask[noise_slot];
    reg signed [55:0] noise_cache[0:31];
    reg [31:0] noise_ready,noise_quiet;
    genvar g;
    generate for(g=0;g<32;g=g+1)begin:g_type
        wire [4:0] input_timbre=timbres[g*5+:5];
        wire [4:0] timbre=frame_timbres[g*5+:5];
        assign input_exc_mask[g]=active[g]&&input_timbre>=13&&input_timbre<=18;
        assign input_exc_indices[g*7+:7]=input_timbre==13 ? 7'd0:7'(input_timbre-5'd11);
        assign piano_mask[g]=frame_active[g]&&(timbre==10||timbre==19||timbre==20);
        assign tom_mask[g]=1'b0;
        assign tom_indices[g*7+:7]=timbre==12 ? 7'd2:7'd1;
        assign modal_kinds[g*2+:2]=(timbre==19||timbre==20) ? 2'd3:2'd0;
        assign modal_start_active[g]=piano_mask[g]||tom_mask[g]||exc_modal_active[g];
        assign modal_start_drums[g*7+:7]=tom_mask[g] ? tom_indices[g*7+:7]:exc_modal_drums[g*7+:7];
    end endgenerate
    // 无鼓版本只启动真实共享模态后端；原激励/噪声/片段/FIR不实例化。
    reg modal_tick;
    always @(posedge clk)begin
        if(!rst_n||cancel)modal_tick<=0;
        else modal_tick<=accept;
    end
    assign modal_start=modal_tick;
    assign exc_modal_active=0; assign exc_modal_step=0;
    assign exc_modal_drums=0; assign exc_modal_generation=0;
    assign exc_modal_pitch=0; assign exc_modal_ages=0;
    assign exc_busy=0; assign exc_late=0; assign exc_bad=0;
    assign exc_pcm=0; assign exc_finished=0; assign exc_finished_generation=0;
    assign exc_valid=piano_valid;
    shared_modal_backend32 #(.COMPACT_SCHEDULER(COMPACT_SCHEDULER),.EXTERNAL_PITCH(1),.REGISTER_INPUTS(REGISTER_INPUTS),.DAMPING_ENABLE(DAMPING_ENABLE),.VELOCITY_TONE_ENABLE(VELOCITY_TONE_ENABLE)) modal(
        .clk(clk),.rst_n(rst_n),.sample_tick(modal_start),.panic(cancel),.damping_settings(frame_damping),.active(modal_start_active),.held(frame_held),
        .velocity_tone_profiles(frame_tone_profiles),.velocities(frame_velocities),
        .kinds(modal_kinds),.generation(frame_generation),.piano_banks(frame_banks),.piano_pitches(1024'd0),
        .piano_pitch_addr(piano_pitch_addr),.piano_pitch_word(piano_pitch_word),
        .drum_indices(modal_start_drums),.drum_pitches(frame_drum_pitch),.advance_exc_mask(exc_modal_step),
        .busy(modal_busy),.sample_valid(modal_done),.deadline_error(modal_late),.parameter_error(modal_bad),.alignment_error(modal_alignment),
        .raw_valid(modal_raw_valid),.raw_slot(modal_raw_slot),.raw_kind(modal_raw_kind),.raw_generation(modal_raw_generation),
        .raw_sum(modal_raw_sum),.raw_quiet(modal_raw_quiet),.raw_quiet_bound(modal_raw_quiet_bound),.slot_ages(modal_ages)
    );
    assign noise_busy=0; assign noise_done=0; assign noise_late=0;
    assign noise_bad=0; assign noise_valid=0; assign noise_voice_quiet=1;
    assign noise_slot=0; assign noise_generation=0; assign noise_sum=0;
    // 每槽Tom噪声最多约135拍全部完成，模态按16拍/槽返回；fresh旁路处理同拍到达。
    wire fresh_noise=accepted_noise&&noise_slot==modal_raw_slot;
    wire post_accept=accepted_raw&&modal_raw_kind!=2&&
        (modal_raw_kind!=1||noise_ready[modal_raw_slot]||fresh_noise);
    wire signed [55:0] selected_noise=fresh_noise ? noise_sum:noise_cache[modal_raw_slot];
    wire selected_noise_quiet=fresh_noise ? noise_voice_quiet:noise_quiet[modal_raw_slot];
    wire signed [55:0] tom_total=$signed(modal_raw_sum[55:0])+selected_noise;
    wire signed [31:0] tom_raw=32'(tom_total>>>26);
    // 入口寄存槽选择后的数据/力度，下一拍才进入乘法，所有元数据随同一笔事务前进。
    reg post_input_valid;
    reg signed [55:0] raw_input_q;
    reg signed [31:0] tom_input_q;
    reg [6:0] pressure_input_q;
    reg [4:0] input_slot_q;
    reg [1:0] input_kind_q;
    reg input_quiet_q,input_bass_q;
    reg [9:0] input_release_q;
    reg [2:0] post_valid;
    reg [4:0] post_slot0,post_slot1,post_slot2;
    reg [1:0] post_kind0,post_kind1,post_kind2;
    reg post_quiet0,post_quiet1,post_quiet2;
    reg signed [62:0] piano_product0;
    reg signed [39:0] tom_product0;
    reg [9:0] release0;
    reg bass0;
    reg signed [36:0] plucked_product1;
    reg bass1;
    wire signed [27:0] plucked_scaled=bass1 ? 28'(plucked_product1>>>9):28'(plucked_product1>>>8);
    wire signed [25:0] piano_scaled=26'(piano_product0>>>38);
    wire signed [32:0] tom_scaled=33'(tom_product0>>>7);
    reg signed [15:0] clipped1,clipped2;
    reg [2:0] modal_drain;
    reg waiting_modal_commit,committed_modal,done_exc;
    // 1088位PCM/完成掩码的总使能显式命名，只走局部布线；不改变复位或提交优先级。
    wire pcm_output_clear=!rst_n||panic||watchdog;
    wire pcm_output_commit=rst_n&&!panic&&!watchdog&&waiting_modal_commit&&modal_drain==0;
    (* syn_keep=1 *) wire pcm_output_enable=pcm_output_clear||pcm_output_commit;
    always @(posedge clk)if(pcm_output_enable)begin
        if(pcm_output_clear)begin piano_pcm<=0;tom_pcm<=0;piano_finished<=0;tom_finished<=0;end
        else begin piano_pcm<=piano_work;tom_pcm<=tom_work;piano_finished<=piano_finished_work;tom_finished<=tom_finished_work;end
    end
    // 代次专用同步RESET优先于CE；复位不再重复穿过513负载的提交使能组合路径。
    // watchdog仍只阻止新代次提交，不能清除旧代次；PCM/finished的提交沿保持。
    (* syn_keep=1 *) wire generation_output_enable=!watchdog&&waiting_modal_commit&&modal_drain==0;
    always @(posedge clk)begin
        if(!rst_n||panic)begin piano_finished_generation<=0;tom_finished_generation<=0;end
        else if(generation_output_enable)begin piano_finished_generation<=frame_generation;tom_finished_generation<=frame_generation;end
    end
    integer i;
    always @(posedge clk)begin
        if(!rst_n||panic)begin
            
            piano_work<=0;tom_work<=0;piano_finished_work<=0;tom_finished_work<=0;

            busy<=0;sample_valid<=0;deadline_error<=0;parameter_error<=0;alignment_error<=0;frame_failed<=0;piano_valid<=0;tom_valid<=0;
            frame_cycles<=0;max_frame_cycles<=0;noise_ready<=0;noise_quiet<=0;
            post_input_valid<=0;post_valid<=0;post_slot0<=0;post_slot1<=0;post_slot2<=0;post_kind0<=0;post_kind1<=0;post_kind2<=0;
            post_quiet0<=0;post_quiet1<=0;post_quiet2<=0;piano_product0<=0;tom_product0<=0;clipped1<=0;clipped2<=0;
            modal_drain<=0;waiting_modal_commit<=0;committed_modal<=0;done_exc<=0;
            plucked_owned<=0;
            for(i=0;i<32;i=i+1)begin release_age[i]<=0;end
            release0<=0;bass0<=0;bass1<=0;plucked_product1<=0;
        end else begin
            sample_valid<=0;frame_failed<=0;piano_valid<=0;tom_valid<=0;
            if(busy)frame_cycles<=frame_cycles+1'b1;
            if(sample_tick&&busy)deadline_error<=1;
            if(modal_late||noise_late||exc_late)deadline_error<=1;
            if(modal_bad||noise_bad||exc_bad)parameter_error<=1;
            if(modal_alignment)alignment_error<=1;
            if(watchdog)begin
                busy<=0;deadline_error<=1;frame_failed<=1;post_input_valid<=0;post_valid<=0;waiting_modal_commit<=0;committed_modal<=0;done_exc<=0;

            end else begin
                post_input_valid<=post_accept;post_valid<={post_valid[1:0],post_input_valid};
                if(accept)begin
                    busy<=1;frame_cycles<=0;
                    
                    piano_work<=0;tom_work<=0;piano_finished_work<=0;tom_finished_work<=0;noise_ready<=0;noise_quiet<=0;
                    post_input_valid<=0;post_valid<=0;waiting_modal_commit<=0;committed_modal<=0;done_exc<=0;modal_drain<=0;
                    for(i=0;i<32;i=i+1)begin
                        if(active[i]&&timbres[i*5+:5]!=10&&timbres[i*5+:5]!=19&&timbres[i*5+:5]!=20)parameter_error<=1;
                        if(!active[i])begin plucked_owned[i]<=0;release_age[i]<=0;end
                        else begin
                            plucked_owned[i]<=1;plucked_generation[i]<=generation[i*16+:16];
                            if(!plucked_owned[i]||plucked_generation[i]!=generation[i*16+:16])begin
                                plucked_release[i]<=timbres[i*5+:5]==20 ? 10'd512:10'd256;
                                release_age[i]<=0;
                            end else begin
                                if(held[i])release_age[i]<=0;
                                else if(release_age[i]<192000)release_age[i]<=release_age[i]+1'b1;
                                if(!held[i]&&plucked_release[i]!=0)plucked_release[i]<=plucked_release[i]-1'b1;
                            end
                        end
                    end
                end
                if(noise_valid)begin
                    if(!noise_identity_ok)alignment_error<=1;
                    if(accepted_noise)begin noise_cache[noise_slot]<=noise_sum;noise_ready[noise_slot]<=1;noise_quiet[noise_slot]<=noise_voice_quiet;end
                end
                if(modal_raw_valid&&!raw_identity_ok)alignment_error<=1;
                if(accepted_raw&&modal_raw_kind==1&&!(noise_ready[modal_raw_slot]||fresh_noise))alignment_error<=1;
                // 载荷逐拍采集，只有post_input_valid允许下级消费；去掉身份比较到宽CE的串联。
                // 无效拍可以含旧值/X，不能影响有效输出、所有权或写回。
                begin
                    input_slot_q<=modal_raw_slot;input_kind_q<=modal_raw_kind;
                    input_quiet_q<=enhanced[modal_raw_slot] ?
                        (modal_raw_quiet || (!frame_held[modal_raw_slot] &&
                         (release_age[modal_raw_slot]>=192000 || (modal_ages[modal_raw_slot*17+:17]>16 &&
                          modal_raw_quiet_bound<32768 && quiet_frames[modal_raw_slot]==3)))):
                        modal_raw_kind==3 ? (plucked_release[modal_raw_slot]==0||
                        (modal_ages[modal_raw_slot*17+:17]>24001&&modal_raw_quiet_bound<32768)):
                        modal_raw_quiet&&(modal_raw_kind!=1||selected_noise_quiet);
                    input_release_q<=enhanced[modal_raw_slot] ? (frame_timbres[modal_raw_slot*5+:5]==20 ? 10'd512:10'd256):plucked_release[modal_raw_slot];input_bass_q<=frame_timbres[modal_raw_slot*5+:5]==20;
                    // P：native56×positive7→signed63；T：先56位和回绕，再32位raw×positive7→signed40。
                    raw_input_q<=modal_raw_sum[55:0];tom_input_q<=tom_raw;
                    pressure_input_q<=frame_pressure[modal_raw_slot*7+:7];
                end
                if(post_input_valid)begin
                    post_slot0<=input_slot_q;post_kind0<=input_kind_q;post_quiet0<=input_quiet_q;
                    release0<=input_release_q;bass0<=input_bass_q;
                    piano_product0<=raw_input_q*$signed({1'b0,pressure_input_q});
                    tom_product0<=tom_input_q*$signed({1'b0,pressure_input_q});
                end
                if(post_valid[0])begin
                    post_slot1<=post_slot0;post_kind1<=post_kind0;post_quiet1<=post_quiet0;
                    plucked_product1<=piano_scaled*$signed({1'b0,release0});bass1<=bass0;
                    clipped1<=post_kind0==0 ? (piano_scaled>32767 ? 16'sd32767:piano_scaled< -32768 ? -16'sd32768:piano_scaled[15:0]):
                        (tom_scaled>32767 ? 16'sd32767:tom_scaled< -32768 ? -16'sd32768:tom_scaled[15:0]);
                end
                if(post_valid[1])begin
                    post_slot2<=post_slot1;post_kind2<=post_kind1;post_quiet2<=post_quiet1;
                    clipped2<=post_kind1==3 ? (post_quiet1 ? 16'sd0:
                        plucked_scaled>32767 ? 16'sd32767:plucked_scaled< -32768 ? -16'sd32768:plucked_scaled[15:0]):clipped1;
                end
                if(post_valid[2])begin
                    if(post_kind2==0||post_kind2==3)begin piano_work[post_slot2*16+:16]<=clipped2;piano_finished_work[post_slot2]<=piano_mask[post_slot2]&&post_quiet2;end
                    else begin tom_work[post_slot2*16+:16]<=clipped2;tom_finished_work[post_slot2]<=tom_mask[post_slot2]&&post_quiet2;end
                end
                if(modal_done&&busy&&!modal_bad&&!modal_late&&!modal_alignment)begin waiting_modal_commit<=1;modal_drain<=4;end
                if(waiting_modal_commit)begin
                    if(modal_drain!=0)modal_drain<=modal_drain-1'b1;
                    else begin
                        waiting_modal_commit<=0;committed_modal<=1;piano_valid<=1;tom_valid<=1;


                    end
                end
                if(exc_valid)done_exc<=1;
                if(busy&&committed_modal)begin
                    sample_valid<=1;busy<=0;if(frame_cycles>max_frame_cycles)max_frame_cycles<=frame_cycles;
                end
            end
        end
    end

endmodule
`default_nettype wire
