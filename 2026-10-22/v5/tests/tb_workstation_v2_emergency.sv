`timescale 1ns/1ps
module tb_workstation_v2_emergency;
    reg clk=0;always #10 clk=~clk;
    reg rst_n=0,frame_valid=0;reg [7:0] frame_type=0;reg [15:0] seq=0,len=0;reg [1055:0] payload=0;
    wire normal_valid,panic,abort_upload,normal_response_valid,normal_busy,response_valid;
    wire [15:0] normal_seq,response_seq;wire [7:0] normal_length,response_length;wire [767:0] normal_payload,response_payload;
    reg tx_busy=0;reg [7:0] tx_count=0;reg hold_tx=0;
    always @(posedge clk) begin
        if(!rst_n) begin tx_busy<=0;tx_count<=0;end
        else if(hold_tx) tx_busy<=1;
        else if(response_valid) begin tx_busy<=1;tx_count<=20;end
        else if(tx_count!=0) tx_count<=tx_count-1'b1;
        else tx_busy<=0;
    end
    workstation_v2_emergency guard(.clk(clk),.rst_n(rst_n),.frame_valid(frame_valid),.frame_type(frame_type),.frame_seq(seq),.frame_length(len),.payload(payload),
        .normal_frame_valid(normal_valid),.panic(panic),.abort_upload(abort_upload),
        .normal_response_valid(normal_response_valid),.normal_response_seq(normal_seq),.normal_response_length(normal_length),.normal_response_payload(normal_payload),.normal_response_busy(normal_busy),
        .response_valid(response_valid),.response_seq(response_seq),.response_length(response_length),.response_payload(response_payload),.response_busy(tx_busy));
    wire validation_start,validation_release;reg validation_busy=0;
    always @(posedge clk) begin
        if(!rst_n || validation_release) validation_busy<=0;
        else if(validation_start) validation_busy<=1;
    end
    wire [31:0] ready_mask;wire [7:0] patch_mask;wire tw;
    workstation_v2_resources #(.ENABLE_EMERGENCY(1)) resources(.clk(clk),.rst_n(rst_n),.frame_valid(normal_valid),.frame_type(frame_type),.frame_seq(seq),.frame_length(len),.payload(payload),
        .response_valid(normal_response_valid),.response_seq(normal_seq),.response_length(normal_length),.response_payload(normal_payload),.response_busy(normal_busy),
        .control_done(1'b0),.control_result(8'd0),.status_data(224'd0),.runtime_data(176'd0),.command_feedback(112'd0),
        .validation_start(validation_start),.validation_release(validation_release),.validation_done(1'b0),.validation_busy(validation_busy),.validation_error(1'b0),.validation_duration(32'd0),
        .selected_song(2'd0),.song_read_address(16'd0),.song_ready_mask(ready_mask),.patch_ready_mask(patch_mask),.table_write(tw),
        .external_adsr_valid(1'b0),.external_adsr_value(32'd0),.external_adsr_aux(32'd0),.envelope_read_bank(4'd0),
        .section_read_address(7'd0),.catalog_index(4'd0),.emergency_abort(abort_upload));
    integer ack_count=0,panic_count=0,abort_count=0,writes=0;reg [15:0] ack_seq[0:31];reg [767:0] ack_data[0:31];
    always @(posedge clk) if(rst_n) begin
        if(response_valid) begin ack_seq[ack_count]=response_seq;ack_data[ack_count]=response_payload;ack_count=ack_count+1;end
        if(panic) panic_count=panic_count+1;
        if(abort_upload) abort_count=abort_count+1;
        if(tw) writes=writes+1;
    end
    task raw(input [7:0] kind,input [15:0] number,input integer length,input [1055:0] data);
        begin @(negedge clk);frame_type=kind;seq=number;len=length;payload=data;frame_valid=1;@(negedge clk);frame_valid=0;end
    endtask
    task send(input [7:0] kind,input [15:0] number,input integer length,input [1055:0] data,input [7:0] code);
        integer previous;
        begin
            wait(!normal_busy && resources.state==0);previous=ack_count;raw(kind,number,length,data);
            wait(ack_count>previous);
            if(ack_seq[previous]!=number || ack_data[previous][7:0]!=kind || ack_data[previous][15:8]!=code) $fatal(1,"bad ACK %d",number);
        end
    endtask
    function automatic [31:0] crc32(input [1055:0] bytes,input integer count);
        reg [31:0] c;integer i,j;
        begin c=32'hffffffff;for(i=0;i<count;i=i+1) begin c=c^{24'd0,bytes[i*8+:8]};for(j=0;j<8;j=j+1)c=c[0]?(c>>1)^32'hedb88320:c>>1;end crc32=c^32'hffffffff;end
    endfunction
    reg [1055:0] header,data;reg [31:0] checksum;integer ack_before,old_writes;
    initial begin
        repeat(8) @(negedge clk);rst_n=1;
        send(8'h30,1,0,0,0);if(ack_data[0][143:128]!=7) $fatal(1,"emergency capability missing");
        // 借用普通响应寄存器期间，即使FSM已idle，后续请求也不能覆盖待发送数据。
        wait(!normal_busy && resources.state==0);raw(8'h01,20,4,1056'h12345678);
        wait(normal_response_valid);@(negedge clk);hold_tx=1;repeat(4) @(negedge clk);ack_before=ack_count;
        raw(8'h30,21,0,0);repeat(3) @(negedge clk);
        if(resources.response_payload[47:16]!=32'h12345678 || !guard.normal_pending) $fatal(1,"ordinary response buffer overwritten while locked");
        raw(8'h3b,22,1,1056'd1);repeat(3) @(negedge clk);hold_tx=0;
        wait(ack_count>=ack_before+2);
        if(ack_seq[ack_before]!=22 || ack_seq[ack_before+1]!=20 || ack_data[ack_before+1][47:16]!=32'h12345678)
            $fatal(1,"urgent overtaking corrupted ordinary response");
        send(8'h01,23,4,1056'd1,0);panic_count=0;abort_count=0;
        // 26-byte合法最小MIDI；验证器故意持续busy，不能依靠普通状态机结束来清音。
        data=208'h002fff00000000046b72544de00101000000000000066468544d;
        // 按真实字节定义，避免人读十六进制顺序掩盖header错误。
        data=0;data[31:0]=32'h6468544d;data[7*8+:8]=6;data[11*8+:8]=1;data[12*8+:8]=1;data[13*8+:8]=8'he0;
        data[14*8+:32]=32'h6b72544d;data[21*8+:8]=4;data[23*8+:8]=8'hff;data[24*8+:8]=8'h2f;
        checksum=crc32(data,26);header=0;header[47:16]=26;header[79:48]=checksum;header[239:208]=1;header[527:496]=1920;
        send(8'h32,2,74,header,0);send(8'h33,3,30,data<<32,0);
        wait(!normal_busy && resources.state==0);raw(8'h34,4,4,{1024'd0,checksum});wait(validation_busy);
        hold_tx=1;repeat(3) @(negedge clk);ack_before=ack_count;
        raw(8'h3b,5,1,1056'd3);repeat(4) @(negedge clk);
        if(panic_count!=1 || abort_count!=1 || resources.state!=0 || validation_busy || ready_mask!=0 || resources.song_data_ready[0]) $fatal(1,"abort failed during validation");
        if(ack_count!=ack_before) $fatal(1,"ACK transmitted into busy UART");
        hold_tx=0;wait(ack_count>ack_before);
        if(ack_seq[ack_before]!=5 || ack_data[ack_before][15:0]!=16'h003b) $fatal(1,"urgent ACK incorrect");
        send(8'h01,6,4,1056'h12345678,0);
        // 非法紧急帧不能清音或取消；应有失败ACK。
        ack_before=ack_count;raw(8'h3b,7,1,1056'd4);wait(ack_count>ack_before);
        if(ack_data[ack_before][15:8]!=1 || panic_count!=1 || abort_count!=1) $fatal(1,"invalid emergency changed state");
        // 取消写波表的中间数据；取消后不得继续写、不得发布半成品。
        header=0;header[7:0]=1;header[47:16]=512;header[543:528]=64;header[559:544]=8;header[575:560]=3000;header[591:576]=32;
        send(8'h32,8,74,header,0);wait(!normal_busy && resources.state==0);
        raw(8'h33,9,132,0);wait(writes>=3);raw(8'h3b,10,1,1056'd3);
        repeat(5) @(negedge clk);old_writes=writes;repeat(200) @(negedge clk);
        if(writes!=old_writes || patch_mask!=0 || resources.uploading) $fatal(1,"wave write continued after abort");
        send(8'h01,11,4,1056'd9,0);
        $display("PASS emergency: busy validation, TX backpressure, invalid request, partial wave abort, recovery");$finish;
    end
    initial begin #1000000;$fatal(1,"emergency timeout");end
endmodule
