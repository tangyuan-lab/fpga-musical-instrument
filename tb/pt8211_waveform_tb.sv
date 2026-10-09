`timescale 1ns/1ps
module pt8211_waveform_tb;
    reg clk = 0;
    always #10 clk = ~clk;
    reg rst_n = 0;
    reg [15:0] sample_in = 16'h1234;
    wire bck, ws, din, frame_tick;
    pt8211_tx dut(.clk(clk), .rst_n(rst_n), .sample_in(sample_in),
        .bck(bck), .ws(ws), .din(din), .frame_tick(frame_tick));
    integer f;
    initial begin
        f = $fopen("waves/pt8211_wave.csv", "w");
        $fwrite(f, "time_ns,bck,ws,din,frame_tick\n");
        repeat (5) @(negedge clk); rst_n = 1;
        repeat (800) begin
            @(posedge clk);
            $fwrite(f, "%0t,%0d,%0d,%0d,%0d\n", $time,bck,ws,din,frame_tick);
        end
        $fclose(f); $finish;
    end
endmodule
