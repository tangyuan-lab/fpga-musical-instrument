`timescale 1ns/1ps
`include "rtl/workstation_build_identity.vh"
`include "rtl/damping_defaults.vh"
`include "sim/ddr_phy_model.sv"
`include "sim/mcp3208_dynamic_model.sv"
module tb_r7_bluetooth_uart;
    GSR GSR(.GSRI(1'b1));
    `include "sim/result.svh"
    reg clk=0;always #10 clk=~clk;
    reg rst_n=0,uart_rx=1,screen_rx=1,bt_rx=1;
    wire uart_tx,screen_tx,bt_tx,pa_en;wire [7:0] led_n;wire [31:0] dq;wire [3:0] dqs,dqsn;
    wire mcp_clk,mcp_mosi,cs0,cs1,miso0,miso1;reg [95:0] adc0_values=0,adc1_values=0;
    mcp3208_dynamic_model adc0(.cs_n(cs0),.sclk(mcp_clk),.mosi(mcp_mosi),.values(adc0_values),.miso(miso0));
    mcp3208_dynamic_model adc1(.cs_n(cs1),.sclk(mcp_clk),.mosi(mcp_mosi),.values(adc1_values),.miso(miso1));
    mega138_models8_top #(.BT_CLKS_PER_BIT(8),.USB_CLKS_PER_BIT(8),.SCREEN_CLKS_PER_BIT(8),.CALIBRATION_SAMPLES(1),
        .STARTUP_CYCLES(10),.SCREEN_STARTUP_CYCLES(100),.SCREEN_UPDATE_CYCLES(5000)) dut(
        .bt_rx_i(bt_rx),.bt_tx_o(bt_tx),.sys_clk(clk),.sys_rst_n(rst_n),.uart_rx_i(uart_rx),.uart_tx_o(uart_tx),.mode_key_n(1'b1),.timbre_key_n(1'b1),
        .led_n(led_n),.hp_bck(),.hp_ws(),.hp_din(),.pa_en(pa_en),.screen_rx_i(screen_rx),.screen_tx_o(screen_tx),
        .mcp0_sclk(mcp_clk),.mcp1_sclk(),.mcp0_mosi(mcp_mosi),.mcp1_mosi(),.mcp0_cs_n(cs0),.mcp1_cs_n(cs1),.mcp0_miso(miso0),.mcp1_miso(miso1),.hpd_en(),
        .ddr_addr(),.ddr_bank(),.ddr_cs(),.ddr_ras(),.ddr_cas(),.ddr_we(),.ddr_ck(),.ddr_ck_n(),.ddr_cke(),.ddr_odt(),.ddr_reset_n(),
        .ddr_dm(),.ddr_dq(dq),.ddr_dqs(dqs),.ddr_dqs_n(dqsn));
    // 仅加速数字ADC模型的串行时钟；实板3.3V时序不由此回归签核。
    defparam dut.adc_spi.HALF_PERIOD=4;
    integer checks=0,bt_replies=0,usb_replies=0,frames=0,controls=0,panics=0;
    reg active=0;reg [767:0] bt_reply,usb_reply;
    reg [255:0] expected_status;
    reg [15:0] bt_seq_seen,usb_seq_seen,bt_len_seen;
    wire [7:0] bb,ub;wire bv,uv,bframe,uframe,bad_b,bad_u;
    wire [7:0] bkind,ukind;wire [15:0] bseq,useq,blen,ulen;wire [1055:0] bp,up;
    uart_rx #(.CLKS_PER_BIT(8)) bm(.clk(clk),.rst_n(rst_n),.rx(bt_tx),.data(bb),.valid(bv),.framing_error());
    uart_rx #(.CLKS_PER_BIT(8)) um(.clk(clk),.rst_n(rst_n),.rx(uart_tx),.data(ub),.valid(uv),.framing_error());
    uart_frame_protocol bfm(.clk(clk),.rst_n(rst_n),.rx_data(bb),.rx_valid(bv),.frame_valid(bframe),.bad_frame(bad_b),.frame_type(bkind),.frame_seq(bseq),.frame_length(blen),.frame_payload(bp));
    uart_frame_protocol ufm(.clk(clk),.rst_n(rst_n),.rx_data(ub),.rx_valid(uv),.frame_valid(uframe),.bad_frame(bad_u),.frame_type(ukind),.frame_seq(useq),.frame_length(ulen),.frame_payload(up));
    always @(posedge clk)begin
        // 独立按契约逐字节采集同一接受沿，串口发送期间寄存器可以继续平滑变化。
        if(dut.bt_link.frame_valid&&dut.bt_link.frame_payload[15:8]==4&&dut.bt_lease)begin
            expected_status=0;
            expected_status[7:0]=1;expected_status[15:8]=dut.app_mode;
            expected_status[23:16]=dut.live_patch;expected_status[31:24]=dut.screen_patch;
            expected_status[39:32]=dut.piano_volume;expected_status[47:40]=dut.midi_volume;
            expected_status[55:48]=dut.master_boost;expected_status[63:56]=dut.delay_mix;
            expected_status[71:64]=dut.reverb_mix;expected_status[79:72]=dut.chorus_mix;
            expected_status[87:80]=dut.chorus_depth;expected_status[95:88]=dut.chorus_rate;
            expected_status[103:96]=dut.feedback;expected_status[119:104]=dut.delay_time;
            expected_status[120]=dut.storage_ready;expected_status[121]=dut.midi_playing;
            expected_status[122]=dut.paused;expected_status[123]=dut.deadline_error;
            expected_status[124]=dut.synth_clipped||dut.master_clipped;
            expected_status[159:128]=dut.directory_revision;expected_status[191:160]=dut.position;
            expected_status[223:192]=dut.song_ready_mask;expected_status[231:224]=dut.voices;
            expected_status[239:232]=dut.live_fx_target;expected_status[247:240]=dut.song_fx_target;
            expected_status[248]=dut.limiter_enabled;expected_status[250:249]=dut.limiter_release;
        end
        if(bad_b||bad_u)$fatal(1,"BT_TOP corrupt actual TX frame");
        if(bframe)begin
            if(bkind!==8'h81||blen<16||blen>64)$fatal(1,"BT_TOP response format");
            bt_reply<=bp[767:0];bt_seq_seen<=bseq;bt_len_seen<=blen;bt_replies<=bt_replies+1;
        end
        if(uframe)begin
            if(ukind!==8'h81||ulen<2||ulen>96)$fatal(1,"BT_TOP USB response format");
            usb_reply<=up[767:0];usb_seq_seen<=useq;usb_replies<=usb_replies+1;
        end
        if(active&&dut.engine.sample_valid)begin
            frames<=frames+1;if((^dut.synth_pcm)===1'bx)$fatal(1,"BT_TOP PCM unknown");
        end
        if(active&&(dut.deadline_error||dut.audio_parameter_error||dut.route_parameter_error))$fatal(1,"BT_TOP audio path error");
        if(dut.bt_command_valid&&dut.bt_command_ready)controls<=controls+1;
        if(dut.emergency_stop)panics<=panics+1;
    end
    task check(input condition,input [8*100-1:0] message);
        begin checks=checks+1;if(condition!==1'b1)$fatal(1,"BT_TOP %0s",message);end
    endtask
    function automatic [15:0] crc16(input [15:0] prior,input [7:0] b);
        reg [15:0] c;integer j;begin c=prior^{b,8'd0};for(j=0;j<8;j=j+1)c=c[15]?(c<<1)^16'h1021:c<<1;crc16=c;end
    endfunction
    task byte_send(input bit bluetooth,input [7:0] b);
        integer j;begin
            @(negedge clk);if(bluetooth)bt_rx=0;else uart_rx=0;repeat(8)@(negedge clk);
            for(j=0;j<8;j=j+1)begin if(bluetooth)bt_rx=b[j];else uart_rx=b[j];repeat(8)@(negedge clk);end
            if(bluetooth)bt_rx=1;else uart_rx=1;repeat(8)@(negedge clk);
        end
    endtask
    task packet(input bit bluetooth,input [7:0] kind,input [15:0] sn,input integer length,input [1055:0] data,input [7:0] expected);
        integer j,prior,n;reg [15:0] c;
        begin
            prior=bluetooth?bt_replies:usb_replies;c=16'hffff;
            byte_send(bluetooth,8'h55);byte_send(bluetooth,8'haa);byte_send(bluetooth,1);c=crc16(c,1);
            byte_send(bluetooth,kind);c=crc16(c,kind);
            byte_send(bluetooth,sn[7:0]);c=crc16(c,sn[7:0]);byte_send(bluetooth,sn[15:8]);c=crc16(c,sn[15:8]);
            byte_send(bluetooth,8'(length));c=crc16(c,8'(length));byte_send(bluetooth,8'(length>>8));c=crc16(c,8'(length>>8));
            for(j=0;j<length;j=j+1)begin byte_send(bluetooth,data[j*8+:8]);c=crc16(c,data[j*8+:8]);end
            byte_send(bluetooth,c[7:0]);byte_send(bluetooth,c[15:8]);n=0;
            while((bluetooth?bt_replies:usb_replies)==prior&&n<150000)begin @(negedge clk);n=n+1;end
            if((bluetooth?bt_replies:usb_replies)!=prior+1)$fatal(1,"BT_TOP reply timeout bt=%0d kind=%h seq=%0d cmd=%0d resource=%0d lease=%b idle=%b",bluetooth,kind,sn,dut.commands.state,dut.resources.state,dut.bt_lease,dut.bt_claim_idle);
            check((bluetooth?bt_seq_seen:usb_seq_seen)===sn,"actual reply sequence");
            check((bluetooth?bt_reply[7:0]:usb_reply[7:0])===kind,"actual reply kind");
            if((bluetooth?bt_reply[15:8]:usb_reply[15:8])!==expected)$fatal(1,"BT_TOP reply code expected=%0d actual=%0d bt=%0d seq=%0d",expected,bluetooth?bt_reply[15:8]:usb_reply[15:8],bluetooth,sn);
            checks=checks+1;if(bluetooth)check(bt_reply[127:96]===`WORKSTATION_BUILD_ID,"actual reply current build");
            repeat(30)@(negedge clk);$display("BT_TOP ACK bt=%0d seq=%0d kind=%h code=%0d time=%0t",bluetooth,sn,kind,expected,$time);
        end
    endtask
    reg [63:0] token;reg [1055:0] request;integer sequence_number=2,n,before_count;
    task control(input [7:0] operation,input [31:0] value,aux);
        begin
            sequence_number=sequence_number+1;request=0;request[151:0]={aux,value,operation,token,8'd5,8'd1};
            packet(1,8'h42,16'(sequence_number),19,request,0);
            check(bt_len_seen==17&&bt_reply[135:128]==0,"control ACK waits for actual successful service");
        end
    endtask
    initial begin
        repeat(10)@(negedge clk);rst_n=1;n=0;
        while((dut.storage_ready!==1'b1||dut.live_audio_ready!==1'b1)&&n<1000000)begin @(negedge clk);n=n+1;end
        check(dut.storage_ready&&dut.live_audio_ready,"bounded real top startup with functional DDR PHY");active=1;
        packet(0,8'h3a,1,0,0,0);check(usb_reply[63:32]===`WORKSTATION_BUILD_ID,"USB identity retained");
        request=0;request[79:0]={64'h123456789abcdef0,8'd0,8'd1};packet(1,8'h42,1,10,request,0);token=bt_reply[95:32];
        request=0;request[143:0]={token,64'h123456789abcdef0,8'd1,8'd1};packet(1,8'h42,2,18,request,0);
        check(dut.bt_lease&&controls==0&&!dut.midi_playing,"claim never executes or starts playback");
        request=0;request[71:0]={32'd0,32'd3,8'd1};packet(0,8'h35,2,9,request,3);
        check(dut.app_mode==0,"leased USB mode request rejected without mutation");
        control(1,2,0);check(dut.app_mode==2,"Bluetooth changes real mode service to performance");
        control(12,19,0);check(dut.live_patch==19,"Bluetooth guitar actual live patch");
        control(13,20,0);check(dut.screen_patch==20,"Bluetooth bass actual screen patch");
        control(52,0,67);check(dut.piano_volume==67,"live volume actual legacy service");
        control(52,1,31);check(dut.midi_volume==31,"song volume actual legacy service");
        control(52,2,3);check(dut.master_boost==3,"master gain actual service");
        control(19,25,0);control(20,33,0);control(41,17,0);
        control(42,11,0);control(43,9,0);control(21,1234,0);control(22,48,0);
        // 参数在原48k采样沿提交，不以发送草稿代替实际回读。
        repeat(3000)@(negedge clk);
        sequence_number=sequence_number+1;request=0;request[79:0]={token,8'd4,8'd1};packet(1,8'h42,16'(sequence_number),10,request,0);
        check(bt_len_seen==48,"status full 32 bytes");
        check(bt_reply[135:128]==1&&bt_reply[143:136]==2,"status schema and actual mode");
        check(bt_reply[151:144]==19&&bt_reply[159:152]==20,"status live and screen patches");
        check(bt_reply[167:160]==67&&bt_reply[175:168]==31&&bt_reply[183:176]==3,"status actual volumes and gain");
        check(bt_reply[383:128]===expected_status,"status all bytes match actual acceptance-edge snapshot");
        check(bt_reply[247:232]==1234,"status delay unit is samples");
        n=0;
        while((dut.delay_mix!=25||dut.reverb_mix!=33||dut.chorus_mix!=17||dut.feedback!=48||dut.chorus_depth!=11||dut.chorus_rate!=9)&&n<200000)begin @(negedge clk);n=n+1;end
        check(n<200000,"actual smoothed effects reach requested targets within original bound");
        control(12,10,0);before_count=controls;
        packet(1,8'h42,16'(sequence_number),19,request,0);check(controls==before_count,"same sequence retry no duplicate control");
        request[87:80]=8'hff;packet(1,8'h42,16'(sequence_number),19,request,5);check(controls==before_count,"conflicting replay no control");
        sequence_number=sequence_number+1;request=0;request[151:0]={32'd0,32'd0,8'hff,token,8'd5,8'd1};packet(1,8'h42,16'(sequence_number),19,request,6);
        check(controls==before_count,"unsupported control not accepted");
        packet(0,8'h3b,3,1,1056'd1,0);check(!dut.bt_lease&&panics>0,"USB panic revokes BT ownership");
        sequence_number=sequence_number+1;request=0;request[79:0]={token,8'd4,8'd1};packet(1,8'h42,16'(sequence_number),10,request,2);
        request=0;request[71:0]={32'd0,32'd2,8'd1};packet(0,8'h35,4,9,request,0);check(dut.app_mode==2,"USB recovered after panic");
        check(controls==dut.bt_accepted_commands,"accepted counter equals real handshake");check(frames>15,"audio continued during Bluetooth and USB activity");
        complete_test("tb_r7_bluetooth_uart",checks);$display("PASS tb_r7_bluetooth_uart CHECKS=%0d BT_ACK=%0d USB_ACK=%0d FRAMES=%0d",checks,bt_replies,usb_replies,frames);$finish;
    end
    initial begin #100000000;$fatal(1,"BT_TOP overall bounded timeout");end
endmodule
