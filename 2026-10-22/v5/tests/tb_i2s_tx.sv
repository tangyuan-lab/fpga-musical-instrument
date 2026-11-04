`timescale 1ns/1ps
module tb_i2s_tx;
    reg clk=0, rst_n=0;
    reg [15:0] left=16'h8123, right=16'h4567;
    wire tick,bck,ws,din;
    reg prev_ws=1;
    reg [15:0] decoded=0;
    integer pos=0, words=0, cycles=0, last_tick=0;
    always #10 clk=~clk;
    i2s_tx dut(.clk(clk),.rst_n(rst_n),.sample_left(left),.sample_right(right),
        .sample_tick(tick),.hp_bck(bck),.hp_ws(ws),.hp_din(din));
    always @(posedge clk) begin
        if(rst_n) begin
            cycles=cycles+1;
            if(tick) begin
                if(last_tick!=0 && cycles-last_tick!=1024) $fatal(1,"wrong 48.828kHz frame cadence");
                last_tick=cycles;
            end
        end
    end
    // 完全按引脚重建时隙，验证 WS 一位提前、左右顺序、补零和整帧快照。
    always @(posedge bck) begin
        if(rst_n) begin
            if(ws!=prev_ws) begin
                pos=0;
                prev_ws=ws;
            end else begin
                pos=pos+1;
            end
            if(pos==0 && din!==0) $fatal(1,"missing one-BCK MSB delay");
            if(pos>=1 && pos<=16) decoded={decoded[14:0],din};
            if(pos==16) begin
                if(words<2) begin
                    if(decoded !== (ws ? 16'h4567:16'h8123)) $fatal(1,"first snapshot/channel mismatch %h",decoded);
                end else if(decoded !== (ws ? 16'hfedc:16'h2345)) $fatal(1,"updated sample mismatch %h",decoded);
                words=words+1;
                if(words==1) begin left=16'h2345; right=16'hfedc; end
                if(words==6) begin $display("PASS tb_i2s_tx delay=1bit slots=32 stereo_snapshot=PASS fs=48828.125Hz"); $finish; end
            end
            if(pos>=17 && din!==0) $fatal(1,"nonzero I2S padding");
        end
    end
    initial begin repeat(3) @(negedge clk); rst_n=1; end
    initial begin #200000; $fatal(1,"timeout"); end
endmodule
