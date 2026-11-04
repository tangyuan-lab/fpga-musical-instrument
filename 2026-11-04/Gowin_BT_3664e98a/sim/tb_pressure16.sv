`timescale 1ns/1ps
module tb_pressure16;
    `include "sim/result.svh"
    reg clk=0;always #10 clk=~clk;
    reg rst_n=0,adc_ready=1,valid=0;reg [191:0] samples=0;reg [15:0] enable=16'hffff;
    wire calibrated,busy,overrun;wire [191:0] baseline,pressure;wire [127:0] velocity;
    wire [15:0] down,on_pulse,off_pulse;wire [4:0] count;
    pressure_key_matrix_serial #(.KEY_COUNT(16),.CALIBRATION_SAMPLES(4),.FILTER_SHIFT(0),.PRESS_FULL(4095),.ACTIVE_LOW_MASK(16'd0)) dut(
        .clk(clk),.rst_n(rst_n),.adc_ready(adc_ready),.sample_frame_valid(valid),.adc_samples(samples),.key_enable(enable),
        .calibrated(calibrated),.baseline_values(baseline),.pressure_values(pressure),.velocity_values(velocity),.key_down(down),
        .key_on_pulse(on_pulse),.key_off_pulse(off_pulse),.active_key_count(count),.frame_busy(busy),.frame_overrun(overrun));
    integer max_cycles=0,frame_count=0;reg [15:0] seen_on,seen_off;reg [127:0] first_velocity;
    task automatic frame(input integer value);
        integer n;
        begin
            @(negedge clk);for(integer k=0;k<16;k=k+1)samples[k*12+:12]=value+k;
            valid=1;@(negedge clk);valid=0;seen_on=0;seen_off=0;n=0;
            while(busy&&n<64)begin @(negedge clk);n=n+1;seen_on=seen_on|on_pulse;seen_off=seen_off|off_pulse;end
            if(busy||n>49)$fatal(1,"pressure processing deadline %0d",n);
            if((^{calibrated,baseline,pressure,velocity,down,count})===1'bx)$fatal(1,"pressure X");
            if(n>max_cycles)max_cycles=n;frame_count=frame_count+1;
            @(negedge clk);
        end
    endtask
    initial begin
        repeat(4)@(negedge clk);rst_n=1;
        repeat(4)frame(1000);
        if(!calibrated||baseline[11:0]!==1000)$fatal(1,"pressure calibration");
        frame(1500);if(down!==16'hffff||count!==16||seen_on!==16'hffff)$fatal(1,"pressure full16 missing");
        first_velocity=velocity;frame(2500);
        for(integer k=0;k<16;k=k+1)if(velocity[k*8+:8]<=first_velocity[k*8+:8])$fatal(1,"continuous pressure did not update %0d",k);
        if(seen_on!=0||seen_off!=0)$fatal(1,"continuous pressure retriggered");
        frame(1000);if(down!=0||count!=0||seen_off!==16'hffff)$fatal(1,"pressure release");
        frame(2000);enable=16'h00ff;repeat(3)@(negedge clk);
        if(pressure[191:96]!==0)$fatal(1,"disabled pressure not masked");
        adc_ready=0;repeat(3)@(negedge clk);
        if(down!=0||pressure!=0||velocity!=0)$fatal(1,"ADC dropout not released");
        complete_test("tb_pressure16",8);$display("PASS tb_pressure16 frames=%0d max_cycles=%0d continuous/dropout/mask",frame_count,max_cycles);$finish;
    end
    initial begin #1000000;$fatal(1,"pressure test timeout");end
endmodule
