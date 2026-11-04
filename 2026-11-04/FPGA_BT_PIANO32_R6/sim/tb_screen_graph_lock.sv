`timescale 1ns/1ps
module tb_screen_graph_lock;
    `include "sim/result.svh"
    reg clk=0,rst_n=0;always #10 clk=~clk;
    wire lock,tx;wire [5:0] address;
    mega138_screen_tx #(.CLKS_PER_BIT(8),.STARTUP_CYCLES(2),.UPDATE_CYCLES(100)) dut(
        .clk(clk),.rst_n(rst_n),.view(4'd7),.mode(3'd3),.test_kind(3'd0),
        .build_id(32'h12345678),.voice_mask(32'd0),.timeout_count(32'd0),.revision(32'd9),
        .voices(6'd0),.peak_voices(6'd0),.keys(16'd0),.flags(16'd0),.pressure(192'd0),
        .result(8'd0),.song_status(224'd0),.song_ready(1'b1),.ddr_ready(1'b1),
        .command_feedback(112'd0),.peaks(64'd0),.graph_ready(1'b1),.lock_granted(lock),
        .graph_data({10'd0,address}),.graph_lock(lock),.graph_address(address),.tx(tx));
    wire [7:0] b;wire bv;
    uart_rx #(.CLKS_PER_BIT(8)) monitor(.clk(clk),.rst_n(rst_n),.rx(tx),.data(b),.valid(bv),.framing_error());
    reg [127:0] prefix=0;integer position=0,held_cycles=0,releases=0;reg old_lock=0;
    reg seen_first=0,seen_last=0,seen_revision=0;
    always @(posedge clk)if(bv)begin
        if(b==8'hff)begin prefix<=0;position<=0;end
        else if(position<16)begin prefix[127-position*8-:8]<=b;position<=position+1;end
        if(b==8'h3d)case(prefix|(128'(b)<<(120-position*8)))
            {"rxG00.val=",48'd0}:seen_first<=1;
            {"rxG63.val=",48'd0}:seen_last<=1;
            {"rxFrame.val=",32'd0}:seen_revision<=1;
            default:;
        endcase
    end
    always @(negedge clk)if(rst_n)begin
        if(lock)begin held_cycles=held_cycles+1;
            if(held_cycles>200000)$fatal(1,"screen graph lock did not release");
        end else held_cycles=0;
        if(old_lock&&!lock)releases=releases+1;
        old_lock=lock;
    end
    initial begin
        repeat(4)@(negedge clk);rst_n=1;
        repeat(600000)begin
            @(negedge clk);
            if(releases==2)begin
                if(!seen_first||!seen_last||!seen_revision)$fatal(1,"screen graph UART fields missing");
                complete_test("tb_screen_graph_lock",5);
                $display("PASS tb_screen_graph_lock releases=%0d first=%b last=%b revision=%b",releases,seen_first,seen_last,seen_revision);$finish;
            end
        end
        $fatal(1,"screen graph cycles incomplete");
    end
endmodule
