`timescale 1ns/1ps
module tb_workstation_screen_tx;
    reg clk=0;always #10 clk=~clk;reg rst_n=0;wire tx;wire [7:0] data;wire valid;
    reg [15:0] keys=16'hffff;reg [2:0] mode=3;
    workstation_screen_tx #(.CLKS_PER_BIT(4),.STARTUP_CYCLES(0)) dut(
        .clk(clk),.rst_n(rst_n),.mode(mode),.edit_bank(3'd2),.keys(keys),.drums(16'h1234),.descriptor(16'h410f),
        .track_sounds(16'h3210),.step_index(4'd15),.edit_key(4'd7),.bpm(8'd240),.flags(8'h3f),
        .patterns(64'hffff_1234_0002_0001),.volumes({7'd100,7'd60,7'd80}),.pressure_values({16{12'hfff}}),.screen_tx_o(tx));
    uart_rx #(.CLKS_PER_BIT(4)) rx(.clk(clk),.rst_n(rst_n),.rx(tx),.data(data),.valid(valid),.framing_error());
    string line="";integer end_count=0,commands=0;reg saw_keys=0,saw_pressure=0,saw_map=0;
    always @(posedge clk) if(valid) begin
        if(data==255) begin
            end_count=end_count+1;
            if(end_count==3) begin
                if(line=="rxKeys.val=0065535") saw_keys=1;
                if(line=="rxConfig.val=2572559") saw_map=1;
                if(line=="rxP15.val=0004095") saw_pressure=1;
                if(line.len()<14) $fatal(1,"short or damaged command %s",line);
                commands=commands+1;line="";end_count=0;
                if(saw_keys && saw_pressure && saw_map) begin
                    $display("PASS tb_workstation_screen_tx UART full commands, BCD and max key bitmap");$finish;
                end
            end
        end else begin if(end_count!=0) $fatal(1,"interrupted terminator");line={line,data};end
    end
    initial begin repeat(4) @(negedge clk);rst_n=1;repeat(80000) @(negedge clk);$fatal(1,"UART test timeout %d",commands);end
endmodule
