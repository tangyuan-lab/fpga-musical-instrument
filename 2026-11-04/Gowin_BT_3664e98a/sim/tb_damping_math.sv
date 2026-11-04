`timescale 1ns/1ps
module tb_damping_math;
    `include "sim/result.svh"
    reg clk=0;always #10 clk=~clk;
    reg rst_n=0,iv=0,held=1,enabled=1;reg [23:0] loss=0;
    reg [255:0] coefficient=0;reg [127:0] state=0;
    reg [43:0] tag=0;reg [1:0] kind=0;
    wire valid;wire [127:0] result;wire [43:0] result_tag;
    reg [31:0] expected_main[0:15],expected_onset[0:15];integer checked=0;
    shared_modal_math #(.TAG_WIDTH(44),.DAMPING_ENABLE(1)) dut(
        .clk(clk),.rst_n(rst_n),.in_valid(iv),.in_tag(tag),.kind(kind),.first(1'b0),.held(held),.age(17'd40),
        .damping_active(enabled),.damping_loss(loss),.damping_native(coefficient[47:0]),.piano_pitch(32'h10000000),.drum_pitch(16'h8000),
        .coefficient(coefficient),.state(state),.out_valid(valid),.out_tag(result_tag),.out_kind(),
        .contribution(),.next_state(result),.quiet(),.quiet_bound(),.precommit_valid(),.precommit_tag(),.precommit_kind());
    function automatic [31:0] advance(input [31:0] level,input [23:0] native_loss,extra);
        reg [24:0] sum;reg [23:0] f;reg [63:0] product,drop;
        begin
            sum={1'b0,native_loss}+{1'b0,extra};f=sum[24]?24'hffffff:sum[23:0];
            product=64'(level)*64'(f);drop=(product+64'd8388608)>>24;
            if(drop==0)drop=1;
            advance=drop>=level ? 0:level-32'(drop);
        end
    endfunction
    task automatic vector(input [1:0] k,input bit h,en,input [23:0] l,native_a,native_b);
        reg [23:0] effective;
        begin
            @(negedge clk);kind=k;held=h;enabled=en;loss=l;iv=1;
            coefficient={128'd0,32'h01000000,32'h20000000,16'h4000,native_a,native_b};
            state={32'd0,32'h10000000,32'h10000000,32'h08000000};
            effective=en ? l:(k==0&&!h ? 24'd8192:0);
            expected_main[tag]=advance(32'h10000000,native_a,effective);
            expected_onset[tag]=advance(32'h08000000,native_b,effective);
            @(negedge clk);iv=0;tag=tag+1;repeat(9)@(negedge clk);
        end
    endtask
    always @(negedge clk)if(valid)begin
        if(result[63:32]!==expected_main[result_tag]||result[31:0]!==expected_onset[result_tag])
            $fatal(1,"damping rounding/saturation tag=%0d actual=%h expected=%h/%h",result_tag,result,expected_main[result_tag],expected_onset[result_tag]);
        checked=checked+1;
    end
    initial begin
        repeat(4)@(negedge clk);rst_n=1;
        vector(0,1,1,0,1000,2000);
        vector(0,0,1,20000,1000,2000);
        vector(3,0,1,20000,1000,2000);
        vector(3,1,1,5000,1000,2000); // palm contact while held
        vector(0,0,1,24'h800000,24'hffff00,24'hffff00); // saturate, never wrap
        vector(3,0,1,24'h800000,24'hffff00,24'hffff00);
        vector(0,0,0,0,1000,2000); // exact legacy piano release
        vector(3,0,0,0,1000,2000); // legacy plucked natural decay
        repeat(12)@(negedge clk);
        if(checked!=8)$fatal(1,"missing math vectors %0d",checked);
        complete_test("tb_damping_math",checked);$display("PASS tb_damping_math checked=%0d",checked);$finish;
    end
    initial begin #100000;$fatal(1,"damping math timeout");end
endmodule
