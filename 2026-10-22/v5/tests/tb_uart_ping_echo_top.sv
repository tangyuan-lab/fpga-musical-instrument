`timescale 1ns/1ps
`default_nettype none

// 覆盖从 UART 引脚接收完整 PING 帧到引脚发出 ACK 的链路，
// 同时检查复位、合法帧和坏 CRC 对 PMOD0 状态灯的影响。
module tb_uart_ping_echo_top;
    localparam integer CLKS_PER_BIT = 434;
    reg  sys_clk = 1'b0;
    reg  sys_rst_n = 1'b0;
    reg  uart_rx_i = 1'b1;
    wire uart_tx_o;
    wire [7:0] led_n;
    wire [7:0] response_data;
    wire response_valid;
    wire response_error;

    reg [7:0] request [0:13];
    reg [7:0] expected [0:15];
    reg [7:0] received [0:15];
    integer response_count = 0;
    integer i;
    integer wait_cycles;

    always #10 sys_clk = ~sys_clk;

    uart_ping_echo_top dut (
        .sys_clk(sys_clk), .sys_rst_n(sys_rst_n),
        .uart_rx_i(uart_rx_i), .uart_tx_o(uart_tx_o), .led_n(led_n)
    );

    uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) response_monitor (
        .clk(sys_clk), .rst_n(sys_rst_n), .rx(uart_tx_o),
        .data(response_data), .valid(response_valid),
        .framing_error(response_error)
    );

    always @(posedge sys_clk) begin
        if (response_valid) begin
            if (response_count >= 16)
                $fatal(1, "unexpected extra ACK byte");
            received[response_count] <= response_data;
            response_count <= response_count + 1;
        end
        if (response_error)
            $fatal(1, "ACK UART framing error");
    end

    task automatic send_byte(input [7:0] value);
        integer bit_index;
        begin
            @(negedge sys_clk);
            uart_rx_i = 1'b0;
            repeat (CLKS_PER_BIT) @(negedge sys_clk);
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                uart_rx_i = value[bit_index];
                repeat (CLKS_PER_BIT) @(negedge sys_clk);
            end
            uart_rx_i = 1'b1;
            repeat (CLKS_PER_BIT) @(negedge sys_clk);
        end
    endtask

    initial begin
        // Python host_app.protocol 生成的序号 0x1234、nonce 0x78563412。
        // PING 与 ACK CRC16 分别为 C9FB、321F，串口低字节先发送。
        request[0]=8'h55; request[1]=8'haa; request[2]=8'h01; request[3]=8'h01;
        request[4]=8'h34; request[5]=8'h12; request[6]=8'h04; request[7]=8'h00;
        request[8]=8'h12; request[9]=8'h34; request[10]=8'h56; request[11]=8'h78;
        request[12]=8'hfb; request[13]=8'hc9;

        expected[0]=8'h55; expected[1]=8'haa; expected[2]=8'h01; expected[3]=8'h81;
        expected[4]=8'h34; expected[5]=8'h12; expected[6]=8'h06; expected[7]=8'h00;
        expected[8]=8'h01; expected[9]=8'h00; expected[10]=8'h12; expected[11]=8'h34;
        expected[12]=8'h56; expected[13]=8'h78; expected[14]=8'h1f; expected[15]=8'h32;

        repeat (5) @(negedge sys_clk);
        if (led_n[7] !== 1'b1)
            $fatal(1, "LED7 must be off during reset");
        sys_rst_n = 1'b1;
        repeat (5) @(negedge sys_clk);
        if (led_n[7] !== 1'b0 || led_n[0] !== 1'b0)
            $fatal(1, "reset release LED state is wrong");

        for (i = 0; i < 14; i = i + 1)
            send_byte(request[i]);

        wait_cycles = 0;
        while (response_count < 16 && wait_cycles < 100_000) begin
            @(negedge sys_clk);
            wait_cycles = wait_cycles + 1;
        end
        if (response_count != 16)
            $fatal(1, "ACK timeout, received %0d bytes", response_count);
        for (i = 0; i < 16; i = i + 1)
            if (received[i] !== expected[i])
                $fatal(1, "ACK byte %0d: got %02x, expected %02x", i, received[i], expected[i]);
        if (led_n[0] !== 1'b1 || led_n[1] !== 1'b0)
            $fatal(1, "PING/error LED state is wrong after valid frame");

        // 只改 CRC 末字节；接收端应拒绝该帧并翻转错误灯，不再发 ACK。
        request[13] = request[13] ^ 8'h01;
        for (i = 0; i < 14; i = i + 1)
            send_byte(request[i]);
        repeat (100) @(negedge sys_clk);
        if (response_count != 16 || led_n[1] !== 1'b1)
            $fatal(1, "bad CRC was not rejected");

        $display("PASS tb_uart_ping_echo_top ACK bytes=%0d", response_count);
        $finish;
    end
endmodule

`default_nettype wire
