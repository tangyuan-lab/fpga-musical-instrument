`default_nettype none
// 钢琴 32 音递进调度器，负责起音事务调度、完成计数、保持和结束通知。
// 这里只排列起音事务，不处理音频、不改变钢琴自然衰减或任何音频watchdog。
// 默认50MHz：相邻起音至少间隔100ms；32次成功完成后保持2秒，finished通知上层清音。
// 上层必须保留现有测试会话心跳，并把退出、急停、超时产生的合成器panic接到cancel。
module r7_piano32_progressive #(
    parameter integer NOTE_GAP_CYCLES = 5_000_000,
    parameter integer HOLD_CYCLES = 100_000_000
)(
    input wire clk,
    input wire rst_n,
    input wire enable,
    input wire cancel,
    input wire [31:0] session,
    input wire request_ready,
    input wire command_done,
    input wire [2:0] command_result,
    output wire request_valid,
    output wire [31:0] request_id,
    output wire [6:0] request_note,
    output wire [4:0] request_timbre,
    output reg [5:0] accepted_count,
    output reg finished,
    output reg failed
);
    localparam [2:0] IDLE=0, OFFER=1, WAIT_DONE=2, GAP=3, HOLD=4, FINISHED=5;
    reg [2:0] state;
    reg session_active;
    reg [31:0] active_session;
    reg [31:0] gap_left;
    reg [31:0] hold_left;

    // source=3沿用原测试音符身份域。有效请求等待ready时，音高和身份保持不变。
    assign request_valid = (state==OFFER) && session_active &&
        (enable===1'b1) && (cancel===1'b0) && (session===active_session);
    assign request_id = {active_session[23:0],2'b11,accepted_count};
    assign request_note = 7'd48 + {1'b0,accepted_count};
    assign request_timbre = 5'd10;

    always @(posedge clk) begin
        finished <= 1'b0;
        if (!rst_n) begin
            state <= IDLE;
            session_active <= 1'b0;
            active_session <= 0;
            gap_left <= 0;
            hold_left <= 0;
            accepted_count <= 0;
            finished <= 1'b0;
            failed <= 1'b0;
        end else if (cancel===1'b1 || enable===1'b0) begin
            state <= IDLE;
            session_active <= 1'b0;
            gap_left <= 0;
            hold_left <= 0;
            // 留住完成计数和失败标志供上层观察，下一次显式新会话才清零。
        end else if (enable===1'b1 && cancel===1'b0 &&
                     (!session_active || session!=active_session)) begin
            if ((^session)===1'bx) begin
                state <= FINISHED;
                session_active <= 1'b0;
                failed <= 1'b1;
                finished <= 1'b1;
            end else begin
                active_session <= session;
                session_active <= 1'b1;
                accepted_count <= 0;
                gap_left <= 0;
                hold_left <= 0;
                failed <= 1'b0;
                state <= OFFER;
            end
        end else if (enable===1'b1 && cancel===1'b0 && session===active_session) begin
            if (gap_left!=0) gap_left <= gap_left-1'b1;
            case (state)
                OFFER: if (request_valid && request_ready===1'b1) begin
                    gap_left <= NOTE_GAP_CYCLES-1;
                    state <= WAIT_DONE;
                end
                WAIT_DONE: if (command_done===1'b1) begin
                    // ready只是请求被接收；只有真实引擎返回成功才增加已接受音符数。
                    if (command_result===3'd0) begin
                        accepted_count <= accepted_count+1'b1;
                        if (accepted_count==31) begin
                            hold_left <= HOLD_CYCLES-1;
                            state <= HOLD;
                        end else state <= GAP;
                    end else begin
                        // 错误或X返回均停止演示，由上层立即清音，不伪装32音完成。
                        failed <= 1'b1;
                        finished <= 1'b1;
                        state <= FINISHED;
                    end
                end
                GAP: if (gap_left==0) state <= OFFER;
                HOLD: begin
                    if (hold_left==0) begin
                        finished <= 1'b1;
                        state <= FINISHED;
                    end else hold_left <= hold_left-1'b1;
                end
                default: ;
            endcase
        end
    end

`ifndef SYNTHESIS
    initial begin
        if (NOTE_GAP_CYCLES<1 || HOLD_CYCLES<1)
            $fatal(1,"PIANO32_INVALID_TIME_PARAMETER");
    end
    always @(posedge clk) if (rst_n && request_valid && request_ready===1'b1) begin
        if ((^{request_id,request_note,request_timbre})===1'bx)
            $fatal(1,"PIANO32_ACCEPTED_DATA_X");
        if (accepted_count>=32 || request_note<48 || request_note>79 || request_timbre!=10)
            $fatal(1,"PIANO32_ACCEPTED_EVENT_RANGE");
    end
`endif
endmodule
`default_nettype wire
