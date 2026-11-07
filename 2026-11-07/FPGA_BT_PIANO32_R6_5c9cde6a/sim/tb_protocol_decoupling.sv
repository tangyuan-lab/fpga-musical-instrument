`timescale 1ns/1ps
module tb_protocol_decoupling;
    `include "sim/result.svh"
    GSR GSR(.GSRI(1'b1));
    reg clk=0,rst_n=0;always #10 clk=~clk;
    integer checks=0,cycle=0,frames=0,tx_bytes=0;
    reg [31:0] rng=32'h1a20b395;
    always @(negedge clk)begin cycle=cycle+1;rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};end
    reg  rx_screen_rx_i=1'b1;
    wire [16-1:0] rx_held_keys_a;
    wire [16-1:0] rx_held_keys_b;
    wire  rx_rx_activity_a;
    wire  rx_rx_activity_b;
    wire  rx_frame_error_a;
    wire  rx_frame_error_b;
    wire [1:0] rx_octave_shift_a;
    wire [1:0] rx_octave_shift_b;
    wire  rx_test_mode_a;
    wire  rx_test_mode_b;
    wire  rx_command_valid_a;
    wire  rx_command_valid_b;
    wire [7:0] rx_command_op_a;
    wire [7:0] rx_command_op_b;
    wire [7:0] rx_command_value_a;
    wire [7:0] rx_command_value_b;
    screen_touch_keys_rx #(.CLKS_PER_BIT(4),.KEY_COUNT(16),.POLYPHONIC(1),.PERFORMANCE_CONTROLS(1),.WORKSTATION_CONTROLS(1),.WATCHDOG_CYCLES(1600),.FRAME_TIMEOUT_CYCLES(100)) rx_a(.clk(clk),.rst_n(rst_n),.screen_rx_i(rx_screen_rx_i),.held_keys(rx_held_keys_a),.rx_activity(rx_rx_activity_a),.frame_error(rx_frame_error_a),.octave_shift(rx_octave_shift_a),.test_mode(rx_test_mode_a),.command_valid(rx_command_valid_a),.command_op(rx_command_op_a),.command_value(rx_command_value_a));
    baseline_screen_touch_keys_rx #(.CLKS_PER_BIT(4),.KEY_COUNT(16),.POLYPHONIC(1),.PERFORMANCE_CONTROLS(1),.WORKSTATION_CONTROLS(1),.WATCHDOG_CYCLES(1600),.FRAME_TIMEOUT_CYCLES(100)) rx_b(.clk(clk),.rst_n(rst_n),.screen_rx_i(rx_screen_rx_i),.held_keys(rx_held_keys_b),.rx_activity(rx_rx_activity_b),.frame_error(rx_frame_error_b),.octave_shift(rx_octave_shift_b),.test_mode(rx_test_mode_b),.command_valid(rx_command_valid_b),.command_op(rx_command_op_b),.command_value(rx_command_value_b));
    always @(negedge clk)if(rst_n)begin
        if(rx_held_keys_a!==rx_held_keys_b)$fatal(1,"DIFF_rx_held_keys cycle=%0d",cycle);
        if(rx_rx_activity_a!==rx_rx_activity_b)$fatal(1,"DIFF_rx_rx_activity cycle=%0d",cycle);
        if(rx_frame_error_a!==rx_frame_error_b)$fatal(1,"DIFF_rx_frame_error cycle=%0d",cycle);
        if(rx_octave_shift_a!==rx_octave_shift_b)$fatal(1,"DIFF_rx_octave_shift cycle=%0d",cycle);
        if(rx_test_mode_a!==rx_test_mode_b)$fatal(1,"DIFF_rx_test_mode cycle=%0d",cycle);
        if(rx_command_valid_a!==rx_command_valid_b)$fatal(1,"DIFF_rx_command_valid cycle=%0d",cycle);
        if(rx_command_op_a!==rx_command_op_b)$fatal(1,"DIFF_rx_command_op cycle=%0d",cycle);
        if(rx_command_value_a!==rx_command_value_b)$fatal(1,"DIFF_rx_command_value cycle=%0d",cycle);
        checks=checks+1;
    end
    reg [3:0] tx_view=8;
    reg [2:0] tx_mode=0;
    reg [2:0] tx_test_kind=0;
    reg [31:0] tx_build_id=32'hffffffff;
    reg [31:0] tx_voice_mask=0;
    reg [31:0] tx_timeout_count=0;
    reg [31:0] tx_revision=0;
    reg [5:0] tx_voices=32;
    reg [5:0] tx_peak_voices=0;
    reg [15:0] tx_keys=0;
    reg [15:0] tx_flags=0;
    reg [191:0] tx_pressure=0;
    reg [479:0] tx_telemetry={15{32'hdeadbeef}};
    reg [7:0] tx_graph_config=0;
    reg [7:0] tx_result=0;
    reg [223:0] tx_song_status=0;
    reg  tx_song_ready=1;
    reg  tx_ddr_ready=1;
    reg [111:0] tx_command_feedback=0;
    reg [63:0] tx_peaks=0;
    reg  tx_graph_ready=1;
    reg  tx_lock_granted=1;
    reg [15:0] tx_graph_data=16'hbead;
    reg [1:0] tx_graph_kind=0;
    reg  tx_freeze_graph=0;
    reg  tx_right_channel=0;
    reg  tx_scope_command_valid=0;
    reg [7:0] tx_scope_command_op=0;
    reg [7:0] tx_scope_command_value=0;
    reg [6:0] tx_scope_available=24;
    reg [23:0] tx_scope_pair=24'hd56712;
    reg  tx_scope_overflow=0;
    wire  tx_scope_pop_a;
    wire  tx_scope_pop_b;
    wire  tx_scope_clear_a;
    wire  tx_scope_clear_b;
    wire  tx_scope_capture_enable_a;
    wire  tx_scope_capture_enable_b;
    wire  tx_graph_lock_a;
    wire  tx_graph_lock_b;
    wire [5:0] tx_graph_address_a;
    wire [5:0] tx_graph_address_b;
    wire  tx_tx_a;
    wire  tx_tx_b;
    mega138_screen_tx #(.CLKS_PER_BIT(4),.STARTUP_CYCLES(2),.UPDATE_CYCLES(200),.STREAM_SUPPORT(1),.TELEMETRY_SUPPORT(1),.PIANO32_SUPPORT(1),.ACK_TIMEOUT_CYCLES(5000)) tx_a(.clk(clk),.rst_n(rst_n),.view(tx_view),.mode(tx_mode),.test_kind(tx_test_kind),.build_id(tx_build_id),.voice_mask(tx_voice_mask),.timeout_count(tx_timeout_count),.revision(tx_revision),.voices(tx_voices),.peak_voices(tx_peak_voices),.keys(tx_keys),.flags(tx_flags),.pressure(tx_pressure),.telemetry(tx_telemetry),.graph_config(tx_graph_config),.result(tx_result),.song_status(tx_song_status),.song_ready(tx_song_ready),.ddr_ready(tx_ddr_ready),.command_feedback(tx_command_feedback),.peaks(tx_peaks),.graph_ready(tx_graph_ready),.lock_granted(tx_lock_granted),.graph_data(tx_graph_data),.graph_kind(tx_graph_kind),.freeze_graph(tx_freeze_graph),.right_channel(tx_right_channel),.scope_command_valid(tx_scope_command_valid),.scope_command_op(tx_scope_command_op),.scope_command_value(tx_scope_command_value),.scope_available(tx_scope_available),.scope_pair(tx_scope_pair),.scope_overflow(tx_scope_overflow),.scope_pop(tx_scope_pop_a),.scope_clear(tx_scope_clear_a),.scope_capture_enable(tx_scope_capture_enable_a),.graph_lock(tx_graph_lock_a),.graph_address(tx_graph_address_a),.tx(tx_tx_a));
    baseline_mega138_screen_tx #(.CLKS_PER_BIT(4),.STARTUP_CYCLES(2),.UPDATE_CYCLES(200),.STREAM_SUPPORT(1),.TELEMETRY_SUPPORT(1),.PIANO32_SUPPORT(1),.ACK_TIMEOUT_CYCLES(5000)) tx_b(.clk(clk),.rst_n(rst_n),.view(tx_view),.mode(tx_mode),.test_kind(tx_test_kind),.build_id(tx_build_id),.voice_mask(tx_voice_mask),.timeout_count(tx_timeout_count),.revision(tx_revision),.voices(tx_voices),.peak_voices(tx_peak_voices),.keys(tx_keys),.flags(tx_flags),.pressure(tx_pressure),.telemetry(tx_telemetry),.graph_config(tx_graph_config),.result(tx_result),.song_status(tx_song_status),.song_ready(tx_song_ready),.ddr_ready(tx_ddr_ready),.command_feedback(tx_command_feedback),.peaks(tx_peaks),.graph_ready(tx_graph_ready),.lock_granted(tx_lock_granted),.graph_data(tx_graph_data),.graph_kind(tx_graph_kind),.freeze_graph(tx_freeze_graph),.right_channel(tx_right_channel),.scope_command_valid(tx_scope_command_valid),.scope_command_op(tx_scope_command_op),.scope_command_value(tx_scope_command_value),.scope_available(tx_scope_available),.scope_pair(tx_scope_pair),.scope_overflow(tx_scope_overflow),.scope_pop(tx_scope_pop_b),.scope_clear(tx_scope_clear_b),.scope_capture_enable(tx_scope_capture_enable_b),.graph_lock(tx_graph_lock_b),.graph_address(tx_graph_address_b),.tx(tx_tx_b));
    always @(negedge clk)if(rst_n)begin
        if(tx_scope_pop_a!==tx_scope_pop_b)$fatal(1,"DIFF_tx_scope_pop cycle=%0d",cycle);
        if(tx_scope_clear_a!==tx_scope_clear_b)$fatal(1,"DIFF_tx_scope_clear cycle=%0d",cycle);
        if(tx_scope_capture_enable_a!==tx_scope_capture_enable_b)$fatal(1,"DIFF_tx_scope_capture_enable cycle=%0d",cycle);
        if(tx_graph_lock_a!==tx_graph_lock_b)$fatal(1,"DIFF_tx_graph_lock cycle=%0d",cycle);
        if(tx_graph_address_a!==tx_graph_address_b)$fatal(1,"DIFF_tx_graph_address cycle=%0d",cycle);
        if(tx_tx_a!==tx_tx_b)$fatal(1,"DIFF_tx_tx cycle=%0d",cycle);
        checks=checks+1;
    end
    reg  adc_mcp0_miso=0;
    reg  adc_mcp1_miso=0;
    wire  adc_mcp_sclk_a;
    wire  adc_mcp_sclk_b;
    wire  adc_mcp_mosi_a;
    wire  adc_mcp_mosi_b;
    wire  adc_mcp0_cs_n_a;
    wire  adc_mcp0_cs_n_b;
    wire  adc_mcp1_cs_n_a;
    wire  adc_mcp1_cs_n_b;
    wire [95:0] adc_samples0_a;
    wire [95:0] adc_samples0_b;
    wire [95:0] adc_samples1_a;
    wire [95:0] adc_samples1_b;
    wire  adc_frame_valid_a;
    wire  adc_frame_valid_b;
    wire  adc_ready_a;
    wire  adc_ready_b;
    wire  adc_fault_a;
    wire  adc_fault_b;
    mcp3208_dual_scan #(.HALF_PERIOD(3)) adc_a(.clk(clk),.rst_n(rst_n),.mcp0_miso(adc_mcp0_miso),.mcp1_miso(adc_mcp1_miso),.mcp_sclk(adc_mcp_sclk_a),.mcp_mosi(adc_mcp_mosi_a),.mcp0_cs_n(adc_mcp0_cs_n_a),.mcp1_cs_n(adc_mcp1_cs_n_a),.samples0(adc_samples0_a),.samples1(adc_samples1_a),.frame_valid(adc_frame_valid_a),.ready(adc_ready_a),.fault(adc_fault_a));
    baseline_mcp3208_dual_scan #(.HALF_PERIOD(3)) adc_b(.clk(clk),.rst_n(rst_n),.mcp0_miso(adc_mcp0_miso),.mcp1_miso(adc_mcp1_miso),.mcp_sclk(adc_mcp_sclk_b),.mcp_mosi(adc_mcp_mosi_b),.mcp0_cs_n(adc_mcp0_cs_n_b),.mcp1_cs_n(adc_mcp1_cs_n_b),.samples0(adc_samples0_b),.samples1(adc_samples1_b),.frame_valid(adc_frame_valid_b),.ready(adc_ready_b),.fault(adc_fault_b));
    always @(negedge clk)if(rst_n)begin
        if(adc_mcp_sclk_a!==adc_mcp_sclk_b)$fatal(1,"DIFF_adc_mcp_sclk cycle=%0d",cycle);
        if(adc_mcp_mosi_a!==adc_mcp_mosi_b)$fatal(1,"DIFF_adc_mcp_mosi cycle=%0d",cycle);
        if(adc_mcp0_cs_n_a!==adc_mcp0_cs_n_b)$fatal(1,"DIFF_adc_mcp0_cs_n cycle=%0d",cycle);
        if(adc_mcp1_cs_n_a!==adc_mcp1_cs_n_b)$fatal(1,"DIFF_adc_mcp1_cs_n cycle=%0d",cycle);
        if(adc_samples0_a!==adc_samples0_b)$fatal(1,"DIFF_adc_samples0 cycle=%0d",cycle);
        if(adc_samples1_a!==adc_samples1_b)$fatal(1,"DIFF_adc_samples1 cycle=%0d",cycle);
        if(adc_frame_valid_a!==adc_frame_valid_b)$fatal(1,"DIFF_adc_frame_valid cycle=%0d",cycle);
        if(adc_ready_a!==adc_ready_b)$fatal(1,"DIFF_adc_ready cycle=%0d",cycle);
        if(adc_fault_a!==adc_fault_b)$fatal(1,"DIFF_adc_fault cycle=%0d",cycle);
        checks=checks+1;
    end

    // 协议解析独立接受字节，无UART实例参与此接口测试。
    reg [7:0] byte_data=0;reg byte_valid=0,byte_error=0;
    wire frame_valid;wire [7:0] frame_op,frame_value;wire frame_error;
    screen_frame_rx #(.FRAME_TIMEOUT_CYCLES(30)) parser(.clk(clk),.rst_n(rst_n),
        .rx_data(byte_data),.rx_valid(byte_valid),.rx_framing_error(byte_error),
        .frame_valid(frame_valid),.frame_op(frame_op),.frame_value(frame_value),.rx_activity(),.frame_error(frame_error));
    always @(posedge clk)if(rst_n&&frame_valid)begin
        frames=frames+1;
        if(frame_op!==1||frame_value!==7)$fatal(1,"BYTE_PARSER_WRONG_EVENT");
    end
    task byte_send(input [7:0] v);
        begin @(negedge clk);byte_data=v;byte_valid=1;@(negedge clk);byte_valid=0;end
    endtask
    task serial_byte(input [7:0] v);
        integer b;
        begin rx_screen_rx_i=0;repeat(4)@(negedge clk);
            for(b=0;b<8;b=b+1)begin rx_screen_rx_i=v[b];repeat(4)@(negedge clk);end
            rx_screen_rx_i=1;repeat(8)@(negedge clk);
        end
    endtask
    task serial_frame(input [7:0] op,v,input bad);
        begin serial_byte(8'ha5);serial_byte(8'h5a);serial_byte(op);serial_byte(v);serial_byte(8'hff^op^v^{7'd0,bad});end
    endtask
    always @(negedge clk)begin
        adc_mcp0_miso=rng[0];adc_mcp1_miso=rng[3];
        tx_graph_data=rng[15:0];
        tx_telemetry={15{rng}};
    end
    initial begin
        repeat(8)@(negedge clk);rst_n=1;
        byte_send(8'ha5);byte_send(8'h5a);byte_send(1);byte_send(7);byte_send(8'hf9);
        repeat(2)@(negedge clk);if(frames!=1)$fatal(1,"DIRECT_BYTE_FRAME_MISSING");
        byte_send(8'ha5);byte_send(8'h5a);byte_send(1);byte_send(7);byte_send(0);
        repeat(40)@(negedge clk);if(frames!=1)$fatal(1,"BAD_CHECKSUM_ACCEPTED");
        byte_send(8'ha5);repeat(40)@(negedge clk);byte_send(8'h5a);byte_send(1);byte_send(7);byte_send(8'hf9);
        repeat(40)@(negedge clk);if(frames!=1)$fatal(1,"TIMEOUT_SPLICE_ACCEPTED");
        byte_send(8'ha5);byte_send(8'h5a);byte_send(1);byte_send(7);byte_send(8'hf9);
        repeat(2)@(negedge clk);if(frames!=2)$fatal(1,"PARSER_RECOVERY_MISSING");
        serial_frame(1,0,0);serial_frame(1,7,0);serial_frame(1,3,1);serial_frame(0,7,0);
        serial_frame(3,2,0);serial_frame(4,1,0);serial_frame(8'h61,2,0);
        repeat(2000)@(negedge clk);
        if(rx_held_keys_a!==0||rx_test_mode_a!==0)$fatal(1,"TOUCH_WATCHDOG_FAILED");
        // 改页、流启动、溢出和缺ACK重试都与原发送器逐周期比较。
        repeat(80000)@(negedge clk);tx_view=9;
        repeat(80000)@(negedge clk);tx_view=7;
        tx_scope_command_valid=1;tx_scope_command_op=8'h6a;tx_scope_command_value=2;
        @(negedge clk);tx_scope_command_valid=0;
        repeat(100000)@(negedge clk);tx_scope_overflow=1;
        @(negedge clk);tx_scope_overflow=0;
        repeat(30000)@(negedge clk);
        complete_test("tb_protocol_decoupling",checks);
        $display("PASS tb_protocol_decoupling CHECKS=%0d direct_frames=%0d",checks,frames);$finish;
    end
    initial begin #8000000;$fatal(1,"DECOUPLING_BOUND");end
endmodule
