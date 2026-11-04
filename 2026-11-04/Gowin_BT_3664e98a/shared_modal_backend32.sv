`timescale 1ns/1ps
`default_nettype none
// 独立共享模态后端原型：四条math与四个统一history银行服务32槽三类模型。
// history和系数ROM在同一prefetch沿同步读；不能看到task_valid后再补一拍系数读取。
// 输出原生未缩放模态和，不包含噪声、解析片段、FIR、力度、ADSR或混音。
module shared_modal_backend32 #(parameter integer COMPACT_SCHEDULER=0,parameter integer EXTERNAL_PITCH=0,parameter integer REGISTER_INPUTS=1,parameter integer DAMPING_ENABLE=0,parameter integer VELOCITY_TONE_ENABLE=0)(
    input wire clk,rst_n,sample_tick,panic,
    input wire [31:0] active,held,
    input wire [767:0] damping_settings,
    input wire [63:0] velocity_tone_profiles,
    input wire [223:0] velocities,
    input wire [63:0] kinds,
    input wire [511:0] generation,
    input wire [159:0] piano_banks,
    input wire [1023:0] piano_pitches,
    output wire [4:0] piano_pitch_addr,
    input wire [31:0] piano_pitch_word,
    input wire [223:0] drum_indices,
    input wire [511:0] drum_pitches,
    input wire [31:0] advance_exc_mask,
    output reg busy,sample_valid,deadline_error,parameter_error,alignment_error,
    output reg raw_valid,
    output reg [4:0] raw_slot,
    output reg [1:0] raw_kind,
    output reg [15:0] raw_generation,
    output reg signed [63:0] raw_sum,
    output reg raw_quiet,
    output reg [15:0] raw_quiet_bound,
    output wire [543:0] slot_ages,
    output reg [10:0] frame_cycles,max_frame_cycles
);
    function automatic valid_exc_drum(input [6:0] drum);
        begin valid_exc_drum=drum==0||drum==3||drum==4||drum==5||drum==6||drum==7;end
    endfunction
    function automatic [2:0] exc_bank(input [6:0] drum);
        case(drum)
            0:exc_bank=0;3:exc_bank=1;4:exc_bank=2;5:exc_bank=3;6:exc_bank=4;7:exc_bank=5;default:exc_bank=0;
        endcase
    endfunction
    wire [767:0] frame_damping;
    wire [63:0] frame_tone_profiles;
    wire [223:0] frame_velocities;

    wire [31:0] frame_held;
    wire [63:0] frame_kinds;
    wire [511:0] frame_generation;
    wire [511:0] frame_drum_pitch;
    wire [159:0] frame_piano_banks;
    wire [223:0] frame_drums;
    reg [31:0] valid_active;
    wire [1023:0] frame_piano_pitch;

    reg [15:0] next_frame,current_frame;
    integer i;
    always @*begin
        valid_active=0;
        for(integer s=0;s<32;s=s+1)begin
            case(kinds[s*2+:2])
                0:valid_active[s]=active[s]&&(EXTERNAL_PITCH!=0||piano_pitches[s*32+:32]!=0);
                1:valid_active[s]=active[s]&&(drum_indices[s*7+:7]==1||drum_indices[s*7+:7]==2)&&drum_pitches[s*16+:16]!=0;
                2:valid_active[s]=active[s]&&valid_exc_drum(drum_indices[s*7+:7])&&drum_pitches[s*16+:16]!=0;
                3:valid_active[s]=active[s]&&(EXTERNAL_PITCH!=0||piano_pitches[s*32+:32]!=0);
                default:valid_active[s]=0;
            endcase
        end
    end
    (* syn_keep=1 *) wire accept=sample_tick&&!busy;
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
        reg [31:0] q_frame_held;assign frame_held=q_frame_held;
        reg [63:0] q_frame_kinds;assign frame_kinds=q_frame_kinds;
        reg [511:0] q_frame_generation;assign frame_generation=q_frame_generation;
        reg [511:0] q_frame_drum_pitch;assign frame_drum_pitch=q_frame_drum_pitch;
        reg [159:0] q_frame_piano_banks;assign frame_piano_banks=q_frame_piano_banks;
        reg [223:0] q_frame_drums;assign frame_drums=q_frame_drums;
        always @(posedge clk)if(rst_n&&!panic&&accept)begin
            q_frame_held<=held;
            q_frame_kinds<=kinds;
            q_frame_generation<=generation;
            q_frame_drum_pitch<=drum_pitches;
            q_frame_piano_banks<=piano_banks;
            q_frame_drums<=drum_indices;
        end
    end else begin:g_parent_snapshot
        assign frame_held=held;
        assign frame_kinds=kinds;
        assign frame_generation=generation;
        assign frame_drum_pitch=drum_pitches;
        assign frame_piano_banks=piano_banks;
        assign frame_drums=drum_indices;
        // synthesis translate_off
        reg [1503:0] checked_frame;
        reg [287:0] checked_tone;
        always @(posedge clk)if(rst_n&&!panic)begin
            if(accept)checked_frame<={held,kinds,generation,drum_pitches,piano_banks,drum_indices};
            else if(busy&&checked_frame!=={held,kinds,generation,drum_pitches,piano_banks,drum_indices})$fatal(1,"shared_modal_backend32 parent snapshot changed while busy");
            if(accept)checked_tone<={velocity_tone_profiles,velocities};
            else if(VELOCITY_TONE_ENABLE&&busy&&checked_tone!=={velocity_tone_profiles,velocities})$fatal(1,"backend velocity-tone snapshot changed while busy");
        end
        // synthesis translate_on
    end endgenerate

    generate if(EXTERNAL_PITCH==0)begin:g_wide_pitch
        reg [1023:0] snapshot;
        assign frame_piano_pitch=snapshot;
        always @(posedge clk)begin
            if(!rst_n||panic)snapshot<=0;
            else if(accept)snapshot<=piano_pitches;
        end
    end else begin:g_external_pitch
        // 父层mod_ram在整帧保持内容；prefetch同步读与state/coeff同步读严格同拍。
        assign frame_piano_pitch=1024'd0;
    end endgenerate
    wire scheduler_busy,scheduler_done,scheduler_late,scheduler_bad,scheduler_alignment;
    wire prefetch_valid,task_valid,task_restart;
    (* syn_keep=1 *) wire return_accepted;
    wire [4:0] prefetch_slot,task_slot;
    wire [1:0] prefetch_kind,task_kind;
    wire [3:0] prefetch_group,task_group;
    wire [15:0] task_frame,task_generation;
    wire [16:0] task_age;
    wire [31:0] task_piano_pitch=EXTERNAL_PITCH!=0 ? piano_pitch_word:frame_piano_pitch[task_slot*32+:32];
    wire [511:0] task_history,return_history;
    wire [3:0] lane_valid,lane_quiet,pre_valid;
    wire [43:0] pre_tag[0:3];
    wire [1:0] pre_kind[0:3];
    reg checked_return_q;
    wire [15:0] lane_bound[0:3];
    reg [15:0] bound_accumulator[0:3];
    wire [43:0] lane_tag[0:3];
    wire [1:0] lane_kind[0:3];
    wire signed [63:0] lane_contribution[0:3];
    wire [127:0] lane_state[0:3];
    wire lanes_aligned=lane_tag[0]==lane_tag[1]&&lane_tag[0]==lane_tag[2]&&lane_tag[0]==lane_tag[3]&&
        lane_kind[0]==lane_kind[1]&&lane_kind[0]==lane_kind[2]&&lane_kind[0]==lane_kind[3];
    // 完整frame/slot/group/generation/kind随math通过，返回不能仅靠“当前快照”重造旧标签。
    wire [15:0] return_frame=lane_tag[0][42:27];
    wire [4:0] return_slot=lane_tag[0][26:22];
    wire [3:0] return_group=lane_tag[0][21:18];
    wire [15:0] return_generation=lane_tag[0][17:2];
    wire [1:0] return_kind=lane_tag[0][1:0];
    // 帧快照在busy期间保持；用E5标签做宽选择/比较，E6寄存校验结果与数据对齐。
    // 实际输出仍检查四lane标签对齐；panic与复位保持最高优先级，不新增在途拍数。
    wire pre_aligned=pre_tag[0]==pre_tag[1]&&pre_tag[0]==pre_tag[2]&&pre_tag[0]==pre_tag[3]&&
        pre_kind[0]==pre_kind[1]&&pre_kind[0]==pre_kind[2]&&pre_kind[0]==pre_kind[3];
    wire [4:0] pre_slot=pre_tag[0][26:22];
    wire pre_identity_ok=(&pre_valid)&&pre_aligned&&pre_kind[0]==pre_tag[0][1:0]&&
        pre_tag[0][42:27]==current_frame&&pre_tag[0][17:2]==frame_generation[pre_slot*16+:16]&&
        pre_tag[0][1:0]==frame_kinds[pre_slot*2+:2];
    always @(posedge clk)begin
        if(!rst_n||panic)checked_return_q<=0;
        else checked_return_q<=pre_identity_ok;
    end
    wire return_valid=(&lane_valid)&&lanes_aligned&&checked_return_q&&!panic&&rst_n;
    assign return_history={lane_state[3],lane_state[2],lane_state[1],lane_state[0]};
    generate if(COMPACT_SCHEDULER==0)begin:g_reference
    shared_modal_scheduler32 scheduler(
        .clk(clk),.rst_n(rst_n),.panic(panic),.frame_start(accept),.frame_tag(next_frame),
        .active32(valid_active),.kinds64(kinds),.generations512(generation),.advance_exc_mask(advance_exc_mask),
        .busy(scheduler_busy),.frame_done(scheduler_done),.deadline_error(scheduler_late),.parameter_error(scheduler_bad),.alignment_error(scheduler_alignment),
        .slot_ages(slot_ages),.prefetch_valid(prefetch_valid),.prefetch_slot(prefetch_slot),.prefetch_kind(prefetch_kind),.prefetch_group(prefetch_group),
        .task_valid(task_valid),.task_frame(task_frame),.task_slot(task_slot),.task_kind(task_kind),.task_group(task_group),
        .task_generation(task_generation),.task_age(task_age),.task_restart(task_restart),.task_history(task_history),
        .return_valid(return_valid),.return_frame(return_frame),.return_slot(return_slot),.return_kind(return_kind),.return_group(return_group),
        .return_generation(return_generation),.return_history(return_history),.return_accepted(return_accepted)
    );
    end else begin:g_compact
    shared_modal_scheduler32_compact #(.PRECHECK_RETURN(1)) scheduler(
        .clk(clk),.rst_n(rst_n),.panic(panic),.frame_start(accept),.frame_tag(next_frame),
        .active32(valid_active),.kinds64(kinds),.generations512(generation),.advance_exc_mask(advance_exc_mask),
        .busy(scheduler_busy),.frame_done(scheduler_done),.deadline_error(scheduler_late),.parameter_error(scheduler_bad),.alignment_error(scheduler_alignment),
        .slot_ages(slot_ages),.prefetch_valid(prefetch_valid),.prefetch_slot(prefetch_slot),.prefetch_kind(prefetch_kind),.prefetch_group(prefetch_group),
        .task_valid(task_valid),.task_frame(task_frame),.task_slot(task_slot),.task_kind(task_kind),.task_group(task_group),
        .task_generation(task_generation),.task_age(task_age),.task_restart(task_restart),.task_history(task_history),
        .precheck_valid((&pre_valid)&&pre_aligned),.precheck_frame(pre_tag[0][42:27]),
        .precheck_slot(pre_slot),.precheck_kind(pre_tag[0][1:0]),.precheck_group(pre_tag[0][21:18]),
        .precheck_generation(pre_tag[0][17:2]),.return_valid(return_valid),.return_frame(return_frame),.return_slot(return_slot),.return_kind(return_kind),.return_group(return_group),
        .return_generation(return_generation),.return_history(return_history),.return_accepted(return_accepted)
    );
    end endgenerate
    wire [8:0] piano_address={frame_piano_banks[prefetch_slot*5+:5],prefetch_group};
    assign piano_pitch_addr=prefetch_slot;
    // Resolve the model/bank base once per frame. The per-task ROM path now only
    // selects a nine-bit base and adds the small group offset.
    reg [287:0] coefficient_bases;
    generate for(genvar cb=0;cb<32;cb=cb+1)begin:g_coefficient_base
        wire [1:0] kind=kinds[cb*2+:2];
        wire [8:0] piano_base={1'b0,piano_banks[cb*5+:5],3'b0};
        wire [8:0] excitation_base={6'd0,exc_bank(drum_indices[cb*7+:7])};
        always @(posedge clk)if(accept)case(kind)
            0:coefficient_bases[cb*9+:9]<=piano_base;
            1:coefficient_bases[cb*9+:9]<=9'd136+(drum_indices[cb*7+:7]==2 ? 9'd16:9'd0);
            2:coefficient_bases[cb*9+:9]<=9'd168+(excitation_base<<3)+(excitation_base<<2)+excitation_base;
            3:coefficient_bases[cb*9+:9]<=9'd246+piano_base;
        endcase
    end endgenerate
    wire [8:0] coefficient_address=coefficient_bases[prefetch_slot*9+:9]+
        ((prefetch_kind==0||prefetch_kind==3) ? {6'd0,prefetch_group[3:1]}:{5'd0,prefetch_group});
    wire [43:0] math_tag={(task_kind==2&&task_age>100000)||(task_kind==0&&task_piano_pitch==0),
        task_frame,task_slot,task_group,task_generation,task_kind};
    wire [31:0] enhanced_active;
    wire [31:0] tone_active;
    genvar expr_slot;
    generate for(expr_slot=0;expr_slot<32;expr_slot=expr_slot+1)begin:g_pipe_mode
        assign enhanced_active[expr_slot]=valid_active[expr_slot] && damping_settings[expr_slot*24+22+:2]!=0;
        assign tone_active[expr_slot]=valid_active[expr_slot]&&kinds[expr_slot*2+:2]==0&&velocity_tone_profiles[expr_slot*2+:2]!=0;
    end endgenerate
    reg pipe_frame;
    always @(posedge clk)begin
        if(!rst_n||panic)pipe_frame<=0;
        else if(accept)pipe_frame<=(DAMPING_ENABLE && |enhanced_active)||(VELOCITY_TONE_ENABLE && |tone_active);
    end
    (* syn_keep=1 *) wire damping_pipe_capture=task_valid && pipe_frame;
    reg pipe_valid,pipe_first,pipe_held;
    reg [43:0] pipe_tag;reg [1:0] pipe_kind;
    reg [16:0] pipe_age;reg [31:0] pipe_pitch;reg [15:0] pipe_drum_pitch;
    always @(posedge clk)begin
        if(!rst_n||panic)pipe_valid<=0;else pipe_valid<=damping_pipe_capture;
        if(damping_pipe_capture)begin
            pipe_tag<=math_tag;pipe_kind<={2{task_kind[1]}};pipe_first<=task_restart;
            pipe_held<=frame_held[task_slot];pipe_age<=task_age;pipe_pitch<=task_piano_pitch;
            pipe_drum_pitch<=frame_drum_pitch[task_slot*16+:16];
        end
    end
    reg signed [63:0] accumulator[0:3];
    reg [3:0] quiet_accumulator;
    genvar lane;
    generate for(lane=0;lane<4;lane=lane+1)begin:g_lane
        // P17 banks occupy136 words, T32 and E78 words follow; G/B occupy256.
        // Plucked body flags use a separate tiny ROM. All coefficients are exact.
        // 同拍读取和kind/half选择寄存保持原系数延迟；四lane仍各有独立读口。
        (* syn_romstyle="block_rom" *) reg [255:0] coefficients[0:511];
        (* syn_romstyle="logic" *) reg [1:0] body_flags[0:255];
        if(lane==0)initial $readmemh("gb_body_lane0.mem",body_flags);
        if(lane==1)initial $readmemh("gb_body_lane1.mem",body_flags);
        if(lane==2)initial $readmemh("gb_body_lane2.mem",body_flags);
        if(lane==3)initial $readmemh("gb_body_lane3.mem",body_flags);
        if(lane==0)initial $readmemh("shared_coeff_lane0.mem",coefficients);
        if(lane==1)initial $readmemh("shared_coeff_lane1.mem",coefficients);
        if(lane==2)initial $readmemh("shared_coeff_lane2.mem",coefficients);
        if(lane==3)initial $readmemh("shared_coeff_lane3.mem",coefficients);
        reg [255:0] coefficient_word;
        reg [31:0] damping_config;
        reg [1:0] tone_profile;reg [6:0] initial_velocity;
        reg [1:0] coefficient_kind;
        reg piano_half,piano_padding;reg [1:0] flags_q;
        always @(posedge clk)if(rst_n&&!panic&&prefetch_valid)begin
            damping_config<={8'd0,frame_damping[prefetch_slot*24+:24]};
            tone_profile<=frame_tone_profiles[prefetch_slot*2+:2];initial_velocity<=frame_velocities[prefetch_slot*7+:7];
            coefficient_word<=coefficients[coefficient_address];coefficient_kind<=prefetch_kind;piano_half<=piano_address[0];
            piano_padding<=frame_piano_banks[prefetch_slot*5+:5]>=17;
            flags_q<=body_flags[piano_address[8:1]];
        end
        wire [127:0] selected_half=piano_half ? coefficient_word[255:128]:coefficient_word[127:0];
        wire [255:0] coefficient_q=coefficient_kind==0 ?
            (piano_padding ? 256'd0:{128'd0,selected_half}):coefficient_kind==3 ?
            {127'd0,(piano_half ? flags_q[1]:flags_q[0]),selected_half}:coefficient_word;
        // Additional loss is selected from native modal-frequency bands. No new multiplier.
        reg [23:0] selected_loss;
        reg [24:0] band_loss;
        always @*begin
            band_loss={5'd0,damping_config[19:0]};
            if(selected_half[127:96]>=32'd223696213)band_loss=band_loss<<damping_config[21:20];
            else if(selected_half[127:96]>=32'd53687091 && damping_config[21:20]!=0)
                band_loss=band_loss<<(damping_config[21:20]-1'b1);
            if(task_kind==3 && coefficient_q[128])band_loss=band_loss>>2;
            selected_loss=0;
            if(damping_config[23:22]!=0)begin
                if(!frame_held[task_slot])selected_loss=band_loss[23:0];
                else if(task_kind==3 && damping_config[23:22]==3)selected_loss=band_loss[23:0]>>2;
            end
        end
        reg [255:0] pipe_coefficient;reg [127:0] pipe_history;
        reg [23:0] pipe_loss;reg pipe_enabled;
        wire [23:0] tone_gain;reg [23:0] pipe_tone_gain;reg pipe_tone_enabled;
        piano_velocity_gain gain_map(.velocity(initial_velocity),.profile(tone_profile),.native_frequency(selected_half[127:96]),.gain(tone_gain));
        always @(posedge clk)if(damping_pipe_capture)begin
            pipe_coefficient<=coefficient_q;pipe_history<=task_history[lane*128+:128];
            pipe_loss<=selected_loss;pipe_enabled<=damping_config[23:22]!=0;
            pipe_tone_gain<=tone_gain;pipe_tone_enabled<=tone_profile!=0&&coefficient_kind==0;
        end
        shared_modal_math #(.TAG_WIDTH(44),.DAMPING_ENABLE(DAMPING_ENABLE),.VELOCITY_TONE_ENABLE(VELOCITY_TONE_ENABLE)) math(
            .clk(clk),.rst_n(rst_n&&!panic),.in_valid(pipe_frame ? pipe_valid:task_valid),
            .in_tag(pipe_frame ? pipe_tag:math_tag),.kind(pipe_frame ? pipe_kind:{2{task_kind[1]}}),
            .first(pipe_frame ? pipe_first:task_restart),.held(pipe_frame ? pipe_held:frame_held[task_slot]),
            .age(pipe_frame ? pipe_age:task_age),
            .damping_active(pipe_frame&&pipe_enabled),.damping_loss(pipe_loss),
            .damping_native(pipe_coefficient[47:0]),
            .excitation_active(pipe_frame&&pipe_tone_enabled),.excitation_gain(pipe_tone_gain),
            .piano_pitch(pipe_frame ? pipe_pitch:task_piano_pitch),.drum_pitch(pipe_frame ? pipe_drum_pitch:frame_drum_pitch[task_slot*16+:16]),
            .coefficient(pipe_frame ? pipe_coefficient:coefficient_q),.state(pipe_frame ? pipe_history:task_history[lane*128+:128]),
            .precommit_valid(pre_valid[lane]),.precommit_tag(pre_tag[lane]),.precommit_kind(pre_kind[lane]),
            .out_valid(lane_valid[lane]),.out_tag(lane_tag[lane]),.out_kind(lane_kind[lane]),
            .contribution(lane_contribution[lane]),.next_state(lane_state[lane]),.quiet(lane_quiet[lane]),.quiet_bound(lane_bound[lane])
        );
    end endgenerate
    // History writes retain their original acceptance edge. Reduction of the
    // accepted lane contributions is isolated by one local valid/data stage.
    // Data registers have no reset; group zero initializes each accumulation,
    // and reset/panic cancels the valid bits before any data can be published.
    reg reduction_valid,reduction_natural_end,reduction_muted;
    reg [3:0] reduction_group,reduction_quiet;
    reg [4:0] reduction_slot;reg [1:0] reduction_kind;reg [15:0] reduction_generation;
    reg signed [63:0] reduction_contribution[0:3];reg [15:0] reduction_bound[0:3];
    always @(posedge clk)begin
        if(!rst_n||panic)reduction_valid<=0;else reduction_valid<=return_accepted;
        reduction_group<=return_group;reduction_slot<=return_slot;reduction_kind<=return_kind;
        reduction_generation<=return_generation;reduction_natural_end<=return_kind==2&&lane_tag[0][43];
        reduction_muted<=lane_tag[0][43];reduction_quiet<=lane_quiet;
        for(integer a=0;a<4;a=a+1)begin
            reduction_contribution[a]<=lane_contribution[a];reduction_bound[a]<=lane_bound[a];
        end
    end
    wire [16:0] reduced_bound[0:3];wire signed [63:0] reduced_partial[0:3];
    generate for(genvar a=0;a<4;a=a+1)begin:g_reduce
        wire signed [63:0] total=(reduction_group==0 ? 64'sd0:accumulator[a])+reduction_contribution[a];
        wire signed [55:0] native_total=total[55:0];
        assign reduced_partial[a]=reduction_kind==2 ? total:{{8{native_total[55]}},native_total};
        assign reduced_bound[a]={1'b0,(reduction_group==0 ? 16'd0:bound_accumulator[a])}+{1'b0,reduction_bound[a]};
        always @(posedge clk)if(reduction_valid)begin
            accumulator[a]<=reduced_partial[a];
            bound_accumulator[a]<=reduced_bound[a]>=32768 ? 16'd32768:reduced_bound[a][15:0];
            quiet_accumulator[a]<=(reduction_group==0||quiet_accumulator[a])&&reduction_quiet[a];
        end
    end endgenerate
    wire [18:0] bound_total={2'd0,reduced_bound[0]}+{2'd0,reduced_bound[1]}+{2'd0,reduced_bound[2]}+{2'd0,reduced_bound[3]};
    wire signed [63:0] native_sum=reduced_partial[0]+reduced_partial[1]+reduced_partial[2]+reduced_partial[3];
    wire raw_publish=reduction_valid&&reduction_group==(reduction_kind==2 ? 12:15);
    always @(posedge clk)if(raw_publish)begin
        raw_slot<=reduction_slot;raw_kind<=reduction_kind;raw_generation<=reduction_generation;
        raw_quiet_bound<=bound_total>=32768 ? 16'd32768:bound_total[15:0];
        raw_sum<=reduction_muted ? 64'sd0:native_sum;
        raw_quiet<=reduction_natural_end||(&((reduction_group==0 ? 4'b1111:quiet_accumulator)&reduction_quiet));
    end
    always @(posedge clk)begin
        if(!rst_n||panic)begin
            busy<=0;sample_valid<=0;deadline_error<=0;parameter_error<=0;alignment_error<=0;
            raw_valid<=0;
            
            next_frame<=0;current_frame<=0;frame_cycles<=0;max_frame_cycles<=0;
        end else begin
            sample_valid<=0;raw_valid<=0;
            if(busy)frame_cycles<=frame_cycles+1'b1;
            if(scheduler_late)deadline_error<=1;
            if(scheduler_bad)parameter_error<=1;
            if(scheduler_alignment)alignment_error<=1;
            if(task_valid&&task_kind==0&&task_piano_pitch==0)parameter_error<=1;
            if((|lane_valid)&&(!(&lane_valid)||!lanes_aligned||!return_valid))alignment_error<=1;
            if(sample_tick&&busy)deadline_error<=1;
            if(accept)begin
                busy<=1;frame_cycles<=0;current_frame<=next_frame;next_frame<=next_frame+1'b1;
                
                
                if((active&~valid_active)!=0)parameter_error<=1;
            end
            if(raw_publish)raw_valid<=1;
            if(scheduler_done)begin
                sample_valid<=1;busy<=0;
                if(frame_cycles>max_frame_cycles)max_frame_cycles<=frame_cycles;
            end
        end
    end
endmodule
`default_nettype wire
