`timescale 1ns/1ps
`include "sim/backend_reference.sv"
module tb_backend_pipeline;
    `include "sim/result.svh"
    GSR GSR(.GSRI(1'b1));
    reg clk=0;always #10 clk=~clk;
    reg rst_n=0,panic=0,tick=0;
    reg [31:0] active=32'hffffffff,held=32'hffffffff;
    reg [63:0] kinds=0;reg [511:0] generation=0;
    reg [159:0] banks=0;reg [1023:0] pitches={32{32'h10000000}};
    wire bo,bc,so,sc,lo,lc,eo,ec,ao,ac,vo,vc,qo,qc;
    wire [4:0] slo,slc;wire [1:0] ko,kc;wire [15:0] go,gc,zo,zc;
    wire signed [63:0] sumo,sumc;wire [543:0] ages_o,ages_c;
    wire [10:0] fco,fcc;
    shared_modal_backend32_reference #(.COMPACT_SCHEDULER(1)) original(
      .clk(clk),.rst_n(rst_n),.sample_tick(tick),.panic(panic),.active(active),.held(held),.kinds(kinds),
      .generation(generation),.piano_banks(banks),.piano_pitches(pitches),.piano_pitch_addr(),.piano_pitch_word(32'd0),
      .drum_indices(224'd0),.drum_pitches(512'd0),.advance_exc_mask(32'd0),
      .busy(bo),.sample_valid(so),.deadline_error(lo),.parameter_error(eo),.alignment_error(ao),
      .raw_valid(vo),.raw_slot(slo),.raw_kind(ko),.raw_generation(go),.raw_sum(sumo),.raw_quiet(qo),
      .raw_quiet_bound(zo),.slot_ages(ages_o),.frame_cycles(fco),.max_frame_cycles());
    shared_modal_backend32 #(.COMPACT_SCHEDULER(1)) candidate(
      .clk(clk),.rst_n(rst_n),.sample_tick(tick),.panic(panic),.active(active),.held(held),.kinds(kinds),
      .generation(generation),.piano_banks(banks),.piano_pitches(pitches),.piano_pitch_addr(),.piano_pitch_word(32'd0),
      .drum_indices(224'd0),.drum_pitches(512'd0),.advance_exc_mask(32'd0),
      .busy(bc),.sample_valid(sc),.deadline_error(lc),.parameter_error(ec),.alignment_error(ac),
      .raw_valid(vc),.raw_slot(slc),.raw_kind(kc),.raw_generation(gc),.raw_sum(sumc),.raw_quiet(qc),
      .raw_quiet_bound(zc),.slot_ages(ages_c),.frame_cycles(fcc),.max_frame_cycles());
    integer outputs=0,writes=0,frames=0;reg [31:0] nonzero=0;
    reg reference_raw_valid=0;reg [103:0] reference_raw;
    always @(posedge clk)begin
      if(!rst_n||panic)reference_raw_valid<=0;
      else begin reference_raw_valid<=vo;if(vo)reference_raw<={slo,ko,go,sumo,qo,zo};end
    end
    always @(negedge clk)if(rst_n)begin
      if((^{bo,bc,so,sc,lo,lc,eo,ec,ao,ac,vo,vc})===1'bx)$fatal(1,"backend control X");
      if({bo,so,lo,eo,ao,fco,ages_o}!=={bc,sc,lc,ec,ac,fcc,ages_c})$fatal(1,"backend control mismatch cycles %0d/%0d",fco,fcc);
      if(reference_raw_valid!==vc)$fatal(1,"backend reduction latency differs from one clock");
      if(lo||eo||ao||lc||ec||ac)$fatal(1,"backend error flags");
      if(vc)begin
        if((^{slc,kc,gc,sumc,qc,zc})===1'bx)$fatal(1,"backend candidate X");
        if(reference_raw!=={slc,kc,gc,sumc,qc,zc})$fatal(1,"backend raw mismatch slot=%0d",slc);
        outputs=outputs+1;if(sumc!=0)nonzero[slc]=1;
      end
      if(original.return_accepted!==candidate.return_accepted)$fatal(1,"backend write enable mismatch");
      if(original.return_accepted)begin
        if((^candidate.return_history)===1'bx)$fatal(1,"backend history X");
        if({original.return_slot,original.return_group,original.return_history}!=={candidate.return_slot,candidate.return_group,candidate.return_history})$fatal(1,"backend history mismatch");
        writes=writes+1;
      end
      if(panic&&(vo||vc||original.return_accepted||candidate.return_accepted))$fatal(1,"backend cancelled result");
    end
    task automatic launch;
      begin
        @(negedge clk);if(bo||bc)$fatal(1,"backend busy launch");tick=1;
        @(negedge clk);tick=0;
      end
    endtask
    task automatic frame;
      integer n;
      begin launch();n=0;
        while(so!==1'b1&&n<700)begin @(negedge clk);n=n+1;end
        if(so!==1'b1||sc!==1'b1)$fatal(1,"backend completion timeout");
        frames=frames+1;@(negedge clk);
      end
    endtask
    initial begin
      for(integer i=0;i<32;i=i+1)begin kinds[i*2+:2]=i%2?3:0;generation[i*16+:16]=i+1;banks[i*5+:5]=i%17;end
      repeat(4)@(negedge clk);rst_n=1;
      repeat(8)frame();
      for(integer i=0;i<32;i=i+3)generation[i*16+:16]=generation[i*16+:16]+1;
      held=32'h55aa55aa;repeat(4)frame();
      for(integer k=0;k<3;k=k+1)begin
        launch();repeat(k==0?20:k==1?100:500)@(negedge clk);
        if(!bo||!bc)$fatal(1,"cancel not inflight");panic=1;
        repeat(2)@(negedge clk);panic=0;
        repeat(3)frame();
      end
      active=0;repeat(2)frame();
      if(outputs<600||writes<9000||nonzero!==32'hffffffff)$fatal(1,"backend vacuous outputs=%0d writes=%0d nonzero=%h",outputs,writes,nonzero);
      complete_test("tb_backend_pipeline",outputs+writes);$display("PASS tb_backend_pipeline frames=%0d outputs=%0d writes=%0d",frames,outputs,writes);$finish;
    end
    initial begin #3000000;$fatal(1,"backend timeout");end
endmodule
