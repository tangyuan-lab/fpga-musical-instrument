`timescale 1ns/1ps
module tb_uart_frame_tx_v2;
    reg clk=0,rst_n=0,valid=0;always #10 clk=~clk;
    reg [767:0] payload;wire tx,busy,rx_valid;wire [7:0] data;
    integer file,i,count=0;
    uart_frame_tx_v2 #(.CLKS_PER_BIT(4)) dut(.clk(clk),.rst_n(rst_n),.response_valid(valid),.response_type(8'h81),
      .response_seq(16'had5a),.response_length(8'd96),.response_payload(payload),.tx(tx),.busy(busy));
    uart_rx #(.CLKS_PER_BIT(4)) rx(.clk(clk),.rst_n(rst_n),.rx(tx),.data(data),.valid(rx_valid),.framing_error());
    always @(posedge clk) if(rx_valid) begin $fwrite(file,"%02x\n",data);count=count+1;end
    initial begin
        file=$fopen("build/tests/uart_frame_tx_v2.hex","w");
        for(i=0;i<96;i=i+1) payload[i*8+:8]=8'(i*37+11);
        repeat(8) @(negedge clk);rst_n=1;repeat(4) @(negedge clk);valid=1;@(negedge clk);valid=0;
        wait(busy);wait(!busy);repeat(20) @(negedge clk);$fclose(file);
        if(count!=106) $fatal(1,"UART byte count %d",count);
        $display("PASS tb_uart_frame_tx_v2 payload96 captured");$finish;
    end
    initial begin #1000000;$fatal(1,"UART TX timeout");end
endmodule
