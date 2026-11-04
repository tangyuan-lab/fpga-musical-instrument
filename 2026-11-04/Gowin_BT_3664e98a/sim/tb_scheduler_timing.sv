`timescale 1ns/1ps
`include "sim/scheduler_timing_reference.sv"
module tb_scheduler_timing;
    `include "sim/result.svh"
    reg clk=0;always #10 clk=~clk;
    reg rst_n=0,panic=0,frame_start=0,drop_returns=0,corrupt=0;
    reg [15:0] frame_tag=0;
    reg [31:0] active=32'hffffffff,advance=32'hffffffff;
    reg [63:0] kinds=0;reg [511:0] generations=0;
    wire busy[0:1];
    wire frame_done[0:1];
    wire deadline_error[0:1];
    wire parameter_error[0:1];
    wire alignment_error[0:1];
    wire [9:0] frame_cycles[0:1];
    wire [9:0] max_frame_cycles[0:1];
    wire [9:0] issued_count[0:1];
    wire [9:0] returned_count[0:1];
    wire [543:0] slot_ages[0:1];
    wire prefetch_valid[0:1];
    wire [4:0] prefetch_slot[0:1];
    wire [1:0] prefetch_kind[0:1];
    wire [3:0] prefetch_group[0:1];
    wire task_valid[0:1];
    wire [15:0] task_frame[0:1];
    wire [4:0] task_slot[0:1];
    wire [1:0] task_kind[0:1];
    wire [3:0] task_group[0:1];
    wire [15:0] task_generation[0:1];
    wire [16:0] task_age[0:1];
    wire task_restart[0:1];
    wire [511:0] task_history[0:1];
    wire return_accepted[0:1];
    reg [8:0] vp=0;
    reg [15:0] pf[0:8],pg[0:8];reg [4:0] ps[0:8];reg [1:0] pk[0:8];reg [3:0] pb[0:8];
    always @(posedge clk)begin
        if(!rst_n||panic)vp<=0;
        else begin
            vp<={vp[7:0],task_valid[0]};
            pf[0]<=task_frame[0];pg[0]<=task_generation[0];ps[0]<=task_slot[0];pk[0]<=task_kind[0];pb[0]<=task_group[0];
            for(integer j=1;j<9;j=j+1)begin pf[j]<=pf[j-1];pg[j]<=pg[j-1];ps[j]<=ps[j-1];pk[j]<=pk[j-1];pb[j]<=pb[j-1];end
        end
    end
    shared_modal_scheduler32_compact_timing_reference #(.PRECHECK_RETURN(1)) original(.clk(clk),.rst_n(rst_n),.panic(panic),.frame_start(frame_start),.frame_tag(frame_tag),
        .active32(active),.kinds64(kinds),.generations512(generations),.advance_exc_mask(advance),
        .precheck_valid(vp[7]&&!drop_returns),.precheck_frame(pf[7]),.precheck_generation(pg[7]),
        .precheck_slot(ps[7]),.precheck_kind(pk[7]),.precheck_group(pb[7]),
        .return_valid(vp[8]&&!drop_returns),.return_frame(pf[8]),.return_generation(pg[8]^{15'd0,corrupt}),
        .return_slot(ps[8]),.return_kind(pk[8]),.return_group(pb[8]),
        .return_history({16{32'h12345678^{7'd0,pf[8],ps[8],pb[8]}}}),
        .busy(busy[0]),
        .frame_done(frame_done[0]),
        .deadline_error(deadline_error[0]),
        .parameter_error(parameter_error[0]),
        .alignment_error(alignment_error[0]),
        .frame_cycles(frame_cycles[0]),
        .max_frame_cycles(max_frame_cycles[0]),
        .issued_count(issued_count[0]),
        .returned_count(returned_count[0]),
        .slot_ages(slot_ages[0]),
        .prefetch_valid(prefetch_valid[0]),
        .prefetch_slot(prefetch_slot[0]),
        .prefetch_kind(prefetch_kind[0]),
        .prefetch_group(prefetch_group[0]),
        .task_valid(task_valid[0]),
        .task_frame(task_frame[0]),
        .task_slot(task_slot[0]),
        .task_kind(task_kind[0]),
        .task_group(task_group[0]),
        .task_generation(task_generation[0]),
        .task_age(task_age[0]),
        .task_restart(task_restart[0]),
        .task_history(task_history[0]),
        .return_accepted(return_accepted[0]));
    shared_modal_scheduler32_compact #(.PRECHECK_RETURN(1)) candidate(.clk(clk),.rst_n(rst_n),.panic(panic),.frame_start(frame_start),.frame_tag(frame_tag),
        .active32(active),.kinds64(kinds),.generations512(generations),.advance_exc_mask(advance),
        .precheck_valid(vp[7]&&!drop_returns),.precheck_frame(pf[7]),.precheck_generation(pg[7]),
        .precheck_slot(ps[7]),.precheck_kind(pk[7]),.precheck_group(pb[7]),
        .return_valid(vp[8]&&!drop_returns),.return_frame(pf[8]),.return_generation(pg[8]^{15'd0,corrupt}),
        .return_slot(ps[8]),.return_kind(pk[8]),.return_group(pb[8]),
        .return_history({16{32'h12345678^{7'd0,pf[8],ps[8],pb[8]}}}),
        .busy(busy[1]),
        .frame_done(frame_done[1]),
        .deadline_error(deadline_error[1]),
        .parameter_error(parameter_error[1]),
        .alignment_error(alignment_error[1]),
        .frame_cycles(frame_cycles[1]),
        .max_frame_cycles(max_frame_cycles[1]),
        .issued_count(issued_count[1]),
        .returned_count(returned_count[1]),
        .slot_ages(slot_ages[1]),
        .prefetch_valid(prefetch_valid[1]),
        .prefetch_slot(prefetch_slot[1]),
        .prefetch_kind(prefetch_kind[1]),
        .prefetch_group(prefetch_group[1]),
        .task_valid(task_valid[1]),
        .task_frame(task_frame[1]),
        .task_slot(task_slot[1]),
        .task_kind(task_kind[1]),
        .task_group(task_group[1]),
        .task_generation(task_generation[1]),
        .task_age(task_age[1]),
        .task_restart(task_restart[1]),
        .task_history(task_history[1]),
        .return_accepted(return_accepted[1]));
    integer cycles=0,accepted=0,frames=0;
    always @(negedge clk)if(rst_n)begin
        cycles=cycles+1;
        if(busy[0]!==busy[1])$fatal(1,"scheduler mismatch busy cycle=%0d",cycles);
        if(frame_done[0]!==frame_done[1])$fatal(1,"scheduler mismatch frame_done cycle=%0d",cycles);
        if(deadline_error[0]!==deadline_error[1])$fatal(1,"scheduler mismatch deadline_error cycle=%0d",cycles);
        if(parameter_error[0]!==parameter_error[1])$fatal(1,"scheduler mismatch parameter_error cycle=%0d",cycles);
        if(alignment_error[0]!==alignment_error[1])$fatal(1,"scheduler mismatch alignment_error cycle=%0d",cycles);
        if(frame_cycles[0]!==frame_cycles[1])$fatal(1,"scheduler mismatch frame_cycles cycle=%0d",cycles);
        if(max_frame_cycles[0]!==max_frame_cycles[1])$fatal(1,"scheduler mismatch max_frame_cycles cycle=%0d",cycles);
        if(issued_count[0]!==issued_count[1])$fatal(1,"scheduler mismatch issued_count cycle=%0d",cycles);
        if(returned_count[0]!==returned_count[1])$fatal(1,"scheduler mismatch returned_count cycle=%0d",cycles);
        if(slot_ages[0]!==slot_ages[1])$fatal(1,"scheduler mismatch slot_ages cycle=%0d",cycles);
        if(prefetch_valid[0]!==prefetch_valid[1])$fatal(1,"scheduler mismatch prefetch_valid cycle=%0d",cycles);
        if(prefetch_slot[0]!==prefetch_slot[1])$fatal(1,"scheduler mismatch prefetch_slot cycle=%0d",cycles);
        if(prefetch_kind[0]!==prefetch_kind[1])$fatal(1,"scheduler mismatch prefetch_kind cycle=%0d",cycles);
        if(prefetch_group[0]!==prefetch_group[1])$fatal(1,"scheduler mismatch prefetch_group cycle=%0d",cycles);
        if(task_valid[0]!==task_valid[1])$fatal(1,"scheduler mismatch task_valid cycle=%0d",cycles);
        if(task_frame[0]!==task_frame[1])$fatal(1,"scheduler mismatch task_frame cycle=%0d",cycles);
        if(task_slot[0]!==task_slot[1])$fatal(1,"scheduler mismatch task_slot cycle=%0d",cycles);
        if(task_kind[0]!==task_kind[1])$fatal(1,"scheduler mismatch task_kind cycle=%0d",cycles);
        if(task_group[0]!==task_group[1])$fatal(1,"scheduler mismatch task_group cycle=%0d",cycles);
        if(task_generation[0]!==task_generation[1])$fatal(1,"scheduler mismatch task_generation cycle=%0d",cycles);
        if(task_age[0]!==task_age[1])$fatal(1,"scheduler mismatch task_age cycle=%0d",cycles);
        if(task_restart[0]!==task_restart[1])$fatal(1,"scheduler mismatch task_restart cycle=%0d",cycles);
        if(task_history[0]!==task_history[1])$fatal(1,"scheduler mismatch task_history cycle=%0d",cycles);
        if(return_accepted[0]!==return_accepted[1])$fatal(1,"scheduler mismatch return_accepted cycle=%0d",cycles);
        if(original.history_complete!==candidate.history_complete)$fatal(1,"history validity mismatch");
        if(original.owned!==candidate.owned)$fatal(1,"ownership mismatch");
        if(return_accepted[0])accepted=accepted+1;
    end
    task automatic launch;
        begin @(negedge clk);frame_tag=frame_tag+1;frame_start=1;@(negedge clk);frame_start=0;end
    endtask
    task automatic finish_frame;
        integer n;begin n=0;while(!frame_done[0]&&n<650)begin @(negedge clk);n=n+1;end
        if(!frame_done[0])$fatal(1,"scheduler frame timeout");frames=frames+1;repeat(3)@(negedge clk);end
    endtask
    task automatic clear;
        begin @(negedge clk);panic=1;repeat(2)@(negedge clk);panic=0;drop_returns=0;corrupt=0;repeat(3)@(negedge clk);end
    endtask
    initial begin
        for(integer j=0;j<32;j=j+1)begin kinds[j*2+:2]=j%4;generations[j*16+:16]=j+1;end
        repeat(5)@(negedge clk);rst_n=1;
        for(integer k=0;k<14;k=k+1)begin
            advance=k%2?32'haaaaaaaa:32'hffffffff;
            active=k%3==1?32'h0fffffff:32'hffffffff;
            if(k%4==0)for(integer j=0;j<32;j=j+3)generations[j*16+:16]=generations[j*16+:16]+1;
            launch();finish_frame();
        end
        active=0;launch();finish_frame();active=32'hffffffff;advance=32'hffffffff;
        for(integer k=0;k<3;k=k+1)begin
            launch();repeat(k==0?8:k==1?120:500)@(negedge clk);clear();launch();finish_frame();
        end
        launch();repeat(30)@(negedge clk);frame_start=1;@(negedge clk);frame_start=0;finish_frame();
        if(!deadline_error[0])$fatal(1,"busy frame was not rejected");clear();
        drop_returns=1;launch();finish_frame();
        if(!deadline_error[0]||candidate.history_complete!==0||candidate.owned!==0)$fatal(1,"timeout recovery did not clear ownership");
        clear();launch();finish_frame();
        if(cycles<10000||accepted<6000)$fatal(1,"scheduler test vacuous");
        complete_test("tb_scheduler_timing",cycles);
        $display("PASS tb_scheduler_timing frames=%0d cycles=%0d returns=%0d",frames,cycles,accepted);$finish;
    end
    initial begin #2000000;$fatal(1,"scheduler check timeout");end
endmodule
