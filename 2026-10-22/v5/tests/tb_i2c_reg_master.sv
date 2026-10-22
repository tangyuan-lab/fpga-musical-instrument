`timescale 1ns/1ps

// I2C 从设备模型：检查发送字节的第 9 个 ACK 时钟，并提供一次连续读数据。
// 该测试不依赖 GT911 实物，专门验证主机的开漏时序和寄存器读写边界。
module tb_i2c_reg_master;
    localparam integer CLK_HZ = 1_000_000;
    localparam integer I2C_HZ = 100_000;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    reg cmd_valid = 1'b0;
    reg cmd_read = 1'b0;
    reg [6:0] cmd_dev_addr = 7'h5d;
    reg [15:0] cmd_reg_addr = 16'h0000;
    reg [7:0] cmd_write_data = 8'h00;
    reg [2:0] cmd_read_len = 3'd1;
    wire busy;
    wire done;
    wire error;
    wire [7:0] read_data0, read_data1, read_data2;
    wire [7:0] read_data3, read_data4, read_data5;

    // tri1 模拟板上的上拉电阻；主机和从机只能拉低，不能主动输出高电平。
    tri1 scl;
    tri1 sda;
    reg slave_sda_low = 1'b0;
    assign sda = slave_sda_low ? 1'b0 : 1'bz;

    i2c_reg_master #(.CLK_HZ(CLK_HZ), .I2C_HZ(I2C_HZ)) dut (
        .clk(clk), .rst_n(rst_n),
        .cmd_valid(cmd_valid), .cmd_read(cmd_read),
        .cmd_dev_addr(cmd_dev_addr), .cmd_reg_addr(cmd_reg_addr),
        .cmd_write_data(cmd_write_data), .cmd_read_len(cmd_read_len),
        .busy(busy), .done(done), .error(error),
        .read_data0(read_data0), .read_data1(read_data1), .read_data2(read_data2),
        .read_data3(read_data3), .read_data4(read_data4), .read_data5(read_data5),
        .scl(scl), .sda(sda)
    );

    always #500 clk = ~clk;

    reg active = 1'b0;
    reg tx_mode = 1'b0;
    reg rx_ack_pending = 1'b0;
    reg rx_ack_active = 1'b0;
    reg tx_ack_pending = 1'b0;
    reg tx_ack_active = 1'b0;
    integer rx_bit_count = 0;
    integer tx_bit_count = 0;
    integer rx_byte_count = 0;
    integer tx_byte_index = 0;
    integer start_count = 0;
    integer stop_count = 0;
    integer rising_count = 0;
    reg [7:0] rx_shift = 8'h00;
    reg [7:0] last_rx_byte = 8'h00;
    reg [7:0] captured [0:7];
    reg [7:0] read_bytes [0:5];
    reg master_ack = 1'b0;

    function automatic [7:0] tx_value(input integer index);
        begin
            case (index)
                0: tx_value = 8'h80;
                1: tx_value = 8'h01;
                2: tx_value = 8'h34;
                3: tx_value = 8'h02;
                4: tx_value = 8'h56;
                default: tx_value = 8'h00;
            endcase
        end
    endfunction

    // START/STOP 只在 SCL 为高时有效。ACK 和数据位均在 SCL 低电平期间改变，
    // 因此不会被误判为总线控制条件。
    always @(negedge sda) begin
        if (scl === 1'b1) begin
            active = 1'b1;
            start_count = start_count + 1;
            rx_bit_count = 0;
            tx_bit_count = 0;
            tx_mode = 1'b0;
            rx_ack_pending = 1'b0;
            rx_ack_active = 1'b0;
            tx_ack_pending = 1'b0;
            tx_ack_active = 1'b0;
        end
    end

    always @(posedge sda) begin
        if ((scl === 1'b1) && active) begin
            active = 1'b0;
            stop_count = stop_count + 1;
            slave_sda_low = 1'b0;
        end
    end

    // 从机在 SCL 高电平采样数据位；ACK/NACK 也在第 9 个高电平采样。
    always @(posedge scl) begin
        if (active) begin
            rising_count = rising_count + 1;
            if (!tx_mode) begin
                if (rx_bit_count < 8) begin
                    rx_shift = {rx_shift[6:0], sda};
                    if (rx_bit_count == 7) begin
                        last_rx_byte = {rx_shift[6:0], sda};
                        if (rx_byte_count < 8)
                            captured[rx_byte_count] = {rx_shift[6:0], sda};
                        rx_byte_count = rx_byte_count + 1;
                        rx_ack_pending = 1'b1;
                        rx_bit_count = 8;
                    end else begin
                        rx_bit_count = rx_bit_count + 1;
                    end
                end else if (rx_ack_active) begin
                    if (sda !== 1'b0)
                        $fatal(1, "master did not ACK received byte %0d", rx_byte_count);
                end
            end else begin
                if (tx_bit_count < 8) begin
                    if (tx_bit_count == 7) begin
                        tx_bit_count = 8;
                        tx_ack_pending = 1'b1;
                    end else begin
                        tx_bit_count = tx_bit_count + 1;
                    end
                end else if (tx_ack_active) begin
                    master_ack = (sda === 1'b0);
                end
            end
        end
    end

    // 在数据位结束后的低电平阶段准备 ACK，避免 SDA 在 SCL 高电平时变化。
    always @(negedge scl) begin
        if (active) begin
            if (!tx_mode) begin
                if (rx_ack_pending) begin
                    rx_ack_pending = 1'b0;
                    rx_ack_active = 1'b1;
                    slave_sda_low = 1'b1;
                end else if (rx_ack_active) begin
                    rx_ack_active = 1'b0;
                    slave_sda_low = 1'b0;
                    rx_bit_count = 0;
                end
            end else begin
                if (tx_ack_pending) begin
                    tx_ack_pending = 1'b0;
                    tx_ack_active = 1'b1;
                    slave_sda_low = 1'b0;
                end else if (tx_ack_active) begin
                    tx_ack_active = 1'b0;
                    if (master_ack && (tx_byte_index < 5)) begin
                        tx_byte_index = tx_byte_index + 1;
                        tx_bit_count = 0;
                        slave_sda_low = (tx_value(tx_byte_index)[7] == 1'b0);
                    end else begin
                        // 最后一个字节收到 NACK 后保持 SDA 释放，等待 STOP。
                        slave_sda_low = 1'b0;
                    end
                end
            end
        end
    end

    // 读地址 0xBB 的 ACK 结束后，切换到从机发送模式并预置第一个数据位。
    always @(negedge scl) begin
        if (active && !tx_mode && rx_ack_active && (last_rx_byte == 8'hbb)) begin
            // 该分支在 ACK 低电平结束时执行；下一次 SCL 上升即为读数据第 1 位。
            tx_mode = 1'b1;
            tx_byte_index = 0;
            tx_bit_count = 0;
            rx_ack_active = 1'b0;
            slave_sda_low = (tx_value(0)[7] == 1'b0);
        end
    end

    task automatic clear_bus_counters;
        integer k;
        begin
            start_count = 0;
            stop_count = 0;
            rising_count = 0;
            rx_byte_count = 0;
            active = 1'b0;
            tx_mode = 1'b0;
            rx_ack_pending = 1'b0;
            rx_ack_active = 1'b0;
            tx_ack_pending = 1'b0;
            tx_ack_active = 1'b0;
            slave_sda_low = 1'b0;
            for (k = 0; k < 8; k = k + 1)
                captured[k] = 8'h00;
        end
    endtask

    task automatic issue_command(input reg is_read, input [15:0] address,
                                 input [7:0] data, input [2:0] length);
        begin
            @(negedge clk);
            cmd_read = is_read;
            cmd_reg_addr = address;
            cmd_write_data = data;
            cmd_read_len = length;
            cmd_valid = 1'b1;
            @(negedge clk);
            cmd_valid = 1'b0;
            fork : wait_for_done
                begin
                    wait (done === 1'b1);
                end
                begin
                    repeat (10000) @(posedge clk);
                    $fatal(1, "I2C command timeout");
                end
            join_any
            disable wait_for_done;
        end
    endtask

    initial begin : test_sequence
        integer k;
        read_bytes[0] = 8'h80;
        read_bytes[1] = 8'h01;
        read_bytes[2] = 8'h34;
        read_bytes[3] = 8'h02;
        read_bytes[4] = 8'h56;
        read_bytes[5] = 8'h00;
        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        repeat (4) @(posedge clk);

        // 写事务：地址、寄存器高字节、寄存器低字节和数据都必须被 ACK。
        clear_bus_counters();
        issue_command(1'b0, 16'h814e, 8'h00, 3'd1);
        if (error !== 1'b0) $fatal(1, "write transaction returned error");
        if (start_count !== 1 || stop_count !== 1)
            $fatal(1, "write START/STOP mismatch: %0d/%0d", start_count, stop_count);
        if (rising_count !== 37)
            $fatal(1, "write clock count expected 37 (36 data/ACK + STOP rise), got %0d", rising_count);
        if (captured[0] !== 8'hba || captured[1] !== 8'h81 ||
            captured[2] !== 8'h4e || captured[3] !== 8'h00)
            $fatal(1, "write bytes mismatch: %02x %02x %02x %02x",
                   captured[0], captured[1], captured[2], captured[3]);

        // 读事务：重复 START、读地址 ACK、6 字节数据及中间 ACK/最后 NACK。
        clear_bus_counters();
        issue_command(1'b1, 16'h814e, 8'h00, 3'd6);
        if (error !== 1'b0) $fatal(1, "read transaction returned error");
        if (start_count !== 2 || stop_count !== 1)
            $fatal(1, "read START/STOP mismatch: %0d/%0d", start_count, stop_count);
        if (rising_count !== 92)
            $fatal(1, "read clock count expected 92 (90 data/ACK + repeat/STOP rise), got %0d", rising_count);
        if (read_data0 !== 8'h80 || read_data1 !== 8'h01 ||
            read_data2 !== 8'h34 || read_data3 !== 8'h02 ||
            read_data4 !== 8'h56 || read_data5 !== 8'h00)
            $fatal(1, "read bytes mismatch: %02x %02x %02x %02x %02x %02x",
                   read_data0, read_data1, read_data2,
                   read_data3, read_data4, read_data5);

        $display("PASS tb_i2c_reg_master");
        $finish;
    end
endmodule

