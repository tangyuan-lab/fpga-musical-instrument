`default_nettype none
// 模式与实体键映射服务。屏幕演奏事件由独立入口处理，不读取此映射表。
// 映射描述符：[15:14] 类型(0旋律/1打击)，[13:8] 音色，[7:0] 音高/鼓编号。
// 预留8套模式、64个音色编号；当前支持旋律0/1、音高0..15，以及鼓0..15。
// 配置保存在运行寄存器中；复位/掉电恢复默认，不写板卡 Flash。
module instrument_mode_control #(
    parameter integer MODE_SLOTS=8,
    parameter [7:0] ENABLED_MODES=8'h1f
) (
    input wire clk, rst_n, cmd_valid, mode_pressed,
    input wire [7:0] cmd_op, cmd_value,
    output reg [2:0] mode,
    output reg mode_changed, map_changed, command_error,
    output wire [255:0] active_map,
    output reg [2:0] edit_bank,
    output reg [3:0] edit_key,
    output wire [15:0] edit_descriptor,
    output reg [6:0] piano_volume, drum_volume, midi_volume,
    output reg midi_start, midi_stop,
    output reg boot_pending
);
    reg [15:0] maps [0:MODE_SLOTS*16-1];
    reg [1:0] staged_kind;
    reg [5:0] staged_timbre;
    reg [7:0] staged_note;
    integer bank,k;
    genvar g;
    generate for(g=0;g<16;g=g+1) begin:g_map
        assign active_map[g*16+:16]=maps[mode*16+g];
    end endgenerate
    assign edit_descriptor=maps[edit_bank*16+edit_key];
    function automatic [15:0] default_map(input integer b,input integer key);
        default_map=(b==1) ? (16'h4000|16'(key)) : 16'(key);
    endfunction
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            mode<=0; mode_changed<=0; map_changed<=0; command_error<=0;
            edit_bank<=1;edit_key<=0;staged_kind<=0;staged_timbre<=0;staged_note<=0;
            piano_volume<=80;drum_volume<=60;midi_volume<=60;midi_start<=0;midi_stop<=0;boot_pending<=1;
            for(bank=0;bank<MODE_SLOTS;bank=bank+1)
                for(k=0;k<16;k=k+1) maps[bank*16+k]<=default_map(bank,k);
        end else begin
            mode_changed<=0; map_changed<=0; command_error<=0;midi_start<=0;midi_stop<=0;
            if(mode_pressed) begin
                mode<=(mode>=3) ? 0 : mode+1'b1; mode_changed<=1; midi_stop<=1;
            end else if(cmd_valid) begin
                case(cmd_op)
                    8'h05: if(cmd_value<MODE_SLOTS && ENABLED_MODES[cmd_value[2:0]]) begin
                        if(mode!=cmd_value[2:0]) begin mode<=cmd_value[2:0];mode_changed<=1;midi_stop<=1;end
                    end else command_error<=1;
                    8'h09: if(cmd_value<=100) piano_volume<=cmd_value[6:0]; else command_error<=1;
                    8'h0a: if(cmd_value<=100) drum_volume<=cmd_value[6:0]; else command_error<=1;
                    8'h0b: if(cmd_value<=100) midi_volume<=cmd_value[6:0]; else command_error<=1;
                    8'h10: if(cmd_value==0) midi_stop<=1;
                        else if(cmd_value==1 && mode==3) midi_start<=1;else command_error<=1;
                    // 完整选择上下文后提交一次，半帧或分阶段编辑不改变演奏映射。
                    8'h20: if(cmd_value>=1 && cmd_value<MODE_SLOTS && cmd_value!=4 &&
                               ENABLED_MODES[cmd_value[2:0]]) edit_bank<=cmd_value[2:0];else command_error<=1;
                    8'h21: if(cmd_value<16) edit_key<=cmd_value[3:0];else command_error<=1;
                    8'h22: if(cmd_value<=1) staged_kind<=cmd_value[1:0];else command_error<=1;
                    8'h23: if(cmd_value<64) staged_timbre<=cmd_value[5:0];else command_error<=1;
                    8'h24: staged_note<=cmd_value;
                    8'h25: if(cmd_value==1 && staged_note<16 &&
                                ((staged_kind==0 && staged_timbre<=1) ||
                                 (staged_kind==1 && staged_timbre==0))) begin
                        maps[edit_bank*16+edit_key]<={staged_kind,staged_timbre,staged_note};map_changed<=1;
                    end else command_error<=1;
                    8'h26: if(cmd_value>=1 && cmd_value<MODE_SLOTS && cmd_value!=4 &&
                               ENABLED_MODES[cmd_value[2:0]]) begin
                        for(k=0;k<16;k=k+1) maps[cmd_value*16+k]<=default_map(cmd_value,k);
                        map_changed<=1;
                    end else command_error<=1;
                    8'h27: if(cmd_value==1) boot_pending<=0;else command_error<=1;
                    default: begin end // 其他服务负责按键、鼓点及编排命令。
                endcase
            end
        end
    end
endmodule
`default_nettype wire
