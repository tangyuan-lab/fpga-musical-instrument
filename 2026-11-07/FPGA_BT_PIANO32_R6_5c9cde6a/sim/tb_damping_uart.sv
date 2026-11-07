`timescale 1ns/1ps
`include "rtl/workstation_build_identity.vh"
`include "rtl/damping_defaults.vh"
`include "sim/ddr_phy_model.sv"
`include "sim/mcp3208_dynamic_model.sv"
module tb_damping_uart;
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
    reg [7:0] song[0:161];integer i;
    initial begin
        $readmemh("sim/song16.mem",song);repeat(6)@(negedge clk);rst_n=1;
        repeat(1000)@(negedge clk);active_checks=1;
        payload=0;packet(8'h3a,0,0);
        if(ack_payload[23:16]!==8'd1||ack_payload[63:32]!==`WORKSTATION_BUILD_ID||ack_payload[27:24]!==4'hf)
            $fatal(1,"hardware status identity/ready %h",ack_payload[63:16]);
        payload=0;packet(8'h3d,0,0);
        if(usb_frame_length!==16 || ack_payload[31:16]!==16'h0301 || ack_payload[127:32]!==`DAMPING_DEFAULTS)
            $fatal(1,"default damping query length/version/data");
        control(44,32'h00a209e1,19);
        payload=0;packet(8'h3d,0,0);
        if(ack_payload[95:64]!==32'h00a209e1 || ack_payload[63:32]!==`DAMPING_PIANO_DEFAULT || ack_payload[127:96]!==`DAMPING_BASS_DEFAULT)
            $fatal(1,"damping write/readback or other timbre corruption");
        payload=0;payload[7:0]=44;payload[39:8]=32'h01000000;payload[71:40]=19;packet(8'h35,9,1);
        payload=0;payload[7:0]=44;payload[39:8]=32'h00e08699;payload[71:40]=10;packet(8'h35,9,1);
        payload=0;packet(8'h3d,0,0);
        if(ack_payload[95:64]!==32'h00a209e1)$fatal(1,"rejected damping command mutated parameters");
        control(44,0,19);payload=0;packet(8'h3d,0,0);
        if(ack_payload[95:64]!==0)$fatal(1,"legacy mode did not read back");
        control(44,`DAMPING_GUITAR_DEFAULT,19);
        payload=0;packet(8'h3c,0,0);
        if(ack_payload[23:16]!==8'd1 || (^ack_payload[95:32])===1'bx) $fatal(1,"chord query version/X");
        // 资源→诊断→资源切换必须保留各自序号/长度/数据，专门覆盖实板E5错发旧目录。
        payload=0;payload[7:0]=8'h64;payload[15:8]=1;packet(8'he5,2,0);
        payload=0;packet(8'he6,0,0);
        if(ack_payload[47:16]!==32'h3833314e)$fatal(1,"diagnostic runtime UART payload");
        payload=0;packet(8'h3a,0,0);
        if(ack_payload[63:32]!==`WORKSTATION_BUILD_ID)$fatal(1,"resource after diagnostic UART payload");
        control(1,3,0);
        // 真实UART、CRC与ACK；上传并经DDR回读校验，不从测试台直接填解析缓存。
        payload=0;payload[47:16]=162;payload[79:48]=32'h20253e1b;payload[207:80]=128'h1234;payload[239:208]=1;payload[527:496]=5000;
        packet(8'h32,74,0);
        payload=0;for(i=0;i<128;i=i+1)payload[32+i*8+:8]=song[i];packet(8'h33,132,0);
        payload=128;for(i=0;i<34;i=i+1)payload[32+i*8+:8]=song[128+i];packet(8'h33,38,0);
        payload=32'h20253e1b;packet(8'h34,4,0);
        if(dut.ddr.writes!=162||dut.ddr.reads!=1024)$fatal(1,"raw song did not traverse DDR w=%0d r=%0d",dut.ddr.writes,dut.ddr.reads);
        // 兼容24字节配器：本段先默认钢琴，逐轨配置再覆盖为10/19/20。
        payload=0;payload[7:0]=2;payload[47:16]=24;payload[79:48]=32'h2d6a7f93;payload[207:80]=128'h1234;payload[239:208]=1;
        packet(8'h32,74,0);
        payload=0;payload[95:64]=5000;payload[127:96]={4{8'd10}};payload[159:128]={4{8'd100}};payload[183:176]=10;
        packet(8'h33,28,0);payload=32'h2d6a7f93;packet(8'h34,4,0);
        if(!dut.selected_ready)$fatal(1,"song not published");
        // PLAY解析已加载的曲谱；先解析再设置各轨配器。
        control(3,0,0);repeat(5000)@(negedge clk);control(4,0,0);
        for(i=0;i<16;i=i+1)control(24,i%3==0 ? 10:i%3==1 ? 19:20,i);
        control(19,20,0);control(20,20,0);control(21,128,0);control(22,32,0);control(41,32,0);
        payload=0;payload[7:0]=8'h60;payload[15:8]=7;packet(8'he5,2,0);
        payload=0;payload[7:0]=8'h64;payload[15:8]=1;packet(8'he5,2,0);
        for(i=0;i<8;i=i+1)adc0_values[i*12+:12]=3000;
        for(i=0;i<8;i=i+1)adc1_values[i*12+:12]=3000;
        repeat(40000)@(negedge clk);
        screen_key(1,0);control(4,0,0);repeat(20000)@(negedge clk);
        if(!observed32||dut.delay_mix!=20||dut.reverb_mix!=20||dut.chorus_mix!=32||dut.ui_view!=7)
            $fatal(1,"parallel load incomplete voices32=%b effects=%0d/%0d/%0d view=%0d",observed32,dut.delay_mix,dut.reverb_mix,dut.chorus_mix,dut.ui_view);
        if(note_on<16||audible_frames==0||!guide_seen)$fatal(1,"whole playback vacuous on=%0d audible=%0d guide=%b",note_on,audible_frames,guide_seen);
        payload=0;packet(8'h39,0,0);if(ack_payload[23:16]!=2||ack_payload[31:24]!=16)$fatal(1,"track snapshot version");
        // 播放期BEGIN应拒绝；存储背压不影响音频帧。
        payload=0;payload[47:16]=162;packet(8'h32,74,4);
        control(5,0,0);repeat(20000)@(negedge clk);
        if(dut.midi_playing||dut.player.flushing)$fatal(1,"song stop incomplete");
        if(dut.voices==0)$fatal(1,"song stop killed live keys");
        screen_key(0,0);adc0_values=0;adc1_values=0;
        // 数据CRC错误不得破坏已发布曲谱。
        payload=0;payload[47:16]=162;payload[79:48]=32'h12345678;payload[207:80]=128'h5678;payload[239:208]=2;payload[527:496]=5000;packet(8'h32,74,0);
        payload=0;for(i=0;i<128;i=i+1)payload[32+i*8+:8]=song[i];packet(8'h33,132,0);
        payload=128;for(i=0;i<34;i=i+1)payload[32+i*8+:8]=song[128+i];packet(8'h33,38,0);
        payload=32'h12345678;packet(8'h34,4,3);
        if(!dut.selected_ready)$fatal(1,"bad replacement destroyed valid song");
        // CRC正确但结构错误：必须真实回读暂存曲、解析失败、再从DDR恢复原曲。
        payload=0;payload[47:16]=162;payload[79:48]=32'h57220e8d;payload[207:80]=128'h5678;payload[239:208]=2;payload[527:496]=5000;packet(8'h32,74,0);
        payload=0;for(i=0;i<128;i=i+1)payload[32+i*8+:8]=song[i];packet(8'h33,132,0);
        payload=128;for(i=0;i<34;i=i+1)payload[32+i*8+:8]=i==33 ? 8'd1:song[128+i];packet(8'h33,38,0);
        payload=32'h57220e8d;packet(8'h34,4,5);
        if(!dut.selected_ready||dut.player.parser_error)$fatal(1,"parse rollback did not restore previous song");
        payload=0;packet(8'h3a,0,0);
        if((^ack_payload[415:16])===1'bx||ack_payload[95:64]==0||ack_payload[95:64]!==ack_payload[127:96]||ack_payload[159:128]!==0)
            $fatal(1,"hardware DDR request/response/error counters");
        if(ack_payload[287:256]>=1041||ack_payload[319:288]!==0||ack_payload[415:384]==0)
            $fatal(1,"hardware audio counters");
        $display("CHECK hardware build=%h req=%0d resp=%0d max=%0d audio=%0d",ack_payload[63:32],ack_payload[95:64],ack_payload[127:96],ack_payload[287:256],ack_payload[415:384]);
        dut.ddr.online=0;repeat(30)@(negedge clk);
        if(dut.selected_ready)$fatal(1,"song remained ready after calibration loss");
        payload=0;packet(8'h3a,0,0);
        if(ack_payload[25]!==0||ack_payload[383:352]==0)$fatal(1,"hardware calibration loss not observed");
        if(screen_bytes<50||audio_frames<30||seen_screen_fields!==8'hff)$fatal(1,"parallel screen/audio inactive fields=%h",seen_screen_fields);
        if(pa_muted_checks<6||pa_enabled_checks<20)$fatal(1,"PA startup checker not exercised");
        $display("CHECK PA muted=%0d enabled=%0d",pa_muted_checks,pa_enabled_checks);
        complete_test("tb_damping_uart",22);
        $display("PASS tb_damping_uart ACKs=%0d audio_frames=%0d audible=%0d screen_bytes=%0d max_cycles=%0d",ack_count,audio_frames,audible_frames,screen_bytes,max_cycles);$finish;
    end
    initial begin #50000000;$fatal(1,"whole workstation timeout");end
endmodule
