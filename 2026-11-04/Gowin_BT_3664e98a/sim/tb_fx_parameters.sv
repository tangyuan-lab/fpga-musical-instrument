`timescale 1ns/1ps
`default_nettype none
module tb_fx_parameters;
    `include "sim/result.svh"
    reg clk=0;always #10 clk=~clk;
    reg rst_n=0,sample_tick=0,app_valid=0;reg [7:0] app_op=0;reg [31:0] app_value=0;
    wire [7:0] dm,rm,cm,dep,rate,fb;wire [14:0] delay_samples;wire [2:0] preview;
    audio_params dut(.clk(clk),.rst_n(rst_n),.sample_tick(sample_tick),.cmd_valid(1'b0),.cmd_op(8'd0),.cmd_value(8'd0),
        .app_valid(app_valid),.app_op(app_op),.app_value(app_value),.app_aux(32'd0),.piano_volume_in(8'd100),.drum_volume_in(8'd0),
        .delay_mix(dm),.reverb_mix(rm),.chorus_mix(cm),.chorus_depth(dep),.chorus_rate(rate),.feedback(fb),
        .delay_samples(delay_samples),.fx_preview(preview));
    integer checks=0;integer before_v[0:5];
    task automatic write(input [7:0] op,input [31:0] value);
        begin app_valid=1;app_op=op;app_value=value;@(negedge clk);app_valid=0;@(negedge clk);end
    endtask
    task automatic frames(input integer count);
        begin
            for(integer i=0;i<count;i=i+1)begin
                before_v[0]=dm;before_v[1]=rm;before_v[2]=cm;before_v[3]=dep;before_v[4]=rate;before_v[5]=fb;
                sample_tick=1;@(negedge clk);sample_tick=0;
                if(dm>before_v[0]+1||dm+1<before_v[0]||rm>before_v[1]+1||rm+1<before_v[1]||
                   cm>before_v[2]+1||cm+1<before_v[2]||dep>before_v[3]+1||dep+1<before_v[3]||
                   rate>before_v[4]+1||rate+1<before_v[4]||fb>before_v[5]+1||fb+1<before_v[5])
                    $fatal(1,"FX_PARAMETERS abrupt change");
                before_v[0]=dm;before_v[1]=rm;before_v[2]=cm;before_v[3]=dep;before_v[4]=rate;before_v[5]=fb;
                repeat(3)@(negedge clk);
                if(dm!=before_v[0]||rm!=before_v[1]||cm!=before_v[2]||dep!=before_v[3]||rate!=before_v[4]||fb!=before_v[5])
                    $fatal(1,"FX_PARAMETERS changed outside sample boundary");
                checks=checks+2;
            end
        end
    endtask
    task automatic expect_values(input integer d,r,c,h,s,f,t);
        if(dm!=d||rm!=r||cm!=c||dep!=h||rate!=s||fb!=f||delay_samples!=t)
            $fatal(1,"FX_PARAMETERS target/restore %0d/%0d/%0d/%0d/%0d/%0d/%0d",dm,rm,cm,dep,rate,fb,delay_samples);
    endtask
    initial begin
        repeat(3)@(negedge clk);rst_n=1;
        write(19,37);write(20,43);write(41,55);write(42,255);write(43,200);write(22,40);write(47,600);
        frames(300);expect_values(37,43,55,255,200,40,28800);
        write(46,1);frames(300);expect_values(0,0,0,255,200,40,28800);
        write(46,2);frames(300);expect_values(80,0,0,255,200,64,12000);
        write(46,3);frames(300);expect_values(0,96,0,255,200,40,28800);
        write(46,4);frames(300);expect_values(0,0,192,128,64,40,28800);
        write(46,0);frames(300);expect_values(37,43,55,255,200,40,28800);
        write(46,5);write(47,49);frames(2);expect_values(37,43,55,255,200,40,28800);
        if(preview!=0)$fatal(1,"FX_PARAMETERS invalid preview changed state");
        complete_test("tb_fx_parameters",checks);$display("PASS tb_fx_parameters smooth_sample_boundary_and_user_restore checks=%0d",checks);$finish;
    end
    initial begin #1000000;$fatal(1,"FX_PARAMETERS timeout");end
endmodule
`default_nettype wire
