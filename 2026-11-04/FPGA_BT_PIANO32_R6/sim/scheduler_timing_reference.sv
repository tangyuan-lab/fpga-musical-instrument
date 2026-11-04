// Frozen 0x725ad43c scheduler for cycle-exact timing-refactor checks.
`timescale 1ns/1ps
`default_nettype none
// 独立精简变体：固定II1/有界延迟/严格按序返回，16深在途队列替代每地址记账位图。
// 与参考同端口/原生history；乱序或错误返回拒绝且不pop，600拍超时取消事务。
// F0锁存一帧，F1起每拍扫描一个{slot,group}地址；P/T16组、E13组，停车槽只产生气泡。
// 历史RAM不复位。所有权或generation改变时不读旧RAM，task_restart显式要求数学级重建原生初态。
module shared_modal_scheduler32_compact_timing_reference #(
    parameter integer FRAME_BUDGET=600, parameter integer PRECHECK_RETURN=0
)(
    input wire clk,rst_n,panic,
    input wire frame_start,
    input wire [15:0] frame_tag,
    input wire [31:0] active32,
    input wire [63:0] kinds64,
    input wire [511:0] generations512,
    // 各激励鼓拥有独立的24k相位；0表示该槽本帧停车，不能用全局奇偶代替。
    input wire [31:0] advance_exc_mask,
    output reg busy,frame_done,
    output reg deadline_error,parameter_error,alignment_error,
    output reg [9:0] frame_cycles,max_frame_cycles,issued_count,returned_count,
    output wire [543:0] slot_ages,
    // 参数ROM可并行使用此前置地址，与四个history银行在同一上升沿同步读。
    output wire prefetch_valid,
    output wire [4:0] prefetch_slot,
    output wire [1:0] prefetch_kind,
    output wire [3:0] prefetch_group,
    output reg task_valid,
    output reg [15:0] task_frame,
    output reg [4:0] task_slot,
    output reg [1:0] task_kind,
    output reg [3:0] task_group,
    output reg [15:0] task_generation,
    output reg [16:0] task_age,
    output reg task_restart,
    output wire [511:0] task_history,
    input wire precheck_valid,
    input wire [15:0] precheck_frame,precheck_generation,
    input wire [4:0] precheck_slot,
    input wire [1:0] precheck_kind,
    input wire [3:0] precheck_group,
    input wire return_valid,
    input wire [15:0] return_frame,
    input wire [4:0] return_slot,
    input wire [1:0] return_kind,
    input wire [3:0] return_group,
    input wire [15:0] return_generation,
    input wire [511:0] return_history,
    output wire return_accepted
);
    localparam [1:0] PIANO=0,TOM=1,EXCITATION=2;
    // 每组四个128位原生state，深度严格为32槽×16组；每银行只有一个同步读端和一个写端。
    (* ram_style="block",syn_ramstyle="block_ram" *) reg [127:0] history0[0:511];
    (* ram_style="block",syn_ramstyle="block_ram" *) reg [127:0] history1[0:511];
    (* ram_style="block",syn_ramstyle="block_ram" *) reg [127:0] history2[0:511];
    (* ram_style="block",syn_ramstyle="block_ram" *) reg [127:0] history3[0:511];
    reg [127:0] read0,read1,read2,read3;
    reg [31:0] history_complete;
    reg [8:0] inflight_tag[0:15];
    reg [3:0] inflight_read,inflight_write;
    reg [4:0] inflight_count;
    wire [8:0] head_tag=inflight_tag[inflight_read];
    reg [31:0] owned;
    reg [1:0] owner_kind[0:31];
    reg [15:0] owner_generation[0:31];
    reg [16:0] next_age[0:31];
    reg [31:0] frame_active,frame_restart;
    reg [63:0] frame_kinds;
    reg [511:0] frame_generations;
    reg [543:0] frame_ages;
    reg [15:0] current_frame;
    reg scanning;
    reg [8:0] cursor;
    // 同一帧最多约10个有效组在途；16深为RAM+7级数学及写回边沿留出余量。
    wire [4:0] issue_slot=cursor[8:4];
    wire [3:0] issue_group=cursor[3:0];
    wire [1:0] issue_kind=frame_kinds[issue_slot*2+:2];
    wire timeout_now=busy&&frame_cycles>=FRAME_BUDGET-1;
    wire issue_candidate=busy&&scanning&&rst_n&&!panic&&!timeout_now&&frame_active[issue_slot]&&
        (issue_kind!=EXCITATION||issue_group<13);
    wire queue_available=inflight_count<16||return_accepted;
    wire issue=issue_candidate&&queue_available;
    wire issue_first=frame_restart[issue_slot]||!history_complete[issue_slot];
    wire read_history=issue&&!issue_first;
    wire [8:0] return_address={return_slot,return_group};
    wire raw_identity=return_frame==current_frame&&frame_active[return_slot]&&
        return_kind==frame_kinds[return_slot*2+:2]&&
        return_generation==frame_generations[return_slot*16+:16]&&
        (return_kind!=EXCITATION||return_group<13);
    // 独立寄存宽身份的各个比较结果，末级仅合取，保持原E5->E6校验时刻。
    reg checked_frame,checked_active_kind,checked_generation,checked_range;
    wire checked_identity=checked_frame&&checked_active_kind&&checked_generation&&checked_range;
    always @(posedge clk)begin
        if(!rst_n||panic)begin checked_frame<=0;checked_active_kind<=0;checked_generation<=0;checked_range<=0;end
        else begin
            checked_frame<=precheck_valid&&precheck_frame==current_frame;
            checked_active_kind<=frame_active[precheck_slot]&&precheck_kind==frame_kinds[precheck_slot*2+:2];
            checked_generation<=precheck_generation==frame_generations[precheck_slot*16+:16];
            checked_range<=precheck_kind!=EXCITATION||precheck_group<13;
        end
    end
    wire return_matches=(PRECHECK_RETURN!=0 ? checked_identity:raw_identity)&&
        inflight_count!=0&&return_address==head_tag;
    assign return_accepted=return_valid&&rst_n&&!panic&&!timeout_now&&busy&&return_matches;
    assign prefetch_valid=issue;
    assign prefetch_slot=issue_slot;
    assign prefetch_kind=issue_kind;
    assign prefetch_group=issue_group;
    assign task_history=task_restart ? 512'd0:{read3,read2,read1,read0};
    genvar g;
    generate for(g=0;g<32;g=g+1)begin:g_ages
        assign slot_ages[g*17+:17]=next_age[g];
    end endgenerate

    // 数据阵列及读数据均无复位；有效位与restart保证任何有效任务都不会读取未写状态。
    // cursor在一帧内严格单调，返回只允许已发任务，因此有效读/写不可能同地址碰撞。
    always @(posedge clk)begin
        if(read_history)begin
            read0<=history0[cursor];read1<=history1[cursor];
            read2<=history2[cursor];read3<=history3[cursor];
        end
        if(return_accepted)begin
            history0[return_address]<=return_history[127:0];
            history1[return_address]<=return_history[255:128];
            history2[return_address]<=return_history[383:256];
            history3[return_address]<=return_history[511:384];
        end
    end

    integer i;
    always @(posedge clk)begin
        frame_done<=0;task_valid<=0;
        if(!rst_n||panic)begin
            busy<=0;scanning<=0;cursor<=0;frame_cycles<=0;max_frame_cycles<=0;
            deadline_error<=0;parameter_error<=0;alignment_error<=0;
            issued_count<=0;returned_count<=0;history_complete<=0;owned<=0;
            frame_active<=0;frame_restart<=0;frame_kinds<=0;frame_generations<=0;frame_ages<=0;
            current_frame<=0;inflight_read<=0;inflight_write<=0;inflight_count<=0;
            task_frame<=0;task_slot<=0;task_kind<=0;task_group<=0;task_generation<=0;task_age<=0;task_restart<=1;
            for(i=0;i<32;i=i+1)begin owner_kind[i]<=0;owner_generation[i]<=0;next_age[i]<=0;end
        end else begin
            if(issue)begin inflight_tag[inflight_write]<=cursor;inflight_write<=inflight_write+1'b1;end
            if(return_accepted)inflight_read<=inflight_read+1'b1;
            case({issue,return_accepted})
                2'b10:inflight_count<=inflight_count+1'b1;
                2'b01:inflight_count<=inflight_count-1'b1;
                default:;
            endcase
            if(issue_candidate&&!queue_available)deadline_error<=1;
            if(frame_start&&busy)deadline_error<=1; // 忙时拒绝新帧，原帧继续，不偷偷重启。
            if(return_valid&&!return_accepted)alignment_error<=1;
            if(return_accepted)begin
                if(return_group==(return_kind==EXCITATION ? 4'd12:4'd15))history_complete[return_slot]<=1;
                returned_count<=returned_count+1'b1;
            end
            if(busy)begin
                frame_cycles<=frame_cycles+1'b1;
                if(timeout_now)begin
                    busy<=0;scanning<=0;task_valid<=0;deadline_error<=1;frame_done<=1;
                    // 丢失返回后不能继续信任部分写回的历史，下一会话全部以first重建。
                    owned<=0;history_complete<=0;inflight_count<=0;inflight_read<=0;inflight_write<=0;
                    if(frame_cycles>max_frame_cycles)max_frame_cycles<=frame_cycles;
                end else begin
                    // 此分支已保证busy/rst_n/!panic/!timeout_now；不把这些条件绕经return_accepted再送回cursor使能。
                    if(scanning&&(!frame_active[issue_slot]||
                        (issue_kind==EXCITATION&&issue_group>=13)||inflight_count<16||(return_valid&&return_matches)))begin
                        if(cursor==511)scanning<=0;else cursor<=cursor+1'b1;
                    end
                    if(issue)begin
                        task_valid<=1;task_frame<=current_frame;task_slot<=issue_slot;task_kind<=issue_kind;
                        task_group<=issue_group;task_generation<=frame_generations[issue_slot*16+:16];
                        task_age<=frame_ages[issue_slot*17+:17];task_restart<=issue_first;
                        issued_count<=issued_count+1'b1;
                    end
                    if(!scanning&&!task_valid&&inflight_count==0)begin
                        busy<=0;frame_done<=1;
                        if(frame_cycles>max_frame_cycles)max_frame_cycles<=frame_cycles;
                    end
                end
            end else if(frame_start)begin
                busy<=1;scanning<=1;cursor<=0;frame_cycles<=0;current_frame<=frame_tag;
                issued_count<=0;returned_count<=0;inflight_read<=0;inflight_write<=0;inflight_count<=0;
                frame_kinds<=kinds64;frame_generations<=generations512;
                for(i=0;i<32;i=i+1)begin
                    frame_active[i]<=active32[i]&&
                        (kinds64[i*2+:2]!=EXCITATION||advance_exc_mask[i]);
                    frame_restart[i]<=!owned[i]||owner_kind[i]!=kinds64[i*2+:2]||owner_generation[i]!=generations512[i*16+:16]||!history_complete[i];
                    frame_ages[i*17+:17]<=0;
                    if(!active32[i])begin
                        // native后端停用即失去历史所有权；与仍活动但24k半帧停车的E槽严格区分。
                        owned[i]<=0;next_age[i]<=0;history_complete[i]<=0;
                    end

                    if(active32[i]&&
                        (kinds64[i*2+:2]!=EXCITATION||advance_exc_mask[i]))begin
                        if(!owned[i]||owner_kind[i]!=kinds64[i*2+:2]||owner_generation[i]!=generations512[i*16+:16]||!history_complete[i])begin
                            frame_ages[i*17+:17]<=0;next_age[i]<=1;history_complete[i]<=0;
                        end else begin
                            frame_ages[i*17+:17]<=next_age[i];
                            if(kinds64[i*2+:2]==EXCITATION)begin
                                if(next_age[i]<17'd100001)next_age[i]<=next_age[i]+1'b1;
                            end else if(next_age[i]!=17'h1ffff)next_age[i]<=next_age[i]+1'b1;
                        end
                        owned[i]<=1;owner_kind[i]<=kinds64[i*2+:2];owner_generation[i]<=generations512[i*16+:16];
                    end
                end
            end
        end
    end

`ifndef SYNTHESIS
    initial if(FRAME_BUDGET<525||FRAME_BUDGET>1023)$fatal(1,"compact scheduler FRAME_BUDGET must cover 512 issues plus math drain");
    always @(posedge clk)if(rst_n&&!panic&&read_history&&return_accepted&&cursor==return_address)
        $fatal(1,"shared history simultaneous read/write address collision");
`endif
endmodule
`default_nettype wire
