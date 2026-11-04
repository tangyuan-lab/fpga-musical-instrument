`timescale 1ns/1ps
`default_nettype none
// 独立共享模态后端原型：四条math与四个统一history银行服务32槽三类模型。
// history和系数ROM在同一prefetch沿同步读；不能看到task_valid后再补一拍系数读取。
// 输出原生未缩放模态和，不包含噪声、解析片段、FIR、力度、ADSR或混音。
module shared_modal_backend32_reference #(parameter integer COMPACT_SCHEDULER=0,parameter integer EXTERNAL_PITCH=0,parameter integer REGISTER_INPUTS=1)(
    input wire clk,rst_n,sample_tick,panic,
    input wire [31:0] active,held,
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
    wire accept=sample_tick&&!busy;
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
        always @(posedge clk)if(rst_n&&!panic)begin
            if(accept)checked_frame<={held,kinds,generation,drum_pitches,piano_banks,drum_indices};
            else if(busy&&checked_frame!=={held,kinds,generation,drum_pitches,piano_banks,drum_indices})$fatal(1,"shared_modal_backend32 parent snapshot changed while busy");
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
    wire prefetch_valid,task_valid,task_restart,return_accepted;
    wire [4:0] prefetch_slot,task_slot;
    wire [1:0] prefetch_kind,task_kind;
    wire [3:0] prefetch_group,task_group;
    wire [15:0] task_frame,task_generation;
    wire [16:0] task_age;
    wire [31:0] task_piano_pitch=EXTERNAL_PITCH!=0 ? piano_pitch_word:frame_piano_pitch[task_slot*32+:32];
    wire [511:0] task_history,return_history;
    wire [3:0] lane_valid,lane_quiet;
    wire [15:0] lane_bound[0:3];
    reg [15:0] bound_accumulator[0:3];
    wire [16:0] bound_partial[0:3];
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
    wire return_valid=(&lane_valid)&&lanes_aligned&&lane_kind[0]==return_kind&&
        return_frame==current_frame&&return_generation==frame_generation[return_slot*16+:16]&&
        return_kind==frame_kinds[return_slot*2+:2]&&!panic&&rst_n;
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
    shared_modal_scheduler32_compact scheduler(
        .clk(clk),.rst_n(rst_n),.panic(panic),.frame_start(accept),.frame_tag(next_frame),
        .active32(valid_active),.kinds64(kinds),.generations512(generation),.advance_exc_mask(advance_exc_mask),
        .busy(scheduler_busy),.frame_done(scheduler_done),.deadline_error(scheduler_late),.parameter_error(scheduler_bad),.alignment_error(scheduler_alignment),
        .slot_ages(slot_ages),.prefetch_valid(prefetch_valid),.prefetch_slot(prefetch_slot),.prefetch_kind(prefetch_kind),.prefetch_group(prefetch_group),
        .task_valid(task_valid),.task_frame(task_frame),.task_slot(task_slot),.task_kind(task_kind),.task_group(task_group),
        .task_generation(task_generation),.task_age(task_age),.task_restart(task_restart),.task_history(task_history),
        .return_valid(return_valid),.return_frame(return_frame),.return_slot(return_slot),.return_kind(return_kind),.return_group(return_group),
        .return_generation(return_generation),.return_history(return_history),.return_accepted(return_accepted)
    );
    end endgenerate
    wire [8:0] piano_address={frame_piano_banks[prefetch_slot*5+:5],prefetch_group};
    wire [4:0] tom_address={frame_drums[prefetch_slot*7+:7]==2,prefetch_group};
    wire [6:0] bank={4'd0,exc_bank(frame_drums[prefetch_slot*7+:7])};
    wire [6:0] excitation_address=(bank<<3)+(bank<<2)+bank+{3'd0,prefetch_group};
    assign piano_pitch_addr=prefetch_slot;
    wire [43:0] math_tag={(task_kind==2&&task_age>100000)||(task_kind==0&&task_piano_pitch==0),
        task_frame,task_slot,task_group,task_generation,task_kind};
    reg signed [63:0] accumulator[0:3];
    reg [3:0] quiet_accumulator;
    wire signed [63:0] partial[0:3];
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
        wire [8:0] coefficient_address=prefetch_kind==0 ? {1'b0,piano_address[8:1]}:
            prefetch_kind==1 ? 9'd136+{4'd0,tom_address}:prefetch_kind==2 ? 9'd168+{2'd0,excitation_address}:
            9'd246+{1'b0,piano_address[8:1]};
        reg [255:0] coefficient_word;
        reg [1:0] coefficient_kind;
        reg piano_half,piano_padding;reg [1:0] flags_q;
        always @(posedge clk)if(rst_n&&!panic&&prefetch_valid)begin
            coefficient_word<=coefficients[coefficient_address];coefficient_kind<=prefetch_kind;piano_half<=piano_address[0];
            piano_padding<=frame_piano_banks[prefetch_slot*5+:5]>=17;
            flags_q<=body_flags[piano_address[8:1]];
        end
        wire [127:0] selected_half=piano_half ? coefficient_word[255:128]:coefficient_word[127:0];
        wire [255:0] coefficient_q=coefficient_kind==0 ?
            (piano_padding ? 256'd0:{128'd0,selected_half}):coefficient_kind==3 ?
            {127'd0,(piano_half ? flags_q[1]:flags_q[0]),selected_half}:coefficient_word;
        shared_modal_math #(.TAG_WIDTH(44)) math(
            .clk(clk),.rst_n(rst_n&&!panic),.in_valid(task_valid),.in_tag(math_tag),.kind({2{task_kind[1]}}),
            .first(task_restart),.held(frame_held[task_slot]),.age(task_age),
            .piano_pitch(task_piano_pitch),.drum_pitch(frame_drum_pitch[task_slot*16+:16]),
            .coefficient(coefficient_q),.state(task_history[lane*128+:128]),
            .out_valid(lane_valid[lane]),.out_tag(lane_tag[lane]),.out_kind(lane_kind[lane]),
            .contribution(lane_contribution[lane]),.next_state(lane_state[lane]),.quiet(lane_quiet[lane]),.quiet_bound(lane_bound[lane])
        );
        assign bound_partial[lane]={1'b0,(return_group==0 ? 16'd0:bound_accumulator[lane])}+{1'b0,lane_bound[lane]};
        wire signed [63:0] unbounded_partial=(return_group==0 ? 64'sd0:accumulator[lane])+lane_contribution[lane];
        wire signed [55:0] native_partial=unbounded_partial[55:0];
        assign partial[lane]=return_kind==2 ? unbounded_partial:{{8{native_partial[55]}},native_partial};
    end endgenerate
    wire [18:0] bound_total={2'd0,bound_partial[0]}+{2'd0,bound_partial[1]}+{2'd0,bound_partial[2]}+{2'd0,bound_partial[3]};
    wire natural_end=return_kind==2&&lane_tag[0][43];
    wire signed [63:0] native_sum=partial[0]+partial[1]+partial[2]+partial[3];
    always @(posedge clk)begin
        if(!rst_n||panic)begin
            busy<=0;sample_valid<=0;deadline_error<=0;parameter_error<=0;alignment_error<=0;
            raw_valid<=0;raw_slot<=0;raw_kind<=0;raw_generation<=0;raw_sum<=0;raw_quiet<=1;raw_quiet_bound<=0;
            
            next_frame<=0;current_frame<=0;frame_cycles<=0;max_frame_cycles<=0;quiet_accumulator<=0;
            for(i=0;i<4;i=i+1)begin accumulator[i]<=0;bound_accumulator[i]<=0;end
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
            if(return_accepted)begin
                for(i=0;i<4;i=i+1)begin
                    bound_accumulator[i]<=bound_partial[i]>=32768 ? 16'd32768:bound_partial[i][15:0];
                    accumulator[i]<=partial[i];quiet_accumulator[i]<=(return_group==0||quiet_accumulator[i])&&lane_quiet[i];
                end
                if(return_group==(return_kind==2 ? 12:15))begin
                    raw_valid<=1;raw_slot<=return_slot;raw_kind<=return_kind;raw_generation<=return_generation;
                    raw_quiet_bound<=bound_total>=32768 ? 16'd32768:bound_total[15:0];
                    raw_sum<=lane_tag[0][43] ? 64'sd0:native_sum;
                    raw_quiet<=natural_end||(&((return_group==0 ? 4'b1111:quiet_accumulator)&lane_quiet));
                end
            end
            if(scheduler_done)begin
                sample_valid<=1;busy<=0;
                if(frame_cycles>max_frame_cycles)max_frame_cycles<=frame_cycles;
            end
        end
    end
endmodule
`default_nettype wire
