`default_nettype none
// 50MHz同域：只整理测试命令与状态，不参加实时音频握手。
// 屏幕67=带8位请求号的钢琴启动，6E=同请求保活，6F=同请求停止。
// 普通62/0仍是无条件停止；USB旧61/63入口保持，旧屏幕61入口只供兼容。
module r7_piano32_screen_status(
    input wire clk,rst_n,
    input wire command_valid,
    input wire [1:0] command_source, // 1=USB，2=屏幕；不包含HC05测试入口
    input wire [7:0] command_op,command_value,
    input wire external_stop,
    input wire [31:0] session,build_id,
    input wire [2:0] test_kind,
    input wire [5:0] completed_count,voices,
    input wire failed,
    input wire [7:0] result,
    output reg forward_valid,
    output reg [7:0] forward_op,forward_value,
    output reg [479:0] telemetry
);
    reg [31:0] observed_session;
    reg [2:0] previous_kind;
    reg [1:0] owner,pending_owner;
    reg [7:0] token,pending_token,last_issued_token;
    reg token_valid,pending_tagged,issued_valid;
    reg [3:0] phase; // 0空闲/其他测试，1准备，2递进，3保持，4完成，5停止，6失联，7错误
    reg [5:0] progress;
    reg [7:0] error_code;
    reg await_counter_reset,stop_pending;
    wire known_command=(command_valid===1'b1) &&
        ((^{command_op,command_value,command_source})!==1'bx) &&
        (command_source==1 || command_source==2);
    wire tagged_owner=(owner==2) && token_valid && (command_source==2) &&
        (command_value==token) && (test_kind==2);
    always @* begin
        forward_valid=known_command;forward_op=command_op;forward_value=command_value;
        case(command_op)
            8'h67:begin
                // 同次上电严格递增且不回绕；255耗尽后只能复位重新协商。
                forward_valid=known_command && command_source==2 && command_value!=0 &&
                    (!issued_valid || command_value>last_issued_token);
                forward_op=8'h61;forward_value=8'd2;
            end
            8'h6e,8'h6f:begin
                forward_valid=known_command && tagged_owner;
                forward_op=command_op==8'h6e ? 8'h63:8'h62;forward_value=0;
            end
            // 其他会话的旧心跳不能替当前屏幕请求续命；失联仍按原750ms退出。
            8'h63:if(test_kind==2)
                forward_valid=known_command && command_source==owner && !token_valid;
            default:;
        endcase
    end
    always @(posedge clk) begin
        if(!rst_n)begin
            observed_session<=0;previous_kind<=0;owner<=0;pending_owner<=0;
            token<=0;pending_token<=0;last_issued_token<=0;
            token_valid<=0;pending_tagged<=0;issued_valid<=0;
            phase<=0;progress<=0;error_code<=0;await_counter_reset<=0;stop_pending<=0;
        end else begin
            previous_kind<=test_kind;
            // 这是请求信息，直到真实控制器session变化才作为已接受会话发布。
            if(forward_valid && forward_op==8'h61 && forward_value>=1 && forward_value<=7)begin
                pending_owner<=command_source;
                pending_token<=command_value;
                pending_tagged<=command_op==8'h67;
                if(command_op==8'h67)begin last_issued_token<=command_value;issued_valid<=1;end
            end
            if(test_kind==2 && (external_stop || (forward_valid &&
               ((forward_op==8'h62 && forward_value==0) || (forward_op==8'h60 && forward_value<=3)))))
                stop_pending<=1;
            if((^session)!==1'bx && session!=observed_session)begin
                observed_session<=session;owner<=pending_owner;
                token<=pending_token;token_valid<=pending_tagged;
                progress<=0;error_code<=0;stop_pending<=0;await_counter_reset<=1;
                phase<=test_kind==2 ? 4'd1:4'd0;
            end else if(test_kind==2)begin
                // 新会话首拍计数仍可能是旧32；等真实调度器清零后才读新进度。
                if(await_counter_reset)begin
                    if(completed_count===6'd0)await_counter_reset<=0;
                end else if((^completed_count)!==1'bx && completed_count<=32)begin
                    progress<=completed_count;
                    phase<=completed_count==0 ? 4'd1:completed_count<32 ? 4'd2:4'd3;
                end
            end else if(previous_kind==2)begin
                // result在控制器退出沿更新；这里下一拍锁住终态，普通UI命令不能擦掉它。
                if(result==6)begin phase<=6;error_code<=6;end
                else if(result==7 || failed!==1'b0)begin phase<=7;error_code<=7;end
                else if(stop_pending || external_stop)begin phase<=5;error_code<=0;end
                else if(progress==32)begin phase<=4;error_code<=0;end
                else begin phase<=5;error_code<=0;end
            end
        end
    end
    integer k;
    always @*begin
        telemetry=0;
        telemetry[0*32+:32]=32'h50333201; // P32协议v1，均为31位以内非负屏幕数值
        telemetry[1*32+:32]=32'h0000000f; // 递进/真实完成/帧快照/带请求号控制
        telemetry[2*32+:32]={16'd0,build_id[15:0]};
        telemetry[3*32+:32]={16'd0,build_id[31:16]};
        telemetry[4*32+:32]={16'd0,observed_session[15:0]};
        telemetry[5*32+:32]={16'd0,observed_session[31:16]};
        telemetry[6*32+:32]={30'd0,owner};
        telemetry[7*32+:32]={14'd0,issued_valid,last_issued_token,token_valid,token};
        telemetry[8*32+:32]={28'd0,phase};
        telemetry[9*32+:32]={26'd0,progress};
        telemetry[10*32+:32]=progress==0 ? 32'd0:32'd47+{26'd0,progress};
        telemetry[11*32+:32]={24'd0,error_code};
        telemetry[12*32+:32]={21'd0,test_kind,2'd0,voices};
        telemetry[13*32+:32]=32'd750; // 原心跳期限，单位ms，不是屏幕自行倒数的进度
        // 辅助检出漏字段；发送器帧首一次快照，P15最后提交，不能边收到边显示。
        telemetry[14*32+:32]=32'h13579bdf;
        for(k=0;k<14;k=k+1)telemetry[14*32+:32]=telemetry[14*32+:32]^telemetry[k*32+:32];
        // 未知数据不能被发送为一份有能力标识的有效进度帧。
        if ((^{session,test_kind,completed_count,voices,failed,result})===1'bx)telemetry=0;
    end
endmodule
`default_nettype wire
