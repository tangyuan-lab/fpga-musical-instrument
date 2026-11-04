`timescale 1ns/1ps
`default_nettype none
module tb_fx_audio;
    `include "sim/result.svh"
    GSR GSR(.GSRI(1'b1));
    reg clk=0;always #10 clk=~clk;
    reg rst_n=0,clear=0,tick=0;
    reg signed [15:0] source=0;
    reg [6:0] dm=0,rm=0,fb=0;
    reg [7:0] cm=0;
    wire signed [15:0] effected,sent,chorused,final_pcm,dc,rc,cc;
    wire ev,ec,cv,cl,mv,mc;
    audio_effects #(.SEPARATE_SEND(1)) fx(.clk(clk),.rst_n(rst_n),.clear(clear),.sample_tick(tick),
        .dry(source),.send_in(source),.delay_mix(dm),.reverb_mix(rm),.feedback(fb),.delay_samples(15'd12000),
        .wet(effected),.send_chain(sent),.valid(ev),.clipped(ec),.delay_component(dc),.reverb_component(rc));
    audio_chorus #(.SEPARATE_SEND(1)) ch(.clk(clk),.rst_n(rst_n),.clear(clear),.sample_tick(tick),
        .dry(effected),.send_in(sent),.mix(cm),.depth(8'd128),.rate(8'd64),
        .out(chorused),.valid(cv),.clipped(cl),.wet_component(cc));
    pcm_master_gain #(.LIMITER_CAPABLE(1)) master(.clk(clk),.rst_n(rst_n),.clear(clear),.sample_tick(tick),
        .sample_in(chorused),.boost(2'd0),.limiter_enabled(1'b0),.limiter_release(2'd1),
        .sample_out(final_pcm),.valid(mv),.clipped(mc),.limited(),.limiter_gain(),.peak_in(),.peak_out(),.gain_q8());
    localparam integer SAMPLES=192000;
    reg signed [15:0] stimulus[0:SAMPLES-1];
    reg [2047:0] input_path,output_path;
    integer output_file,checks=0,delay_nonzero=0,reverb_nonzero=0,chorus_nonzero=0;
    task automatic frame(input integer x);
        begin
            @(negedge clk);source=x;tick=1;@(negedge clk);tick=0;
            repeat(9)@(negedge clk);
            if((^{effected,chorused,final_pcm,dc,rc,cc})===1'bx || ec||cl||mc)
                $fatal(1,"FX_AUDIO X/clipped");
        end
    endtask
    initial begin
        if(!$value$plusargs("INPUT=%s",input_path)||!$value$plusargs("OUT=%s",output_path))$fatal(1,"FX_AUDIO paths");
        $readmemh(input_path,stimulus);output_file=$fopen(output_path,"w");
        if(!output_file)$fatal(1,"FX_AUDIO output");
        repeat(4)@(negedge clk);rst_n=1;
        for(integer c=0;c<4;c=c+1)begin
            dm=c==1?80:0;rm=c==2?96:0;fb=c==1?64:0;cm=c==3?192:0;
            clear=1;@(negedge clk);clear=0;repeat(260)frame(0);
            for(integer i=0;i<SAMPLES;i=i+1)begin
                frame(stimulus[i]);
                if(c==1&&dc!=0)delay_nonzero=delay_nonzero+1;
                if(c==2&&rc!=0)reverb_nonzero=reverb_nonzero+1;
                if(c==3&&cc!=0)chorus_nonzero=chorus_nonzero+1;
                $fwrite(output_file,"%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d\n",c,i,source,final_pcm,dc,rc,cc,effected);
                checks=checks+1;
            end
        end
        $fclose(output_file);
        if(delay_nonzero<1000||reverb_nonzero<1000||chorus_nonzero<1000)$fatal(1,"FX_AUDIO missing_effect %0d %0d %0d",delay_nonzero,reverb_nonzero,chorus_nonzero);
        complete_test("tb_fx_audio",checks);
        $display("PASS tb_fx_audio samples=%0d delay=%0d reverb=%0d chorus=%0d",checks,delay_nonzero,reverb_nonzero,chorus_nonzero);$finish;
    end
    initial begin #240000000;$fatal(1,"FX_AUDIO timeout");end
endmodule
`default_nettype wire
