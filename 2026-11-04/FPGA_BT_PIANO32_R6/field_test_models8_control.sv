`default_nettype none
// 测试有显式会话和心跳。观察页只改变画面；离开测试去首页/演奏、急停、失联均清音。
// 钢琴32/吉他32/混合32/Bass32命令均进入真实合成器，source=3使用完整32槽，DDS测试与钢琴验收严格区分。
module field_test_models8_control #(parameter integer WATCHDOG_CYCLES=37_500_000)(
    input wire clk,rst_n,command_valid,external_stop,
    input wire [7:0] command_op,command_value,
    input wire event_ready,
    output reg [3:0] view,
    output reg [2:0] test_kind,
    output wire test_active,
    output reg panic,
    output reg [7:0] result,
    output reg [1:0] graph_kind,
    output reg freeze_graph,right_channel,
    output reg [5:0] solo,
    output reg [3:0] led_self_test,
    output wire event_valid,
    output wire [31:0] event_id,
    output wire [6:0] event_note,
    output wire [4:0] event_timbre,
    output reg [31:0] session
);
    reg [31:0] watchdog;reg [5:0] next_note;reg [2:0] settle;
    assign test_active=test_kind!=0;
    assign event_valid=(test_kind==2||test_kind==3||test_kind==4||test_kind==7) && settle==0 && next_note<32 && !panic;
    assign event_id={session[23:0],2'b11,next_note};
        // 兼容旧屏/实体映射鼓号0..7：KICK/MID/HIGH/LOW/SNARE/SIDE/CLAP/RIM。
    // 此顺序不是原模型drum_index；以下转换到内置模型10..18注册表，绝不按低4位回绕。
    function automatic [4:0] builtin_drum(input [2:0] index);
        case(index)
            0:builtin_drum=14;1:builtin_drum=11;2:builtin_drum=12;3:builtin_drum=13;
            4:builtin_drum=15;5:builtin_drum=16;6:builtin_drum=17;7:builtin_drum=18;
        endcase
    endfunction
    function automatic [4:0] resolve_timbre(input [5:0] raw,input [4:0] follow);
        // 63是映射层哨兵，必须先在6位域判定；它从不进入5位引擎端口。
        if(raw==6'd63)resolve_timbre=follow;
        else if(raw>=10&&raw<=20)resolve_timbre=raw[4:0];
        else resolve_timbre=5'd31; // 无效编号显式拒绝，不能别名为钢琴或另一种鼓。
    endfunction
    wire [4:0] mixed_timbre=next_note%3==0 ? 5'd10:next_note%3==1 ? 5'd19:5'd20;
    assign event_timbre=test_kind==2 ? 5'd10:test_kind==4 ? mixed_timbre:test_kind==7 ? 5'd20:5'd19;
    assign event_note=event_timbre==10 ? 7'd48+{1'b0,next_note}:
        event_timbre==19 ? 7'd60+{3'd0,next_note[3:0]}:
        event_timbre==20 ? 7'd28+{3'd0,next_note[3:0]}:7'd60;
    always @(posedge clk)begin
        panic<=0;
        if(!rst_n)begin
            view<=0;test_kind<=0;panic<=1;result<=0;graph_kind<=0;freeze_graph<=0;
            right_channel<=0;solo<=0;led_self_test<=0;watchdog<=0;next_note<=32;settle<=0;session<=0;
        end else if(external_stop || (test_active && watchdog>=WATCHDOG_CYCLES-1))begin
            test_kind<=0;panic<=1;watchdog<=0;next_note<=32;solo<=0;
            if(!external_stop)result<=8'd6; // 失联，不能把超时退出显示成成功。
        end else begin
            if(test_active)watchdog<=watchdog+1'b1;else watchdog<=0;
            if(settle!=0)settle<=settle-1'b1;
            if(event_valid && event_ready)next_note<=next_note+1'b1;
            if(command_valid)case(command_op)
                8'h60:if(command_value<=15)begin
                    view<=command_value[3:0];result<=0;
                    if(command_value<=3)begin test_kind<=0;panic<=1;solo<=0;end
                end else result<=1;
                8'h61:if(command_value>=1&&command_value<=7)begin
                    test_kind<=command_value[2:0];watchdog<=0;panic<=1;session<=session+1'b1;
                    next_note<=0;settle<=4;solo<=0;result<=0;view<=8;
                    graph_kind<=1;freeze_graph<=0;
                end else result<=4;
                8'h62:if(command_value==0)begin test_kind<=0;panic<=1;result<=0;solo<=0;end else result<=1;
                8'h63:if(command_value==0)begin watchdog<=0;end else result<=1;
                8'h64:if(command_value<3)begin graph_kind<=command_value[1:0];result<=0;end else result<=1;
                8'h65:if(command_value<2)begin freeze_graph<=command_value[0];result<=0;end else result<=1;
                8'h66:if(command_value<2)begin right_channel<=command_value[0];result<=0;end else result<=1;
                8'h68:if(test_kind>=2&&test_kind<=4)result<=4;
                    else if(command_value<=32)begin solo<=command_value[5:0];result<=0;end else result<=1;
                8'h69:if(command_value<=8)begin led_self_test<=command_value[3:0];result<=0;end else result<=1;
                default:;
            endcase
        end
    end
endmodule
`default_nettype wire
