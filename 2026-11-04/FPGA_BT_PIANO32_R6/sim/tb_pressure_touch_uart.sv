`timescale 1ns/1ps
`include "rtl/workstation_build_identity.vh"
`include "rtl/damping_defaults.vh"
`include "sim/ddr_phy_model.sv"
`include "sim/mcp3208_dynamic_model.sv"
module tb_pressure_touch_uart;
    GSR GSR(.GSRI(1'b1));
    `include "sim/result.svh"
    reg clk=0;always #10 clk=~clk;
    reg rst_n=0,uart_rx=1,screen_rx=1;
    wire uart_tx,screen_tx,pa_en;wire [7:0] led_n;wire [31:0] dq;wire [3:0] dqs,dqsn;
    wire mcp_clk,mcp_mosi,cs0,cs1,miso0,miso1;reg [95:0] adc0_values=0,adc1_values=0;
    mcp3208_dynamic_model adc0(.cs_n(cs0),.sclk(mcp_clk),.mosi(mcp_mosi),.values(adc0_values),.miso(miso0));
    mcp3208_dynamic_model adc1(.cs_n(cs1),.sclk(mcp_clk),.mosi(mcp_mosi),.values(adc1_values),.miso(miso1));
    mega138_models8_top #(.USB_CLKS_PER_BIT(8),.SCREEN_CLKS_PER_BIT(8),.CALIBRATION_SAMPLES(1),
        .STARTUP_CYCLES(10),.SCREEN_STARTUP_CYCLES(100),.SCREEN_UPDATE_CYCLES(5000)) dut(
        .bt_rx_i(1'b1),.bt_tx_o(),.sys_clk(clk),.sys_rst_n(rst_n),.uart_rx_i(uart_rx),.uart_tx_o(uart_tx),.mode_key_n(1'b1),.timbre_key_n(1'b1),
        .led_n(led_n),.hp_bck(),.hp_ws(),.hp_din(),.pa_en(pa_en),.screen_rx_i(screen_rx),.screen_tx_o(screen_tx),
        .mcp0_sclk(mcp_clk),.mcp1_sclk(),.mcp0_mosi(mcp_mosi),.mcp1_mosi(),.mcp0_cs_n(cs0),.mcp1_cs_n(cs1),.mcp0_miso(miso0),.mcp1_miso(miso1),.hpd_en(),
        .ddr_addr(),.ddr_bank(),.ddr_cs(),.ddr_ras(),.ddr_cas(),.ddr_we(),.ddr_ck(),.ddr_ck_n(),.ddr_cke(),.ddr_odt(),.ddr_reset_n(),
        .ddr_dm(),.ddr_dq(dq),.ddr_dqs(dqs),.ddr_dqs_n(dqsn));
    reg [1055:0] payload=0;reg [15:0] seq=0;
    integer ack_count=0,note_on=0,note_off=0,audio_frames=0,audible_frames=0,screen_bytes=0,max_cycles=0,last_tick=0,cycles=0;
    reg [15:0] ack_seq;reg [7:0] ack_code,ack_type;reg [767:0] ack_payload;
    reg active_checks=0,guide_seen=0,observed32=0;
    integer pa_muted_checks=0,pa_enabled_checks=0;
    always @(negedge clk)begin
        if(dut.rst_n===1'b0||dut.live_audio_ready===1'b0)begin
            if(pa_en!==1'b1)$fatal(1,"PA enabled during reset/startup");
            pa_muted_checks=pa_muted_checks+1;
        end else if(dut.rst_n===1'b1&&dut.live_audio_ready===1'b1)begin
            if(pa_en!==1'b0)$fatal(1,"PA did not enable after startup");
            pa_enabled_checks=pa_enabled_checks+1;
        end
    end
    // 从实际TX引脚解码完整CRC帧；模块内部valid脉冲不代表UART最终发对了数据。
    wire [7:0] usb_byte;wire usb_byte_valid,usb_frame_valid,usb_bad_frame;
    wire [7:0] usb_frame_type;wire [15:0] usb_frame_seq,usb_frame_length;
    wire [1055:0] usb_frame_payload;
    uart_rx #(.CLKS_PER_BIT(8)) usb_monitor(.clk(clk),.rst_n(rst_n),.rx(uart_tx),
        .data(usb_byte),.valid(usb_byte_valid),.framing_error());
    uart_frame_protocol usb_frames(.clk(clk),.rst_n(rst_n),.rx_data(usb_byte),.rx_valid(usb_byte_valid),
        .frame_valid(usb_frame_valid),.bad_frame(usb_bad_frame),.frame_type(usb_frame_type),
        .frame_seq(usb_frame_seq),.frame_length(usb_frame_length),.frame_payload(usb_frame_payload));
    reg [127:0] screen_name=0;integer screen_position=0;reg [7:0] seen_screen_fields=0;
    wire [7:0] screen_byte;wire screen_byte_valid;
    uart_rx #(.CLKS_PER_BIT(8)) screen_monitor(.clk(clk),.rst_n(rst_n),.rx(screen_tx),.data(screen_byte),.valid(screen_byte_valid),.framing_error());
    always @(posedge clk)begin
        cycles<=cycles+1;
        if(dut.live_sample_tick)last_tick<=cycles;
        if(screen_byte_valid)begin
            screen_bytes<=screen_bytes+1;
            if(screen_byte==8'hff)begin screen_name<=0;screen_position<=0;end
            else if(screen_position<16)begin
                screen_name[127-screen_position*8-:8]<=screen_byte;screen_position<=screen_position+1;
            end
            if(screen_byte==8'h3d)case(screen_name|(128'(screen_byte)<<(120-screen_position*8)))
                "rxSongReady.val=":seen_screen_fields[0]<=1;
                {"rxPlay.val=",40'd0}:seen_screen_fields[1]<=1;
                {"rxPause.val=",32'd0}:seen_screen_fields[2]<=1;
                {"rxPosition.val=",8'd0}:seen_screen_fields[3]<=1;
                {"rxSection.val=",16'd0}:seen_screen_fields[4]<=1;
                {"rxLoop.val=",40'd0}:seen_screen_fields[5]<=1;
                {"rxControl.val=",16'd0}:seen_screen_fields[6]<=1;
                {"rxDdrReady.val=",8'd0}:seen_screen_fields[7]<=1;
                default:;
            endcase
        end
        if(usb_bad_frame)$fatal(1,"invalid actual UART ACK CRC/frame");
        if(usb_frame_valid)begin
            if(usb_frame_type!==8'h81 || usb_frame_length<2 || usb_frame_length>96)
                $fatal(1,"actual UART ACK type/length");
            ack_count<=ack_count+1;ack_seq<=usb_frame_seq;
            ack_type<=usb_frame_payload[7:0];ack_code<=usb_frame_payload[15:8];ack_payload<=usb_frame_payload[767:0];
        end
        if(dut.player_event_valid&&dut.player_event_ready)begin
            if(dut.player_event_op==1)note_on<=note_on+1;else note_off<=note_off+1;
        end
        if(dut.guide_keys!=0)guide_seen<=1;
    end
    always @(negedge clk)if(dut.rst_n&&active_checks)begin
        if(dut.engine_command_done&&dut.engine_command_result!=0)
            $display("CMD_ERROR result=%0d source=%0d id=%0d op=%0d timbre=%0d note=%0d track=%0d",dut.engine_command_result,dut.player_event_source,dut.player_event_id,dut.player_event_op,dut.player_timbre,dut.player_note,dut.player_track);
        if(dut.deadline_error||dut.parameter_error)$fatal(1,"whole engine error deadline=%b parameter=%b components=%b%b%b%b command=%b playing=%b paused=%b seq=%0d",dut.deadline_error,dut.parameter_error,dut.audio_parameter_error,dut.engine_parameter_error,dut.route_parameter_error,dut.engine_command_error,dut.engine_command_error,dut.midi_playing,dut.paused,seq);
        if(dut.engine.sample_valid)begin
            if(dut.voices==32)observed32=1;
            if((^dut.synth_pcm)===1'bx)$fatal(1,"whole PCM X");
            audio_frames=audio_frames+1;if(dut.synth_pcm!=0)audible_frames=audible_frames+1;
            if(cycles-last_tick>max_cycles)max_cycles=cycles-last_tick;
        end
    end
    function automatic [15:0] crc16(input [15:0] old,input [7:0] b);
        reg [15:0] c;begin c=old^{b,8'd0};for(integer bitno=0;bitno<8;bitno=bitno+1)c=c[15] ? (c<<1)^16'h1021:c<<1;crc16=c;end
    endfunction
    task automatic byte_send(input [7:0] b);
        begin @(negedge clk);uart_rx=0;repeat(8)@(negedge clk);
            for(integer bitno=0;bitno<8;bitno=bitno+1)begin uart_rx=b[bitno];repeat(8)@(negedge clk);end
            uart_rx=1;repeat(8)@(negedge clk);
        end
    endtask
    task automatic screen_key(input [7:0] operation,key);
        reg [39:0] message;
        begin
            message={8'ha5,8'h5a,operation,key,8'hff^operation^key};
            for(integer byte_index=0;byte_index<5;byte_index=byte_index+1)begin
                screen_rx=0;repeat(8)@(negedge clk);
                for(integer bitno=0;bitno<8;bitno=bitno+1)begin screen_rx=message[39-byte_index*8-(7-bitno)];repeat(8)@(negedge clk);end
                screen_rx=1;repeat(8)@(negedge clk);
            end
        end
    endtask
    task automatic packet(input [7:0] kind,input integer length,input [7:0] expected);
        reg [15:0] c;integer previous,n;
        begin
            while(dut.resource_response_busy)@(negedge clk);
            previous=ack_count;seq=seq+1;c=16'hffff;
            byte_send(8'h55);byte_send(8'haa);byte_send(1);c=crc16(c,1);
            byte_send(kind);c=crc16(c,kind);byte_send(seq[7:0]);c=crc16(c,seq[7:0]);byte_send(seq[15:8]);c=crc16(c,seq[15:8]);
            byte_send(8'(length));c=crc16(c,8'(length));byte_send(8'(length>>8));c=crc16(c,8'(length>>8));
            for(integer i=0;i<length;i=i+1)begin byte_send(payload[i*8+:8]);c=crc16(c,payload[i*8+:8]);end
            byte_send(c[7:0]);byte_send(c[15:8]);n=0;
            while(ack_count==previous&&n<300000)begin @(negedge clk);n=n+1;end
            if(ack_count!=previous+1||ack_seq!==seq||ack_type!==kind||ack_code!==expected)
                $fatal(1,"packet ACK kind=%h seq=%0d received=%0d/%h code=%0d expected=%0d state=%0d",kind,seq,ack_seq,ack_type,ack_code,expected,dut.resources.state);
            while(dut.resource_response_busy)@(negedge clk);repeat(20)@(negedge clk);
            $display("ACK seq=%0d kind=%h code=%0d at=%0t",seq,kind,ack_code,$time);
        end
    endtask
    task automatic control(input [7:0] operation,input [31:0] v,a);
        begin payload=0;payload[7:0]=operation;payload[39:8]=v;payload[71:40]=a;packet(8'h35,9,0);end
    endtask

    task automatic setting(input [7:0] s,c,m,expected);
        begin payload=0;payload[31:0]={m,c,s,8'd1};packet(8'h3f,4,expected);end
    endtask
    // 输入经过真实ADC整帧和1/4滤波；固定延时不能证明已经到达目标压力。
    task automatic settle_pressure(input integer target,tolerance);
        integer waited,value;
        begin
            waited=0;value=dut.pressure_values[11:0];
            while((value<target-tolerance||value>target+tolerance)&&waited<1000000)begin
                @(negedge clk);waited=waited+1;value=dut.pressure_values[11:0];
            end
            if(waited>=1000000)$fatal(1,"pressure did not settle target=%0d actual=%0d",target,value);
            // 让有界扫描及所有权更新完成，再读同一声部的已提交压力。
            repeat(3000)@(negedge clk);
        end
    endtask
    integer first_pressure,last_pressure,first_generation,starts=0,updates=0,live_slot=-1;
    always @(posedge clk)if(dut.realtime_valid&&dut.synth_ready&&dut.realtime_source==0)begin
        if(dut.realtime_op==1)starts=starts+1;
        if(dut.realtime_op==3)updates=updates+1;
    end
    initial begin
        repeat(6)@(negedge clk);rst_n=1;repeat(25000)@(negedge clk);
        payload=0;packet(8'h3f,0,0);
        if(ack_payload[47:16]!=={8'd16,8'd1,8'd1,8'd1}||ack_payload[79:48]!==`WORKSTATION_BUILD_ID)
            $fatal(1,"pressure defaults/version/build readback");
        setting(0,0,8,0);if(dut.pressure_touch_settings!==11'd128)$fatal(1,"pressure legacy config");
        setting(4,0,8,1);setting(0,3,8,1);setting(0,0,7,1);setting(0,0,65,1);
        payload=0;payload[31:0]={8'd8,8'd0,8'd0,8'd2};packet(8'h3f,4,1);
        payload=0;packet(8'h3f,1,1);
        if(dut.pressure_touch_settings!==11'd128)$fatal(1,"invalid pressure config mutated state");
        setting(1,1,16,0);
        control(1,2,0);repeat(20000)@(negedge clk);
        adc0_values[11:0]=300;settle_pressure(300,16);
        if(!dut.physical_piano_keys[0]||dut.voices!=1||starts!=1)$fatal(1,"pressure note did not start once");
        // 实时声部优先占用预留槽；按owner查实际槽位，不能假定槽0。
        for(integer k=0;k<32;k=k+1)if(dut.engine.control.held[k]&&dut.engine.control.tracks[k*5+:5]==16)live_slot=k;
        if(live_slot<0)$fatal(1,"physical owner slot missing");
        first_pressure=dut.engine.control.pressures[live_slot*7+:7];first_generation=dut.engine.control.generation[live_slot*16+:16];
        adc0_values[11:0]=1100;settle_pressure(1100,16);
        last_pressure=dut.engine.control.pressures[live_slot*7+:7];
        if(last_pressure<=first_pressure||last_pressure<90||updates<1||starts!=1||
           dut.engine.control.generation[live_slot*16+:16]!=first_generation)
            $fatal(1,"continuous pressure not expressive or retriggered first=%0d last=%0d starts=%0d updates=%0d",first_pressure,last_pressure,starts,updates);
        setting(0,0,8,0);repeat(40000)@(negedge clk);
        if(dut.engine.control.pressures[live_slot*7+:7]>=last_pressure||starts!=1)$fatal(1,"held note setting did not update without retrigger");
        adc0_values=0;settle_pressure(0,8);
        if(dut.physical_piano_keys!=0||dut.engine.control.held!=0)$fatal(1,"pressure release stuck");
        // 确认原协议、屏幕/伴奏设置及错误标志未被新协议污染。
        payload=0;packet(8'h3a,0,0);
        if(ack_payload[319:288]!=0||ack_payload[287:256]>=1041||ack_payload[29:28]!=0)
            $fatal(1,"pressure whole audio deadline/error");
        if(dut.deadline_error||dut.parameter_error)$fatal(1,"pressure whole engine error");
        rst_n=0;repeat(10)@(negedge clk);rst_n=1;repeat(25000)@(negedge clk);
        payload=0;packet(8'h3f,0,0);
        if(ack_payload[47:16]!=={8'd16,8'd1,8'd1,8'd1})$fatal(1,"pressure reset defaults");
        complete_test("tb_pressure_touch_uart",ack_count+8);
        $display("PASS tb_pressure_touch_uart ACKs=%0d low=%0d high=%0d starts=%0d updates=%0d",ack_count,first_pressure,last_pressure,starts,updates);$finish;
    end
    initial begin #50000000;$fatal(1,"pressure touch UART timeout");end
endmodule
