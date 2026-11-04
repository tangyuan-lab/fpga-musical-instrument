`timescale 1ns/1ps
module tb_pressure_max16;
    reg clk=0,rst_n=0;always #10 clk=~clk;
    reg [191:0] values=0;wire [11:0] maximum;
    pressure_max16 dut(.clk(clk),.rst_n(rst_n),.values(values),.maximum(maximum));
    reg [11:0] history[0:3];reg [11:0] expected;integer i,j,trial;
    always @(posedge clk) begin
        if(!rst_n) for(j=0;j<4;j=j+1) history[j]=0;
        else begin
            expected=0;for(j=0;j<16;j=j+1) if(values[j*12+:12]>expected) expected=values[j*12+:12];
            for(j=3;j>0;j=j-1) history[j]=history[j-1];history[0]=expected;
            #1;if(maximum!==history[3]) $fatal(1,"maximum pipeline mismatch actual=%h expected=%h",maximum,history[3]);
        end
    end
    initial begin
        repeat(3) @(negedge clk);rst_n=1;
        for(trial=0;trial<100;trial=trial+1) begin
            @(negedge clk);for(i=0;i<16;i=i+1) values[i*12+:12]=$random;
            if(trial<16) begin values=0;values[trial*12+:12]=4095;end
        end
        values=0;repeat(5) @(negedge clk);
        $display("PASS tb_pressure_max16 all16/coherent_four_stage/zero");$finish;
    end
endmodule
