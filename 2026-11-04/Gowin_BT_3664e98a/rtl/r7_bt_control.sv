`default_nettype none
// 蓝牙会话服务：仅将白名单控制送入整机控制仲裁器，ACK等待实际完成。
// 本模块不访问音频PCM/DDR，不产生音符；USB空闲及取消由顶层仲裁器提供。
module r7_bt_control #(
    parameter [31:0] BUILD_ID=32'd0,
    parameter integer LEASE_CYCLES=250_000_000,
    parameter integer SERVICE_CYCLES=5_000_000
)(
    input wire clk,rst_n,
    input wire frame_valid,input wire [7:0] frame_type,
    input wire [15:0] frame_seq,frame_length,input wire [255:0] payload,
    input wire usb_idle,external_cancel,
    input wire [255:0] status_data,
    output reg lease_active,
    output reg response_valid,output reg [15:0] response_seq,
    output reg [7:0] response_length,output reg [511:0] response_payload,
    input wire response_busy,
    output wire command_valid,output reg [7:0] command_op,
    output reg [31:0] command_value,command_aux,
    input wire command_ready,command_done,input wire [7:0] command_result,
    output wire command_cancel,output reg emergency,
    output reg [31:0] accepted_commands
);
    localparam [7:0] OK=0,INVALID=1,NO_SESSION=2,BUSY=3,STALE=4,CONFLICT=5,
        UNSUPPORTED=6,CANCELLED=7,TIMEOUT=8;
    localparam [1:0] IDLE=0,SEND=1,WAIT_DONE=2;
    reg [1:0] state;
    reg command_pending;
    reg [63:0] uptime,challenge,nonce;
    reg hello_pending;
    reg [31:0] lease_age,service_age;
    reg cache_valid;
    reg [15:0] last_seq,last_length;
    reg [255:0] last_request;
    reg [511:0] last_response;
    reg [7:0] last_response_length;
    reg [15:0] pending_seq,pending_length;
    reg [255:0] pending_request;
    wire [7:0] operation=payload[15:8];
    wire known=(^payload)!==1'bx && (^frame_length)!==1'bx &&
               (^frame_seq)!==1'bx && (^frame_type)!==1'bx;
    wire session_ok=lease_active && payload[79:16]==challenge;
    wire expired=(lease_active||hello_pending) && lease_age>=LEASE_CYCLES-1;
    wire urgent_frame=frame_valid===1'b1 && known && frame_type==8'h42 &&
        payload[7:0]==1 && operation==6 && frame_length==10 && session_ok &&
        frame_seq>last_seq && frame_seq!=16'hffff && !response_valid &&
        (state==IDLE || frame_seq>pending_seq);
    reg cancel_pulse;
    wire service_expired=state!=IDLE && service_age>=SERVICE_CYCLES-1;
    // 同沿撤销必须在下游执行沿之前可见；单纯寄存取消会让排队的PLAY多走一拍。
    assign command_cancel=cancel_pulse || (state!=IDLE &&
        (external_cancel!==1'b0 || expired || urgent_frame || service_expired));
    assign command_valid=command_pending && !command_cancel;

    function automatic control_allowed(input [7:0] op,input [31:0] value,aux);
        begin
            control_allowed=0;
            if(op==52) case(value)
                0,1:control_allowed=aux<=100;
                2,6:control_allowed=aux<=3;
                3:control_allowed=aux<=1;
                4,5:control_allowed=aux<=128;
                default:control_allowed=0;
            endcase
            else if(aux==0) case(op)
                1:control_allowed=value<=4;
                2,3,5,15:control_allowed=value==0;
                12,13:control_allowed=value==10||value==19||value==20;
                19,20:control_allowed=value<=100;
                21:control_allowed=value<=4095;
                22:control_allowed=value<=96;
                41,42,43:control_allowed=value<=255;
                default:control_allowed=0;
            endcase
        end
    endfunction

    function automatic [511:0] reply(input [7:0] code,op,input [63:0] session);
        begin reply=0;reply[127:0]={BUILD_ID,session,op,8'd1,code,8'h42};end
    endfunction

    task respond(input [15:0] sequence_number,input [511:0] data,input [7:0] length);
        begin response_seq<=sequence_number;response_payload<=data;response_length<=length;response_valid<=1;end
    endtask
    task finish_request(input [511:0] data,input [7:0] length);
        begin
            respond(pending_seq,data,length);last_seq<=pending_seq;last_length<=pending_length;
            last_request<=pending_request;last_response<=data;last_response_length<=length;
            cache_valid<=1;state<=IDLE;
        end
    endtask
    task immediate(input [511:0] data,input [7:0] length);
        begin
            respond(frame_seq,data,length);last_seq<=frame_seq;last_length<=frame_length;
            last_request<=payload;last_response<=data;last_response_length<=length;cache_valid<=1;
        end
    endtask

    reg [511:0] result_data;
    always @(posedge clk) begin
        cancel_pulse<=0;emergency<=0;
        if(response_valid && !response_busy) response_valid<=0;
        if(!rst_n) begin
            uptime<=0;challenge<=0;nonce<=0;hello_pending<=0;lease_active<=0;lease_age<=0;
            state<=IDLE;service_age<=0;command_pending<=0;command_op<=0;command_value<=0;command_aux<=0;
            response_valid<=0;response_seq<=0;response_length<=0;response_payload<=0;
            cache_valid<=0;last_seq<=0;last_length<=0;last_request<=0;last_response<=0;last_response_length<=0;
            pending_seq<=0;pending_length<=0;pending_request<=0;accepted_commands<=0;result_data=0;
        end else begin
            uptime<=uptime+1'b1;
            if(lease_active||hello_pending)lease_age<=lease_age+1'b1;
            if(state!=IDLE)service_age<=service_age+1'b1;else service_age<=0;
            // 取消优先于派发和完成。发出的取消只针对本通道，不应被接成全局实体清音。
            if(external_cancel || expired) begin
                lease_active<=0;hello_pending<=0;cache_valid<=0;command_pending<=0;
                cancel_pulse<=state!=IDLE;state<=IDLE;lease_age<=0;
                if(state!=IDLE)respond(pending_seq,reply(CANCELLED,5,challenge),16);
            end else if(state!=IDLE && service_age>=SERVICE_CYCLES-1) begin
                command_pending<=0;cancel_pulse<=1;
                finish_request(reply(TIMEOUT,5,challenge),16);
                // 超时后结果不确定；不接受该会话的下一条控制。
                lease_active<=0;hello_pending<=0;
            end else begin
                if(state==SEND && command_valid && command_ready===1'b1) begin
                    command_pending<=0;state<=WAIT_DONE;accepted_commands<=accepted_commands+1'b1;
                end else if(state==WAIT_DONE && command_done===1'b1) begin
                    if((^command_result)===1'bx) begin
                        finish_request(reply(INVALID,5,challenge),16);
                        lease_active<=0;cancel_pulse<=1;
                    end else begin
                        result_data=reply(OK,5,challenge);result_data[135:128]=command_result;
                        finish_request(result_data,17);
                    end
                end
                // UART响应尚未被锁存时，不允许覆盖；主机在同一个执行器中重试。
                if(frame_valid===1'b1 && !response_valid && known && frame_type==8'h42 && (state==IDLE || urgent_frame)) begin
                    if(payload[7:0]!=1 || frame_length<2 || frame_length>32)
                        respond(frame_seq,reply(INVALID,operation,challenge),16);
                    else if(operation==0 && state==IDLE) begin
                        if(frame_length!=10)respond(frame_seq,reply(INVALID,0,0),16);
                        else if(lease_active)respond(frame_seq,reply(BUSY,0,challenge),16);
                        else begin
                            result_data=reply(OK,0,(hello_pending && nonce==payload[79:16])?challenge:uptime+1'b1);
                            result_data[191:128]=payload[79:16];result_data[223:192]=32'h0000001f;
                            respond(frame_seq,result_data,28);
                            if(!hello_pending || nonce!=payload[79:16])challenge<=uptime+1'b1;
                            nonce<=payload[79:16];hello_pending<=1;lease_age<=0;
                        end
                    end else if(operation==1 && state==IDLE) begin
                        if(frame_length!=18)respond(frame_seq,reply(INVALID,1,challenge),16);
                        else if(lease_active)begin
                            if(cache_valid && frame_seq==last_seq && frame_length==last_length && payload==last_request)
                                respond(frame_seq,last_response,last_response_length);
                            else respond(frame_seq,reply(BUSY,1,challenge),16);
                        end else if(!hello_pending || nonce!=payload[79:16] || challenge!=payload[143:80])
                            respond(frame_seq,reply(NO_SESSION,1,challenge),16);
                        else if(usb_idle!==1'b1)respond(frame_seq,reply(BUSY,1,challenge),16);
                        else if(frame_seq==16'hffff)respond(frame_seq,reply(STALE,1,challenge),16);
                        else begin
                            lease_active<=1;hello_pending<=0;lease_age<=0;
                            immediate(reply(OK,1,challenge),16);
                        end
                    end else if(!session_ok)respond(frame_seq,reply(NO_SESSION,operation,challenge),16);
                    else if(operation==6 && frame_length==10 && frame_seq>last_seq && frame_seq!=16'hffff) begin
                        emergency<=1;cancel_pulse<=state!=IDLE;command_pending<=0;state<=IDLE;
                        immediate(reply(OK,6,challenge),16);lease_age<=0;
                    end else if(state==IDLE) begin
                        if(cache_valid && frame_seq==last_seq) begin
                            if(frame_length==last_length && payload==last_request)respond(frame_seq,last_response,last_response_length);
                            else respond(frame_seq,reply(CONFLICT,operation,challenge),16);
                        end else if(frame_seq<=last_seq || frame_seq==16'hffff)respond(frame_seq,reply(STALE,operation,challenge),16);
                        else if(operation>=2 && operation<=4 && frame_length==10) begin
                            result_data=reply(OK,operation,challenge);
                            if(operation==4)begin
                                result_data[383:128]=status_data;
                                if((^status_data)===1'bx)result_data=reply(INVALID,operation,challenge);
                            end
                            immediate(result_data,operation==4?48:16);lease_age<=0;
                            if(operation==3) begin lease_active<=0;hello_pending<=0;cache_valid<=0;end
                        end else if(operation==5 && frame_length==19) begin
                            if(!control_allowed(payload[87:80],payload[119:88],payload[151:120]))
                                immediate(reply(UNSUPPORTED,5,challenge),16);
                            else begin
                                pending_seq<=frame_seq;pending_length<=frame_length;pending_request<=payload;
                                command_op<=payload[87:80];command_value<=payload[119:88];command_aux<=payload[151:120];
                                command_pending<=1;state<=SEND;service_age<=0;lease_age<=0;
                            end
                        end else immediate(reply(INVALID,operation,challenge),16);
                    end
                end
            end
        end
    end
endmodule
`default_nettype wire
