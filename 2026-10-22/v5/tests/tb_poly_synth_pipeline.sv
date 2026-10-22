`timescale 1ns/1ps
// 验证DSP流水线在不同相位、音色混合量和力度下的数值一致性及停止静音。
module tb_poly_synth_pipeline;
    reg clk=0, rst_n=0;
    always #10 clk=~clk;
    wire signed [15:0] pcm;
    reg [31:0] phase_value;
    reg [7:0] blend_value;
    reg [12:0] level_value;
    poly_synth_voice dut(.clk(clk),.rst_n(rst_n),.sample_tick(1'b0),.gate(1'b0),
        .retrigger(1'b0),.timbre(1'b0),.phase_step(32'd0),.target_level(13'd0),
        .sample_out(pcm),.current_level(),.timbre_blend(),.idle());
    integer p,b,l,folded,triangle,square,wave,expected,checks,blend_int,level_int;
    integer history[0:4];
    function [31:0] phase_case(input integer index);
        case(index)
            0: phase_case=32'h00000000;
            1: phase_case=32'h12340000;
            2: phase_case=32'h40000000;
            3: phase_case=32'h7fff0000;
            4: phase_case=32'h80000000;
            5: phase_case=32'h92340000;
            6: phase_case=32'hc0000000;
            default: phase_case=32'hffff0000;
        endcase
    endfunction
    function [7:0] blend_case(input integer index);
        case(index)
            0: blend_case=0;
            1: blend_case=1;
            2: blend_case=128;
            3: blend_case=254;
            default: blend_case=255;
        endcase
    endfunction
    function [12:0] level_case(input integer index);
        case(index)
            0: level_case=0;
            1: level_case=4;
            2: level_case=16;
            3: level_case=2048;
            default: level_case=4080;
        endcase
    endfunction
    initial begin
        checks=0;
        repeat(3) @(negedge clk);rst_n=1;
        force dut.phase_acc=phase_value;
        force dut.timbre_blend=blend_value;
        force dut.current_level=level_value;
        for(p=0;p<8;p=p+1) for(b=0;b<5;b=b+1) for(l=0;l<5;l=l+1) begin
            phase_value=phase_case(p);blend_value=blend_case(b);level_value=level_case(l);
            folded=(phase_value>>16)&32767;
            if(phase_value[31]) folded=32767-folded;
            triangle=(folded-16384)>>>2;
            square=phase_value[31] ? 2304 : -2304;
            // 转成有符号整数，防止测试参考模型因reg的无符号传播而逻辑右移。
            blend_int=blend_value;level_int=level_value;
            wave=blend_int==255 ? square : triangle+(((square-triangle)*blend_int)>>>8);
            expected=(wave*level_int)>>>12;
            repeat(6) @(negedge clk);
            if(pcm!==expected[15:0]) $fatal(1,"DSP alignment p=%0d b=%0d level=%0d pcm=%0d expected=%0d",p,blend_value,level_value,pcm,expected);
            checks=checks+1;
        end
        // 每拍同时改变相位和音色，检查配套数据/全方波选择标志的真实时序对齐。
        // 力度固定为一半，独立整数参考波形经五拍延迟队列后与PCM逐拍比较。
        level_value=2048;
        for(p=0;p<5;p=p+1) history[p]=0;
        for(p=0;p<64;p=p+1) begin
            phase_value=phase_case(p%8);blend_value=blend_case((p*3)%5);
            folded=(phase_value>>16)&32767;
            if(phase_value[31]) folded=32767-folded;
            triangle=(folded-16384)>>>2;
            square=phase_value[31] ? 2304 : -2304;
            blend_int=blend_value;
            wave=blend_int==255 ? square : triangle+(((square-triangle)*blend_int)>>>8);
            expected=(wave*2048)>>>12;
            @(negedge clk);
            for(b=4;b>0;b=b-1) history[b]=history[b-1];
            history[0]=expected;
            if(p>=4) begin
                if(pcm!==history[4][15:0]) $fatal(1,"dynamic pipeline alignment cycle=%0d pcm=%0d expected=%0d",p,pcm,history[4]);
                checks=checks+1;
            end
        end
        release dut.phase_acc;release dut.timbre_blend;release dut.current_level;
        #3 rst_n=0;#1;
        if(pcm!==0) $fatal(1,"stop/reset did not immediately silence PCM");
        repeat(8) @(negedge clk);rst_n=1;
        repeat(8) @(negedge clk);
        if(pcm!==0) $fatal(1,"stale pipeline output after reset");
        $display("PASS tb_poly_synth_pipeline %0d static/dynamic signed PCM checks, reset silence",checks);
        $finish;
    end
    initial begin #1000000;$fatal(1,"timeout");end
endmodule
