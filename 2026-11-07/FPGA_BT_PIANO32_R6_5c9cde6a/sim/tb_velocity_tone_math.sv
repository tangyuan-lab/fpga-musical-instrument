`timescale 1ns/1ps
module tb_velocity_tone_math;
    `include "sim/result.svh"
    reg clk=0;always #10 clk=~clk;
    reg rst_n=0,iv=0,first=1;reg [1:0] kind=0,profile=0;reg [6:0] velocity=0;
    reg [31:0] frequency=0;wire [23:0] gain;
    reg [255:0] coefficient=0;reg [127:0] state=0;reg [43:0] tag=0;
    wire valid;wire [43:0] output_tag;wire [127:0] result;
    piano_velocity_gain map(.velocity(velocity),.profile(profile),.native_frequency(frequency),.gain(gain));
    shared_modal_math #(.TAG_WIDTH(44),.DAMPING_ENABLE(1),.VELOCITY_TONE_ENABLE(1)) dut(
        .clk(clk),.rst_n(rst_n),.in_valid(iv),.in_tag(tag),.kind(kind),.first(first),.held(1'b0),.age(17'd100),
        .damping_active(1'b1),.damping_loss(24'd37),.damping_native(coefficient[47:0]),
        .excitation_active(profile!=0),.excitation_gain(gain),.piano_pitch(32'h10000000),.drum_pitch(16'h8000),
        .coefficient(coefficient),.state(state),.out_valid(valid),.out_tag(output_tag),.out_kind(),
        .contribution(),.next_state(result),.quiet(),.quiet_bound(),.precommit_valid(),.precommit_tag(),.precommit_kind());
    function automatic [23:0] reference_gain(input integer v,p,input [31:0] f);
        longint unsigned numerator,denominator;
        begin
            numerator=1;denominator=1;
            if(p!=0&&f>=223696213)case(p)
                1:begin numerator=128+v+1;denominator=256;end
                2:begin numerator=128+7*(v+1);denominator=1024;end
                3:begin numerator=128+31*(v+1);denominator=4096;end
            endcase
            else if(p!=0&&f>=53687091)case(p)
                1:begin numerator=896+v+1;denominator=1024;end
                2:begin numerator=384+v+1;denominator=512;end
                3:begin numerator=128+v+1;denominator=256;end
            endcase
            reference_gain=24'(64'd8388608*numerator/denominator);
        end
    endfunction
    reg [31:0] expected_main[0:4095],expected_onset[0:4095],expected_phase[0:4095];
    integer sent=0,checked=0,gain_checks=0;
    function automatic [31:0] decay(input [31:0] level,input integer loss);
        longint unsigned drop;
        begin drop=(64'(level)*64'(loss)+8388608)/16777216;if(drop==0)drop=1;
            decay=drop>=level ? 0:level-32'(drop);end
    endfunction
    task automatic vector(input integer v,p,input [31:0] f,input bit init,input [1:0] k,input [15:0] amplitude);
        longint unsigned scaled;reg [31:0] seed;
        begin
            @(negedge clk);iv=1;velocity=v;profile=p;frequency=f;first=init;kind=k;tag=sent;
            coefficient={128'd0,f,32'h12345678,amplitude,24'd1024,24'd2048};
            state={32'd0,32'h08000000,32'h12345678,32'h01234567};
            seed={amplitude,16'd0};
            scaled=(64'(seed)*64'(reference_gain(v,p,f))+4194304)/8388608;
            expected_main[sent]=init ? ((k==0&&p!=0)?32'(scaled):seed):decay(state[63:32],1061);
            expected_onset[sent]=init ? expected_main[sent]:decay(state[31:0],2085);
            expected_phase[sent]=init ? 32'h12345678:32'h08000000+f;sent=sent+1;
        end
    endtask
    always @(negedge clk)if(valid)begin
        if({result[95:64],result[63:32],result[31:0]}!=={expected_phase[output_tag],expected_main[output_tag],expected_onset[output_tag]})
            $fatal(1,"velocity seed/rounding/follow-up mismatch tag=%0d actual=%h",output_tag,result);
        checked=checked+1;
    end
    reg [31:0] bands[0:5];reg [23:0] previous;
    initial begin
        bands[0]=0;bands[1]=53687090;bands[2]=53687091;bands[3]=223696212;bands[4]=223696213;bands[5]=32'h70000000;
        repeat(4)@(negedge clk);rst_n=1;
        for(integer b=0;b<6;b=b+1)for(integer p=0;p<4;p=p+1)begin
            previous=0;
            for(integer v=0;v<128;v=v+1)begin
                velocity=v;profile=p;frequency=bands[b];#1;
                if(gain!==reference_gain(v,p,bands[b])||gain>8388608||gain<previous)$fatal(1,"gain curve/bounds v=%0d p=%0d band=%0d",v,p,b);
                previous=gain;gain_checks=gain_checks+1;
            end
            if(gain!==8388608)$fatal(1,"maximum velocity is not exact unity");
        end
        for(integer p=0;p<4;p=p+1)for(integer b=0;b<6;b=b+1)for(integer v=1;v<128;v=v+31)begin
            vector(v,p,bands[b],1,0,16'hffff);
            vector(v,p,bands[b],0,0,16'h1234);
            vector(v,p,bands[b],1,3,16'h1234);
        end
        vector(32,3,223696213,1,0,0);vector(32,3,223696213,1,0,1);
        for(integer p=0;p<4;p=p+1)vector(127,p,223696213,1,0,16'hffff);
        @(negedge clk);iv=0;repeat(12)@(negedge clk);
        if(checked!=sent||gain_checks!=3072)$fatal(1,"missing vectors");
        complete_test("tb_velocity_tone_math",checked+gain_checks);
        $display("PASS tb_velocity_tone_math gain_checks=%0d math_vectors=%0d",gain_checks,checked);$finish;
    end
    initial begin #1000000;$fatal(1,"velocity math timeout");end
endmodule
