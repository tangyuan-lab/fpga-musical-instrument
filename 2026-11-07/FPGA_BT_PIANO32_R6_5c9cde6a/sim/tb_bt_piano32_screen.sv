`timescale 1ns/1ps
`include "rtl/workstation_build_identity.vh"
`include "rtl/damping_defaults.vh"
`include "sim/ddr_phy_model.sv"
`include "sim/mcp3208_dynamic_model.sv"
module tb_bt_piano32_screen;
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
    integer old_serial;
    task automatic source_gain(input [7:0] op,percent,expected_result);
        begin
            payload=0;packet(8'h37,0,0);old_serial=ack_payload[79:48];
            payload=0;payload[7:0]=op;payload[15:8]=percent;packet(8'he3,2,0);
            payload=0;packet(8'h37,0,0);
            if(ack_payload[79:48]==old_serial||ack_payload[31:24]!=op||ack_payload[607:576]!=percent||ack_payload[39:32]!=expected_result)
                $fatal(1,"source completion did not match accepted E3 request");
        end
    endtask
    // 只缩短演示等待参数以验证顶层路径；真实50MHz/48k/64模态及音源参数保持。
    // 默认5M/100M周期由独立真实时基长测和最终资格验证负责，不能以本测试代替。
    defparam dut.test_center.NOTE_GAP_CYCLES=2048;
    defparam dut.test_center.HOLD_CYCLES=32768;
    integer top_checks=0,requests=0,completions=0,prev_request=-10000,wait_cycles=0,hold_frames=0,full_cycle=-1;
    reg [31:0] tracked_session=0;
    reg [223:0] held_notes;
    reg [159:0] held_timbres,held_tracks;
    task require(input condition,input [8*120-1:0] label_text);
        begin top_checks=top_checks+1;if(condition!==1'b1)$fatal(1,"PIANO32_TOP %0s requests=%0d completions=%0d",label_text,requests,completions);end
    endtask
    always @(posedge clk)if(dut.rst_n && !dut.synth_panic && dut.test_active && dut.test_kind==2)begin
        if(tracked_session!==dut.test_session)begin
            tracked_session=dut.test_session;requests=0;completions=0;prev_request=-10000;hold_frames=0;full_cycle=-1;
        end
        if(dut.test_event_valid===1 && dut.synth_ready===1)begin
            require(dut.engine.command_valid===1 && dut.engine.command_source===3 && dut.engine.command_track===18,"REAL_ENGINE_OWNER");
            require(dut.engine.command_note===48+requests && dut.engine.command_timbre===10,"ASCENDING_REAL_PIANO");
            require(dut.engine.command_id==={dut.test_session[23:0],2'b11,requests[5:0]},"REQUEST_IDENTITY");
            require(cycles-prev_request>=2048,"NOT_SIMULTANEOUS_REQUESTS");
            prev_request=cycles;requests=requests+1;
            $display("TOP_PIANO_ACCEPT session=%0d index=%0d note=%0d cycle=%0d",dut.test_session,requests-1,dut.engine.command_note,cycles);
        end
        if(dut.engine_command_done===1)begin
            require(dut.engine_command_result===0,"ACTUAL_ENGINE_COMPLETION");completions=completions+1;
            if(completions==32)begin
                full_cycle=cycles;held_notes=dut.engine.notes;held_timbres=dut.engine.timbres;held_tracks=dut.engine.tracks;
            end
        end
    end
    always @(negedge clk)if(dut.rst_n && !dut.synth_panic && dut.test_active && dut.test_kind==2 && full_cycle>=0)begin
        if(dut.engine.sample_valid)begin
            require(dut.voice_mask===32'hffffffff && dut.engine.held===32'hffffffff,"HOLD_REAL_32_SLOTS");
            require(dut.engine.notes===held_notes && dut.engine.timbres===held_timbres && dut.engine.tracks===held_tracks,"HOLD_STABLE_IDENTITY");
            if(cycles-full_cycle>4)require(dut.voices===32,"HOLD_REAL_VOICE_COUNT");
            for(integer slot=0;slot<32;slot=slot+1)begin
                require(dut.engine.timbres[slot*5+:5]===10 && dut.engine.tracks[slot*5+:5]===18,"EVERY_SLOT_PIANO_OWNER");
                require((^dut.engine.piano_pcm[slot*16+:16])!==1'bx,"EVERY_SLOT_KNOWN_PCM");
            end
            hold_frames=hold_frames+1;
        end
    end
    task wait_automatic_finish;
        begin
            wait_cycles=0;
            while(dut.test_active && wait_cycles<180000)begin @(negedge clk);wait_cycles=wait_cycles+1;end
            require(!dut.test_active,"TOP_AUTO_FINISH_BOUNDED");
            require(requests==32 && completions==32 && dut.piano32_completed_count===32,"TOP_32_ACTUAL_COMPLETIONS");
            require(hold_frames>=30 && dut.test_result===0 && !dut.piano32_failed,"HOLD_COMPLETED_NO_ERROR");
            repeat(12)@(negedge clk);
            require(dut.voice_mask===0 && dut.voices===0,"AUTO_FINISH_CLEARS_REAL_ENGINE");
        end
    endtask
    reg [479:0] expected_snapshot;
    reg [23:0] expected_sequence;
    reg snapshot_valid=0;
    reg [31:0] screen_words[0:14];
    reg [14:0] received_words=0;
    integer wire_index=-1,atomic_frames=0;
    reg number_active=0;
    reg [31:0] number_value=0,wire_xor;
    always @(posedge clk)begin
        if(dut.rst_n && dut.display.service.telemetry_capture_enable && dut.ui_view==8)begin
            expected_snapshot=dut.screen_telemetry;
            expected_sequence=dut.display.service.telemetry_sequence+1'b1;snapshot_valid=1;
        end
        if(screen_byte_valid)begin
            if(screen_byte==8'h3d)begin
                wire_index=-1;
                if(screen_name[127:104]=="rxP")
                    wire_index=(screen_name[103:96]-8'd48)*10+screen_name[95:88]-8'd48;
                number_active=1;number_value=0;
            end else if(number_active && screen_byte>=48 && screen_byte<=57)
                number_value=number_value*10+screen_byte-48;
            else if(number_active && screen_byte==8'hff)begin
                number_active=0;
                if(wire_index>=0 && wire_index<15)begin
                    screen_words[wire_index]=number_value;received_words[wire_index]=1;
                end else if(wire_index==15 && number_value[31:28]==7 && number_value[3:0]==8)begin
                    require(snapshot_valid && received_words==15'h7fff,"SCREEN_ATOMIC_ALL_FIELDS");
                    require(number_value[27:4]===expected_sequence,"SCREEN_ATOMIC_SEQUENCE");
                    wire_xor=32'h13579bdf;
                    for(integer w=0;w<15;w=w+1)begin
                        require(screen_words[w]===expected_snapshot[w*32+:32],"SCREEN_WIRE_SNAPSHOT");
                        if(w<14)wire_xor=wire_xor^screen_words[w];
                    end
                    require(screen_words[14]===wire_xor,"SCREEN_FIELD_CHECK");
                    require(screen_words[0]===32'h50333201 && screen_words[1]===15,"SCREEN_CAPABILITY");
                    require({screen_words[3][15:0],screen_words[2][15:0]}===`WORKSTATION_BUILD_ID,"SCREEN_BUILD_BINDING");
                    atomic_frames=atomic_frames+1;received_words=0;snapshot_valid=0;
                end
            end
        end
    end
    reg [31:0] session_before,watchdog_before;
    initial begin
        repeat(6)@(negedge clk);rst_n=1;repeat(20000)@(negedge clk);active_checks=1;
        require(dut.rst_n && dut.live_audio_ready,"TOP_READY");
        payload=0;payload[7:0]=8'h61;payload[15:8]=2;packet(8'he5,2,0);
        require(dut.test_active && dut.test_kind==2,"USB_START_REACHES_PROGRESSIVE");
        payload=0;payload[7:0]=8'h63;packet(8'he5,2,0);
        wait_automatic_finish();
        // 实际屏幕RX五字节入口，经原解析器/顶层mux进入同一递进器。
        screen_key(8'h61,2);repeat(8)@(negedge clk);
        require(dut.test_active && dut.test_kind==2,"SCREEN_START_REACHES_PROGRESSIVE");
        screen_key(8'h63,0);wait_automatic_finish();
        require(dut.piano32_status.phase==4 && dut.piano32_status.progress==32,"REAL_COMPLETION_RETAINED");
        screen_key(8'h67,8'h31);repeat(30)@(negedge clk);
        require(dut.test_active && dut.piano32_status.owner==2 && dut.piano32_status.token_valid &&
                dut.piano32_status.token==8'h31,"TAGGED_SCREEN_START");
        session_before=dut.test_session;screen_key(8'h67,8'h31);repeat(8)@(negedge clk);
        require(dut.test_session===session_before,"DUPLICATE_START_NOT_RETRIGGERED");
        watchdog_before=dut.test_center.legacy.watchdog;screen_key(8'h6e,8'h30);repeat(8)@(negedge clk);
        require(dut.test_center.legacy.watchdog>watchdog_before,"OLD_TOKEN_CANNOT_KEEP_ALIVE");
        watchdog_before=dut.test_center.legacy.watchdog;screen_key(8'h63,0);repeat(8)@(negedge clk);
        require(dut.test_center.legacy.watchdog>watchdog_before,"UNTAGGED_CANNOT_KEEP_TAGGED_ALIVE");
        screen_key(8'h6e,8'h31);repeat(8)@(negedge clk);
        require(dut.test_center.legacy.watchdog<100,"MATCHED_TOKEN_HEARTBEAT");
        screen_key(8'h6f,8'h30);repeat(8)@(negedge clk);require(dut.test_active,"OLD_TOKEN_CANNOT_STOP_NEW_SESSION");
        screen_key(8'h6f,8'h31);repeat(20)@(negedge clk);
        require(!dut.test_active && dut.voice_mask===0 && dut.voices===0,"SCREEN_STOP_CLEARS_REAL_ENGINE");
        require(dut.piano32_status.phase==5,"MANUAL_STOP_NOT_AUTOMATIC_SUCCESS");
        screen_key(8'h67,8'h32);repeat(30)@(negedge clk);
        screen_key(8'h6f,8'h31);repeat(8)@(negedge clk);require(dut.test_active && dut.piano32_status.token==8'h32,"LATE_OLD_STOP_IGNORED");
        // 只在命令接收边界注入同沿冲突；其余会话都通过实际UART字节进入。
        session_before=dut.test_session;
        @(negedge clk);force dut.diagnostic_control_valid=1;force dut.diagnostic_op=8'h62;force dut.diagnostic_value=0;
        force dut.screen_valid=1;force dut.screen_op=8'h67;force dut.screen_value=8'h33;
        @(negedge clk);release dut.diagnostic_control_valid;release dut.diagnostic_op;release dut.diagnostic_value;
        release dut.screen_valid;release dut.screen_op;release dut.screen_value;
        repeat(20)@(negedge clk);
        require(!dut.test_active && dut.test_session===session_before && dut.voice_mask===0,"USB_STOP_BEATS_SAME_EDGE_SCREEN_START");
        screen_key(8'h67,8'h31);repeat(20)@(negedge clk);
        require(!dut.test_active && dut.test_session===session_before,"OLD_REQUEST_REUSE_REJECTED");
        wait_cycles=0;while(atomic_frames<2 && wait_cycles<80000)begin @(negedge clk);wait_cycles=wait_cycles+1;end
        require(atomic_frames>=2,"REAL_SCREEN_TX_COMMITTED_FRAMES");
        wait_cycles=requests;repeat(5000)@(negedge clk);require(requests==wait_cycles,"NO_REQUEST_AFTER_STOP");
        require(audio_frames>100 && audible_frames>0 && max_cycles<1041,"REAL_AUDIO_CONTINUES");
        complete_test("tb_bt_piano32_screen",top_checks);
        $display("PASS tb_bt_piano32_screen CHECKS=%0d frames=%0d audible=%0d maxdeadline=%0d",top_checks,audio_frames,audible_frames,max_cycles);$finish;
    end
    initial begin #16000000;$fatal(1,"PIANO32_TOP_TIMEOUT");end
endmodule
