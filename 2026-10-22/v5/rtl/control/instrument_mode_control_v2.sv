`default_nettype none
// 模式与实体键映射服务。屏幕演奏事件由独立入口处理，不读取此映射表。
// 映射描述符：[15:14] 类型(0旋律/1打击)，[13:8] 音色，[7:0] 音高/鼓编号。
// 预留8套模式、64个音色编号；V2支持旋律0..9及63（跟随当前音色）、音高0..15，以及鼓0..15。
// 配置保存在运行寄存器中；复位/掉电恢复默认，不写板卡 Flash。
module instrument_mode_control_v2 #(
    parameter integer MODE_SLOTS=8,
    parameter [7:0] ENABLED_MODES=8'h1f
) (
    input wire clk, rst_n, cmd_valid, mode_pressed,
    input wire [7:0] cmd_op, cmd_value,
    input wire direct_valid,input wire [15:0] direct_descriptor,
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
    reg [MODE_SLOTS-1:0] write_pending,restore_pending;
    reg [3:0] write_key [0:MODE_SLOTS-1];
    reg [15:0] write_descriptor [0:MODE_SLOTS-1];
    integer bank;
    genvar g;
    generate for(g=0;g<16;g=g+1) begin:g_map
        assign active_map[g*16+:16]=maps[(mode<MODE_SLOTS ? mode:0)*16+g];
    end endgenerate
    assign edit_descriptor=maps[edit_bank*16+edit_key];
    function automatic [15:0] default_map(input integer b,input integer key);
        default_map=(b==1) ? (16'h4000|16'(key)) : (16'h3f00|16'(key));
    endfunction
    // 合法事务及编辑上下文先寄存；每组使用常量索引写入，切断跨区批量写译码。
    genvar local_bank,local_key;
    generate for(local_bank=0;local_bank<MODE_SLOTS;local_bank=local_bank+1) begin:g_write_bank
        for(local_key=0;local_key<16;local_key=local_key+1) begin:g_write_key
            always @(posedge clk or negedge rst_n) begin
                if(!rst_n) maps[local_bank*16+local_key]<=default_map(local_bank,local_key);
                else if(restore_pending[local_bank]) maps[local_bank*16+local_key]<=default_map(local_bank,local_key);
                else if(write_pending[local_bank] && write_key[local_bank]==local_key)
                    maps[local_bank*16+local_key]<=write_descriptor[local_bank];
            end
        end
    end endgenerate
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            mode<=0; mode_changed<=0; map_changed<=0; command_error<=0;
            edit_bank<=1;edit_key<=0;staged_kind<=0;staged_timbre<=0;staged_note<=0;
            piano_volume<=80;drum_volume<=60;midi_volume<=60;midi_start<=0;midi_stop<=0;boot_pending<=1;
            write_pending<=0;restore_pending<=0;
            for(bank=0;bank<MODE_SLOTS;bank=bank+1) begin write_key[bank]<=0;write_descriptor[bank]<=0;end
        end else begin
            // 通知与实际提交同拍；仲裁器state4/5的等待覆盖新增的一拍（20ns）。
            mode_changed<=0; map_changed<=|write_pending || |restore_pending; command_error<=0;midi_start<=0;midi_stop<=0;
            write_pending<=0;restore_pending<=0;
            if(mode_pressed) begin
                mode<=(mode>=3) ? 0 : mode+1'b1; mode_changed<=1; midi_stop<=1;
            end else if(direct_valid) begin
                // 上位机完整描述符原子提交，沿用当前已选择的配置组和实体键。
                if(direct_descriptor[7:0]<16 &&
                    ((direct_descriptor[15:14]==0 && (direct_descriptor[13:8]<10 || direct_descriptor[13:8]==63)) ||
                     (direct_descriptor[15:14]==1 && direct_descriptor[13:8]==0))) begin
                    for(bank=0;bank<MODE_SLOTS;bank=bank+1) if(edit_bank==bank) begin
                        write_pending[bank]<=1;write_key[bank]<=edit_key;write_descriptor[bank]<=direct_descriptor;
                    end
                end else command_error<=1;
            end else if(cmd_valid) begin
                case(cmd_op)
                    8'h05: if((cmd_value<MODE_SLOTS || cmd_value==4) && ENABLED_MODES[cmd_value[2:0]]) begin
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
                                ((staged_kind==0 && (staged_timbre<10 || staged_timbre==63)) ||
                                 (staged_kind==1 && staged_timbre==0))) begin
                        for(bank=0;bank<MODE_SLOTS;bank=bank+1) if(edit_bank==bank) begin
                            write_pending[bank]<=1;write_key[bank]<=edit_key;write_descriptor[bank]<={staged_kind,staged_timbre,staged_note};
                        end
                    end else command_error<=1;
                    8'h26: if(cmd_value>=1 && cmd_value<MODE_SLOTS && cmd_value!=4 &&
                               ENABLED_MODES[cmd_value[2:0]]) begin
                        for(bank=0;bank<MODE_SLOTS;bank=bank+1) if(cmd_value==bank) restore_pending[bank]<=1;
                    end else command_error<=1;
                    8'h27: if(cmd_value==1) boot_pending<=0;else command_error<=1;
                    default: begin end // 其他服务负责按键、鼓点及编排命令。
                endcase
            end
        end
    end
endmodule
`default_nettype wire
