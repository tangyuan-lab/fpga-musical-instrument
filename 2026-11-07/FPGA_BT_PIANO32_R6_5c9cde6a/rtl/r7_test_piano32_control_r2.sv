`default_nettype none
// 蓝牙后继版的测试入口适配；保留旧会话/画面/750ms心跳，仅钢琴kind=2改递进。
// 中文注释理解：event_ready是请求接收，engine_done/result才是实际提交结果。
// synth_panic必须来自同一真实引擎的清音输入，撤销旧事务后才能进入新会话。
// 本模块将钢琴递进调度接入测试中心，时间参数以 50 MHz 时钟周期为单位。
module r7_test_piano32_control_r2 #(
    parameter integer SEMANTIC_CANCEL=0,
    parameter integer WATCHDOG_CYCLES=37_500_000,
    parameter integer NOTE_GAP_CYCLES=5_000_000,
    parameter integer HOLD_CYCLES=100_000_000
)(
    input wire clk,rst_n,command_valid,external_stop,
    input wire [7:0] command_op,command_value,
    input wire restart_or_stop_in,
    input wire event_ready,synth_panic,engine_done,
    input wire [2:0] engine_result,
    output wire [3:0] view,
    output wire [2:0] test_kind,
    output wire test_active,panic,
    output wire [7:0] result,
    output wire [1:0] graph_kind,
    output wire freeze_graph,right_channel,
    output wire [5:0] solo,
    output wire [3:0] led_self_test,
    output wire event_valid,
    output wire [31:0] event_id,
    output wire [6:0] event_note,
    output wire [4:0] event_timbre,
    output wire [31:0] session,
    output wire [5:0] piano_completed_count,
    output wire piano_failed
);
    wire legacy_valid,progress_valid,progress_finished;
    wire [31:0] legacy_id,progress_id;
    wire [6:0] legacy_note,progress_note;
    wire [4:0] legacy_timbre,progress_timbre;
    wire [7:0] legacy_result;
    // 命令撤销沿就禁止再派发；随后仍沿用原panic链清理真实引擎。
    wire decoded_restart_or_stop=command_valid===1'b1 &&
        ((command_op===8'h61 && command_value>=1 && command_value<=7) ||
         (command_op===8'h62 && command_value===0) ||
         (command_op===8'h60 && command_value<=3));
    // 兼容独立调用方默认使用原译码；整机只用已鉴权、同沿的本地语义输入。
    wire restart_or_stop=SEMANTIC_CANCEL ? restart_or_stop_in:decoded_restart_or_stop;
    wire progress_cancel=synth_panic || panic || external_stop || restart_or_stop;

    field_test_models8_control_piano32_r2 #(.WATCHDOG_CYCLES(WATCHDOG_CYCLES)) legacy(
        .clk(clk),.rst_n(rst_n),.command_valid(command_valid),.command_op(command_op),.command_value(command_value),
        .external_stop(external_stop),.auto_finish_valid(progress_finished && test_kind==2),
        .auto_finish_failed(piano_failed),.event_ready(event_ready && test_kind!=2),
        .view(view),.test_kind(test_kind),.test_active(test_active),.panic(panic),.result(legacy_result),
        .graph_kind(graph_kind),.freeze_graph(freeze_graph),.right_channel(right_channel),.solo(solo),.led_self_test(led_self_test),
        .event_valid(legacy_valid),.event_id(legacy_id),.event_note(legacy_note),.event_timbre(legacy_timbre),.session(session));

    r7_piano32_progressive #(.NOTE_GAP_CYCLES(NOTE_GAP_CYCLES),.HOLD_CYCLES(HOLD_CYCLES)) progressive(
        .clk(clk),.rst_n(rst_n),.enable(test_kind==2),.cancel(progress_cancel),.session(session),
        .request_ready(event_ready),.command_done(engine_done),.command_result(engine_result),
        .request_valid(progress_valid),.request_id(progress_id),.request_note(progress_note),.request_timbre(progress_timbre),
        .accepted_count(piano_completed_count),.finished(progress_finished),.failed(piano_failed));

    assign event_valid=test_kind==2 ? progress_valid:legacy_valid;
    assign event_id=test_kind==2 ? progress_id:legacy_id;
    assign event_note=test_kind==2 ? progress_note:legacy_note;
    assign event_timbre=test_kind==2 ? progress_timbre:legacy_timbre;
    // 新错误码7只表示递进请求被引擎拒绝或返回X；成功/旧超时码6语义保持。
    assign result=legacy_result;
endmodule
`default_nettype wire
