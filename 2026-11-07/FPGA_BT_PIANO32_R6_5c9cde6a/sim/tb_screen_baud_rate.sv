`timescale 1ns/1ps
// Real 50MHz / divider109 screen TX, decoded at both 109 and the reported 434.
module tb_screen_baud_rate #(parameter integer TX_DIV=109,EXPECTED_RX_DIV=109);
    `include "sim/result.svh"
    reg clk=0,rst_n=0;always #10 clk=~clk;
    wire tx,lock;wire [5:0] address;reg [31:0] revision=9;reg previous_lock=0;
    mega138_screen_tx #(.CLKS_PER_BIT(TX_DIV),.STARTUP_CYCLES(2)) dut(
        .clk(clk),.rst_n(rst_n),.view(4'd7),.mode(3'd3),.test_kind(3'd0),
        .build_id(32'he06439bf),.voice_mask(32'd3),.timeout_count(32'd0),.revision(revision),
        .voices(6'd2),.peak_voices(6'd28),.keys(16'd1),.flags(16'd0),.pressure(192'd0),
        .result(8'd0),.song_status(224'd0),.song_ready(1'b1),.ddr_ready(1'b1),
        .command_feedback(112'd0),.peaks(64'd0),.graph_ready(1'b1),.lock_granted(lock),
        .graph_data({address,10'd0}),.graph_lock(lock),.graph_address(address),.tx(tx));
    wire [7:0] good_byte,bad_byte;wire good_valid,bad_valid,bad_error;
    uart_rx #(.CLKS_PER_BIT(EXPECTED_RX_DIV)) good(.clk(clk),.rst_n(rst_n),.rx(tx),.data(good_byte),.valid(good_valid),.framing_error());
    uart_rx #(.CLKS_PER_BIT(434)) wrong(.clk(clk),.rst_n(rst_n),.rx(tx),.data(bad_byte),.valid(bad_valid),.framing_error(bad_error));
    reg [127:0] good_prefix=0,bad_prefix=0;integer good_pos=0,bad_pos=0,good_ff=0,bad_ff=0;
    reg good_frame=0,bad_frame=0;integer good_frames=0,bad_frames=0,framing_errors=0,good_bytes=0;
    time first_frame=0,last_frame=0,period_ns=0;
    always @(posedge clk)if(rst_n)begin
        previous_lock<=lock;
        if(previous_lock&&!lock)revision<=revision+1;
        if(bad_error)framing_errors=framing_errors+1;
        if(good_valid)begin
            good_bytes=good_bytes+1;
            if(good_byte==8'hff)begin
                good_ff=good_ff+1;
                if(good_ff==3)begin
                    if(good_frame)begin
                        good_frames=good_frames+1;
                        if(first_frame==0)first_frame=$time;
                        else begin period_ns=$time-last_frame;$display("SCREEN_FRAME_PERIOD_NS=%0d",period_ns);end
                        last_frame=$time;
                    end
                    good_ff=0;good_frame=0;good_pos=0;good_prefix=0;
                end
            end else begin
                good_ff=0;
                if(good_pos<16)begin good_prefix[127-good_pos*8-:8]=good_byte;good_pos=good_pos+1;end
                if(good_prefix=={"rxFrame.val=",32'd0})good_frame=1;
            end
        end
        if(bad_valid)begin
            if(bad_byte==8'hff)begin
                bad_ff=bad_ff+1;
                if(bad_ff==3)begin
                    if(bad_frame)bad_frames=bad_frames+1;
                    bad_ff=0;bad_frame=0;bad_pos=0;bad_prefix=0;
                end
            end else begin
                bad_ff=0;
                if(bad_pos<16)begin bad_prefix[127-bad_pos*8-:8]=bad_byte;bad_pos=bad_pos+1;end
                if(bad_prefix=={"rxFrame.val=",32'd0})bad_frame=1;
            end
        end
    end
    initial begin
        repeat(4)@(negedge clk);rst_n=1;
        repeat(16000000)begin
            @(negedge clk);
            if(good_frames==2)begin
                if(bad_frames!=0||framing_errors==0)$fatal(1,"reported 115200 mismatch not reproduced");
                if(period_ns<100000000||period_ns>200000000)$fatal(1,"unexpected production update period %0d",period_ns);
                complete_test("tb_screen_baud_rate",5);
                $display("PASS tb_screen_baud_rate good_frames=%0d wrong_baud_frames=%0d wrong_baud_errors=%0d bytes=%0d period_ns=%0d",good_frames,bad_frames,framing_errors,good_bytes,period_ns);
                $finish;
            end
        end
        $fatal(1,"screen nominal divider109 frames did not finish");
    end
endmodule
