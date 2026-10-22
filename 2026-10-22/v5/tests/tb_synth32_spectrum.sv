`timescale 1ns/1ps
module tb_synth32_spectrum;
    reg clk=0,rst_n=0,tick=0,valid=0;always #10 clk=~clk;
    integer cycle=0,index,file;
    always @(negedge clk) begin tick=cycle==1023;cycle=(cycle+1)%1024;end
    reg [15:0] identity=0;reg [6:0] note=60;wire ready,deadline;
    wire signed [15:0] pcm;wire [5:0] voices;wire [31:0] mask;
    synth32 dut(.clk(clk),.rst_n(rst_n),.sample_tick(tick),.panic(1'b0),
        .command_valid(valid),.command_ready(ready),.command_op(2'd1),.command_source(2'd0),
        .command_id(identity),.command_note(note),.command_velocity(7'd100),.command_timbre(4'd1),.custom_ready(8'd0),
        .bend(14'sd0),.vibrato_depth(8'd0),.vibrato_rate(8'd5),.table_write(1'b0),.table_address(11'd0),.table_data(16'sd0),
        .parameter_write(1'b0),.parameter_bank(4'd0),.attack_step(12'd1),.decay_step(12'd1),.sustain_level(12'd0),.release_step(12'd1),
        .pcm(pcm),.voice_count(voices),.active_mask(mask),.deadline_error(deadline));
    initial begin
        repeat(5) @(negedge clk);rst_n=1;
        for(index=0;index<4;index=index+1) begin
            @(negedge clk);while(!ready) @(negedge clk);identity=index;
            case(index) 0:note=60;1:note=64;2:note=67;3:note=71;endcase
            valid=1;@(negedge clk);valid=0;while(!ready) @(negedge clk);
        end
        repeat(512) @(posedge tick);
        file=$fopen("build/tests/synth32_four_frequency_samples.csv","w");
        for(index=0;index<8192;index=index+1) begin
            @(posedge tick);repeat(230) @(negedge clk);$fdisplay(file,"%0d",pcm);
            if(voices!=4 || mask!=15 || deadline) $fatal(1,"four-frequency engine state failed");
        end
        $fclose(file);$display("PASS tb_synth32_spectrum 8192 actual RTL samples");$finish;
    end
endmodule
