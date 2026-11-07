`default_nettype none
// 触键业务。每键独立保活；命令字段只在有效帧上锁存，时间单位为50MHz周期。
module screen_touch_service #(
    parameter integer KEY_COUNT=13,POLYPHONIC=0,PERFORMANCE_CONTROLS=0,WORKSTATION_CONTROLS=0,
    parameter integer WATCHDOG_CYCLES=37_500_000
)(
    input wire clk,rst_n,frame_valid,input wire [7:0] frame_op,frame_value,
    output reg [KEY_COUNT-1:0] held_keys,output reg [1:0] octave_shift,
    output reg test_mode,command_valid,output reg [7:0] command_op,command_value,
    output reg unsupported_frame,
    output reg [4:0] command_cancel_flags
);
    localparam integer WATCHDOG_COUNT_WIDTH=(WATCHDOG_CYCLES<2)?1:$clog2(WATCHDOG_CYCLES);
    reg [WATCHDOG_COUNT_WIDTH-1:0] watchdog_count;
    wire key_on=frame_valid&&frame_value<KEY_COUNT&&frame_op==8'h01;
    wire key_off=frame_valid&&frame_value<KEY_COUNT&&frame_op==8'h00;
    wire all_off=frame_valid&&((frame_op==8'h02&&frame_value==8'hff)||
        (WORKSTATION_CONTROLS&&frame_op==8'h05&&frame_value<=4));
    // 通用服务接口仅交付完整且校验正确的帧；上层服务再校验各字段范围。
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin command_valid<=0;command_op<=0;command_value<=0;command_cancel_flags<=0;end
        else begin
            command_valid<=frame_valid;
            if(frame_valid) begin
                command_op<=frame_op;command_value<=frame_value;
                // 与命令字段同沿锁存五个局部类别，仅交给相邻测试适配器，来源/token仍由它鉴权。
                // bit0=61启动，1=62停止，2=60退出，3=67带号启动，4=6F带号停止。
                if((^{frame_op,frame_value})===1'bx)command_cancel_flags<=0;
                else command_cancel_flags<={frame_op==8'h6f,
                    (frame_op==8'h67&&frame_value!=0),(frame_op==8'h60&&frame_value<=3),
                    (frame_op==8'h62&&frame_value==0),
                    (frame_op==8'h61&&frame_value>=1&&frame_value<=7)};
            end
        end
    end
    // OP=03：0 原八度、1 高八度、2 低八度；OP=04：0 退出、1 四频测试/保活。
    wire octave_command = PERFORMANCE_CONTROLS && frame_valid &&
        frame_op == 8'h03 && frame_value <= 2;
    wire test_command = PERFORMANCE_CONTROLS && frame_valid &&
        frame_op == 8'h04 && frame_value <= 1;
    always @(posedge clk or negedge rst_n)
        if(!rst_n)unsupported_frame<=0;
        else unsupported_frame<=frame_valid&&!(key_on||key_off||all_off||octave_command||test_command||WORKSTATION_CONTROLS);
    reg [WATCHDOG_COUNT_WIDTH-1:0] test_watchdog;
    wire [KEY_COUNT-1:0] key_mask = {{(KEY_COUNT-1){1'b0}}, 1'b1} << frame_value;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            octave_shift <= 0; test_mode <= 0; test_watchdog <= 0;
        end else if (all_off) begin
            octave_shift <= 0; test_mode <= 0; test_watchdog <= 0;
        end else begin
            if (octave_command) octave_shift <= frame_value[1:0];
            if (test_command) begin
                test_mode <= frame_value[0]; test_watchdog <= 0;
            end else if (test_mode) begin
                // 诊断连续发声也必须由页面保活，断线后恢复正常演奏输入。
                if (test_watchdog >= WATCHDOG_CYCLES-1) begin
                    test_mode <= 0; test_watchdog <= 0;
                end else test_watchdog <= test_watchdog+1'b1;
            end else test_watchdog <= 0;
        end
    end

    generate if (POLYPHONIC != 0) begin : polyphonic_hold
        reg [WATCHDOG_COUNT_WIDTH-1:0] key_watchdog [0:KEY_COUNT-1];
        integer k;
        // 每键单独保活：某一个键持续发心跳不能延长其他已丢失松开事件的键。
        // 计数器属于控制寄存器，不是音频 BRAM，因此允许复位。
        always @(posedge clk or negedge rst_n) begin
            if (!rst_n) begin
                held_keys <= {KEY_COUNT{1'b0}};
                for (k = 0; k < KEY_COUNT; k = k + 1) begin
                    key_watchdog[k] <= {WATCHDOG_COUNT_WIDTH{1'b0}};
                end
            end else begin
                for (k = 0; k < KEY_COUNT; k = k + 1) begin
                    if (all_off || (key_off && key_mask[k])) begin
                        held_keys[k] <= 1'b0;
                        key_watchdog[k] <= {WATCHDOG_COUNT_WIDTH{1'b0}};
                    end else if (key_on && key_mask[k]) begin
                        held_keys[k] <= 1'b1;
                        key_watchdog[k] <= {WATCHDOG_COUNT_WIDTH{1'b0}};
                    end else if (held_keys[k]) begin
                        if (key_watchdog[k] >= WATCHDOG_CYCLES - 1) begin
                            held_keys[k] <= 1'b0;
                            key_watchdog[k] <= {WATCHDOG_COUNT_WIDTH{1'b0}};
                        end else begin
                            key_watchdog[k] <= key_watchdog[k] + 1'b1;
                        end
                    end else begin
                        key_watchdog[k] <= {WATCHDOG_COUNT_WIDTH{1'b0}};
                    end
                end
            end
        end
    end endgenerate
    generate if (POLYPHONIC == 0) begin : monophonic_hold
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            held_keys      <= {KEY_COUNT{1'b0}};
            watchdog_count <= {WATCHDOG_COUNT_WIDTH{1'b0}};
        end else if (key_on) begin
            // 合法 ON 可以切换到另一键；只有合法 ON/同键保活延长保持时间。
            held_keys      <= key_mask;
            watchdog_count <= {WATCHDOG_COUNT_WIDTH{1'b0}};
        end else if (all_off || (key_off && ((held_keys & key_mask) != 0))) begin
            // 迟到的旧键 OFF 不影响新键，防止滑动/事件乱序误松开。
            held_keys      <= {KEY_COUNT{1'b0}};
            watchdog_count <= {WATCHDOG_COUNT_WIDTH{1'b0}};
        end else if (held_keys != 0) begin
            // 坏校验、越界键、噪声、非匹配 OFF 均不重置 watchdog。
            if (watchdog_count >= WATCHDOG_CYCLES - 1) begin
                held_keys      <= {KEY_COUNT{1'b0}};
                watchdog_count <= {WATCHDOG_COUNT_WIDTH{1'b0}};
            end else begin
                watchdog_count <= watchdog_count + 1'b1;
            end
        end else begin
            watchdog_count <= {WATCHDOG_COUNT_WIDTH{1'b0}};
        end
    end
    end endgenerate
endmodule
`default_nettype wire
