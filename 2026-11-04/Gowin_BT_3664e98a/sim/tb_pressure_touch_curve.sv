`timescale 1ns/1ps
module tb_pressure_touch_curve;
    reg [6:0] raw=0,minimum=8;
    reg [1:0] sensitivity=0,curve=0;
    wire [6:0] velocity;
    pressure_touch_curve dut(raw,sensitivity,curve,minimum,velocity);
    `include "sim/result.svh"
    integer checks=0,previous,expected;
    initial begin
        if($test$plusargs("MUTATE_TOUCH"))force dut.velocity=7'd0;
        for(integer s=0;s<4;s=s+1)for(integer c=0;c<3;c=c+1)
            for(integer m=8;m<=64;m=m+8)begin
                sensitivity=s;curve=c;minimum=m;previous=-1;
                for(integer x=0;x<128;x=x+1)begin
                    raw=x;#1;
                    if((^velocity)===1'bx||velocity<minimum||velocity>127||(x>0&&velocity<previous))
                        $fatal(1,"pressure curve range/monotonic s=%0d c=%0d m=%0d x=%0d y=%0d",s,c,m,x,velocity);
                    if(x==127&&velocity!=127)$fatal(1,"pressure full scale not preserved");
                    if(s==0&&c==0&&m==8&&velocity!=(x<8?8:x))$fatal(1,"legacy touch compatibility");
                    previous=velocity;checks=checks+1;
                end
            end
        sensitivity=1;curve=1;minimum=16;
        // 现场短按压力239/1247，现有采集器取7位后分别为7/38。
        raw=7;#1;if(velocity!=28)$fatal(1,"soft touch low force anchor");
        raw=38;#1;if(velocity!=102)$fatal(1,"soft touch high force anchor");
        raw=0;#1;if(velocity!=16)$fatal(1,"touch minimum anchor");
        curve=2;sensitivity=0;minimum=8;
        raw=32;#1;if(velocity!=16)$fatal(1,"firm curve anchor");
        raw=96;#1;if(velocity!=80)$fatal(1,"firm curve strong anchor");
        complete_test("tb_pressure_touch_curve",checks+5);
        $display("PASS tb_pressure_touch_curve checks=%0d",checks+5);$finish;
    end
    initial begin #1000000;$fatal(1,"pressure touch unit timeout");end
endmodule
