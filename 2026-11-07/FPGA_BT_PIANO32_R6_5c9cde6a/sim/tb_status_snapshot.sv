`timescale 1ns/1ps
module tb_status_snapshot;
    `include "sim/result.svh"
    GSR GSR(.GSRI(1'b1));
    reg clk=0;always #10 clk=~clk;
    reg rst_n=0,frame_valid=0,response_busy=0,emergency=0;
    reg [7:0] frame_type=0;reg [15:0] frame_seq=0;
    reg [223:0] status_data=0;reg [175:0] runtime_data=0;reg [111:0] feedback=0;
    wire response_valid;wire [15:0] response_seq;wire [7:0] response_length;wire [767:0] response_payload;
    workstation_cut123_resources #(.ENABLE_EMERGENCY(1),.BUILTIN_PIANO(1)) dut(
        .clk(clk),.rst_n(rst_n),.frame_valid(frame_valid),.frame_type(frame_type),.frame_seq(frame_seq),.frame_length(16'd0),.payload(1056'd0),
        .response_valid(response_valid),.response_seq(response_seq),.response_length(response_length),.response_payload(response_payload),.response_busy(response_busy),
        .control_done(1'b0),.control_result(8'd0),.status_data(status_data),.runtime_data(runtime_data),.command_feedback(feedback),
        .hardware_status(400'd0),.chord_status(64'd0),.damping_settings(96'd0),
        .track_gains(256'd0),.track_timbres(128'd0),.track_volumes(128'd0),.track_mutes(16'd0),.track_solos(16'd0),.channel_map(64'd0),
        .validation_done(1'b0),.validation_busy(1'b0),.validation_error(1'b0),.validation_duration(32'd0),
        .selected_song(2'd0),.song_read_address(16'd0),.external_adsr_valid(1'b0),.external_adsr_value(32'd0),.external_adsr_aux(32'd0),
        .envelope_read_bank(5'd10),.section_read_address(7'd0),.catalog_index(4'd0),.emergency_abort(emergency),.storage_ready(1'b1),
        .ddr_req_ready(1'b1),.ddr_resp_valid(1'b0),.ddr_resp_error(1'b0),.ddr_resp_data(256'd0));
    integer checks=0;
    task automatic request(input [7:0] kind,input [15:0] seq);
        integer n;
        begin
            n=0;while(dut.state!=0&&n<1000)begin @(negedge clk);n=n+1;end
            if(dut.state!=0)$fatal(1,"request idle timeout");
            @(negedge clk);frame_type=kind;frame_seq=seq;frame_valid=1;
            @(negedge clk);frame_valid=0;
        end
    endtask
    task automatic wait_capture;
        integer n;
        begin
            n=0;while(dut.state!=13&&n<1000)begin @(negedge clk);n=n+1;end
            if(dut.state!=13)$fatal(1,"capture timeout");
            @(negedge clk); // All source fields have now been sampled at one edge.
        end
    endtask
    task automatic receive;
        integer n;
        begin
            n=0;while(!response_valid&&n<1000)begin @(negedge clk);n=n+1;end
            if(!response_valid||response_seq!==frame_seq||response_payload[15:8]!==0)$fatal(1,"reply header/timeout");
            checks=checks+1;
        end
    endtask
    task automatic consumed;
        begin response_busy=1;repeat(2)@(negedge clk);response_busy=0;repeat(2)@(negedge clk);end
    endtask
    reg [223:0] expected_status;reg [175:0] expected_runtime;reg [111:0] expected_feedback;
    reg [767:0] saved_response;
    initial begin
        repeat(5)@(negedge clk);rst_n=1;repeat(3)@(negedge clk);
        status_data={7{32'h13579bdf}};expected_status=status_data;
        request(8'h36,1);wait_capture();status_data=~status_data;
        receive();if(response_length!==30||response_payload[239:16]!==expected_status)$fatal(1,"status was not frozen");consumed();
        status_data={7{32'hdeadbeef}};runtime_data={11{16'h1234}};feedback=112'h0123456789abcdef135724681234;
        expected_status=status_data;expected_runtime=runtime_data;expected_feedback=feedback;
        request(8'h37,2);wait_capture();status_data=0;runtime_data=0;feedback=0;
        // Backpressure must not change the captured data or publish a partial reply.
        response_busy=1;repeat(12)begin @(negedge clk);if(response_valid)$fatal(1,"reply ignored backpressure");end
        response_busy=0;receive();
        if(response_length!==80||response_payload[303:80]!==expected_status||response_payload[479:304]!==expected_runtime||
            {response_payload[639:608],response_payload[607:576],response_payload[79:48],response_payload[39:32],response_payload[31:24]}!==expected_feedback||
            response_payload[575:544]!==0||response_payload[23:16]!==1||
            {response_payload[543:528],response_payload[527:512],response_payload[511:496],response_payload[495:480]}!=={16'd32,16'd3072,16'd8,16'd64})
            $fatal(1,"extended snapshot fields mixed across clocks");
        saved_response=response_payload;consumed();
        request(8'h37,2);receive();if(response_payload!==saved_response)$fatal(1,"retry changed cached reply");consumed();
        request(8'h37,3);wait_capture();receive();
        if(response_payload[303:80]!==0||response_payload[479:304]!==0||response_payload[575:544]!==1)$fatal(1,"fresh snapshot/counter");consumed();
        request(8'h36,4);wait_capture();emergency=1;@(negedge clk);emergency=0;
        repeat(20)begin @(negedge clk);if(response_valid)$fatal(1,"aborted snapshot leaked reply");end
        checks=checks+1;status_data={7{32'hfedcba98}};
        request(8'h36,5);wait_capture();receive();if(response_payload[239:16]!==status_data)$fatal(1,"query after abort");consumed();
        complete_test("tb_status_snapshot",checks);$display("PASS tb_status_snapshot checks=%0d",checks);$finish;
    end
    initial begin #1000000;$fatal(1,"status snapshot timeout");end
endmodule
