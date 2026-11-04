`default_nettype none
`include "rtl/damping_defaults.vh"
`include "rtl/piano_velocity_defaults.vh"
// 音频参数影子寄存器：控制域写 live_*，sample_tick 时整体搬到音频域。
// 音频层只读本模块输出，不再直接引用控制层或播放器的信号。
module audio_params(
    input wire clk,rst_n,sample_tick,
    input wire cmd_valid,
    input wire [7:0] cmd_op,cmd_value,
    input wire app_valid,input wire [7:0] app_op,input wire [31:0] app_value,app_aux,
    output reg [95:0] damping_settings,
    output reg [1:0] velocity_tone_setting,
    input wire [7:0] piano_volume_in,drum_volume_in,
    output reg signed [13:0] bend,
    output reg signed [6:0] transpose,
    output reg [7:0] vibrato_depth,vibrato_rate,
    output reg [7:0] chorus_mix,chorus_depth,chorus_rate,
    output reg [7:0] delay_mix,reverb_mix,feedback,
    output reg [14:0] delay_samples,
    output wire [2:0] fx_preview,
    output reg [11:0] env_a,env_d,env_s,env_r,
    output reg env_write,
    output reg command_error,
    output reg [7:0] piano_volume,drum_volume
);
    reg [95:0] l_damping;
    reg [1:0] l_velocity_tone;
    reg signed [13:0] l_bend;
    reg signed [6:0] l_transpose;
    reg [7:0] l_vib_dep,l_vib_rate,l_chorus_mix,l_chorus_dep,l_chorus_rate;
    reg [7:0] l_delay_mix,l_reverb_mix,l_feedback;
    reg [14:0] l_delay_samples;
    reg [11:0] l_env_a,l_env_d,l_env_s,l_env_r;
    reg [2:0] preview;
    assign fx_preview=preview;
    // 试听只覆盖音频侧目标，不改用户影子参数；0恢复设置，1干声，2延迟，3混响，4合唱。
    wire [7:0] target_delay=preview==0 ? l_delay_mix:preview==2 ? 8'd80:8'd0;
    wire [7:0] target_reverb=preview==0 ? l_reverb_mix:preview==3 ? 8'd96:8'd0;
    wire [7:0] target_chorus=preview==0 ? l_chorus_mix:preview==4 ? 8'd192:8'd0;
    wire [7:0] target_depth=preview==4 ? 8'd128:l_chorus_dep;
    wire [7:0] target_rate=preview==4 ? 8'd64:l_chorus_rate;
    wire [7:0] target_feedback=preview==2 ? 8'd64:l_feedback;
    reg vib_on,env_dirty;reg boot_done;
    reg [7:0] boot_cnt;
    // 控制域：命令写入 live 值
    always @(posedge clk)begin
        if(!rst_n)begin
            l_damping<=`DAMPING_DEFAULTS;
            l_velocity_tone<=`PIANO_VELOCITY_TONE_DEFAULT;
            l_bend<=0;l_transpose<=0;l_vib_dep<=8'd60;l_vib_rate<=8'd40;vib_on<=0;
            l_chorus_mix<=8'd0;l_chorus_dep<=8'd40;l_chorus_rate<=8'd6;
            l_delay_mix<=8'd0;l_reverb_mix<=8'd0;l_feedback<=8'd0;l_delay_samples<=15'd12000;preview<=0;
            l_env_a<=12'd64;l_env_d<=12'd8;l_env_s<=12'd3072;l_env_r<=12'd32;
            env_dirty<=1'b0;boot_cnt<=0;command_error<=0;
        end else begin
            // 同拍命令在后方置位，留到下一采样边界提交，不丢更新。
            command_error<=0;
            if(sample_tick) env_dirty<=1'b0;
            if(cmd_valid)case(cmd_op)
                8'h40: if(cmd_value<=100)l_bend<=($signed({1'b0,cmd_value[6:0]})-8'sd50)*8'sd80;else command_error<=1;
                8'h41: if(cmd_value<=1)vib_on<=cmd_value[0];else command_error<=1;
                8'h42: l_vib_dep<=cmd_value[7:0];
                8'h43: l_vib_rate<=cmd_value[7:0];
                8'h44: if(cmd_value<=24)l_transpose<=$signed({1'b0,cmd_value[5:0]})-7'sd12;else command_error<=1;
                8'h46: begin l_env_a<=cmd_value[7:0];env_dirty<=1'b1;end
                8'h47: begin l_env_d<=cmd_value[7:0];env_dirty<=1'b1;end
                8'h48: begin l_env_s<=cmd_value[7:0];env_dirty<=1'b1;end
                8'h49: begin l_env_r<=cmd_value[7:0];env_dirty<=1'b1;end
                8'h50: l_chorus_mix<=cmd_value[7:0];
                8'h51: if(cmd_value<=127)l_delay_mix<=cmd_value;else command_error<=1;
                8'h52: if(cmd_value<=127)l_reverb_mix<=cmd_value;else command_error<=1;
                8'h53: if(cmd_value<=96)l_feedback<=cmd_value;else command_error<=1;
                8'h54: if(cmd_value<=127)l_delay_samples<={cmd_value[6:0],5'd0};else command_error<=1;
                8'h55: l_chorus_dep<=cmd_value[7:0];
                8'h56: l_chorus_rate<=cmd_value[7:0];
                default:;
            endcase
            // USB执行成功后进入同一影子寄存器，下一采样边界生效；不直接改音频中间帧。
            if(app_valid)case(app_op)
                11:l_transpose<=7'(app_value);
                16:l_bend<=14'(app_value);
                17:begin l_vib_dep<=app_value>255 ? 255:app_value[7:0];vib_on<=app_value!=0;end
                18:l_vib_rate<=app_value>20 ? 20:app_value[7:0];
                19:l_delay_mix<=app_value>100 ? 100:app_value[7:0];
                20:l_reverb_mix<=app_value>100 ? 100:app_value[7:0];
                21:l_delay_samples<=app_value>4095 ? 4095:app_value[11:0];
                22:l_feedback<=app_value>96 ? 96:app_value[7:0];
                41:l_chorus_mix<=app_value>255 ? 255:app_value[7:0];
                42:l_chorus_dep<=app_value>255 ? 255:app_value[7:0];
                43:l_chorus_rate<=app_value>255 ? 255:app_value[7:0];
                46:if(app_value<=4)preview<=app_value[2:0];
                47:if(app_value>=50&&app_value<=600)l_delay_samples<=15'(app_value*48);
                44:case(app_aux)
                    10:l_damping[31:0]<=app_value;
                    19:l_damping[63:32]<=app_value;
                    20:l_damping[95:64]<=app_value;
                    default:;
                endcase
                45:if(app_aux==10)l_velocity_tone<=app_value[1:0];
                default:;
            endcase
        end
    end
    // 音频域：只在 sample_tick 整体切换
    always @(posedge clk)begin
        if(!rst_n)begin
            damping_settings<=`DAMPING_DEFAULTS;
            velocity_tone_setting<=`PIANO_VELOCITY_TONE_DEFAULT;
            bend<=0;transpose<=0;vibrato_depth<=0;vibrato_rate<=0;
            chorus_mix<=0;chorus_depth<=0;chorus_rate<=0;
            delay_mix<=0;reverb_mix<=0;feedback<=0;delay_samples<=0;
            env_a<=12'd64;env_d<=12'd8;env_s<=12'd3072;env_r<=12'd32;
            env_write<=0;piano_volume<=0;drum_volume<=0;boot_done<=1'b1;
        end else begin
            env_write<=0;
            if(sample_tick)begin
                damping_settings<=l_damping;
                velocity_tone_setting<=l_velocity_tone;
                bend<=l_bend;transpose<=l_transpose;
                vibrato_depth<=vib_on ? l_vib_dep:8'd0;vibrato_rate<=l_vib_rate;
                // 每个采样改变一级：增益、调制及反馈均平滑，不改变音源力度或采样节奏。
                chorus_mix<=chorus_mix<target_chorus ? chorus_mix+1'b1:chorus_mix>target_chorus ? chorus_mix-1'b1:chorus_mix;
                delay_mix<=delay_mix<target_delay ? delay_mix+1'b1:delay_mix>target_delay ? delay_mix-1'b1:delay_mix;
                reverb_mix<=reverb_mix<target_reverb ? reverb_mix+1'b1:reverb_mix>target_reverb ? reverb_mix-1'b1:reverb_mix;
                chorus_depth<=chorus_depth<target_depth ? chorus_depth+1'b1:chorus_depth>target_depth ? chorus_depth-1'b1:chorus_depth;
                chorus_rate<=chorus_rate<target_rate ? chorus_rate+1'b1:chorus_rate>target_rate ? chorus_rate-1'b1:chorus_rate;
                feedback<=feedback<target_feedback ? feedback+1'b1:feedback>target_feedback ? feedback-1'b1:feedback;
                delay_samples<=preview==2 ? 15'd12000:l_delay_samples;
                env_a<=l_env_a;env_d<=l_env_d;env_s<=l_env_s;env_r<=l_env_r;
                piano_volume<=piano_volume_in;drum_volume<=drum_volume_in;
                if(env_dirty || !boot_done) begin env_write<=1'b1;boot_done<=1'b1;end
            end
        end
    end
endmodule
`default_nettype wire
