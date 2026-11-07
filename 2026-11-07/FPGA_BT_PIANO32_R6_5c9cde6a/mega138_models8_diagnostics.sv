`default_nettype none
// 阶段诊断接口，沿用55 AA/版本/类型/序号/长度/CRC16帧。
// E0读取快照，E1设置有效键掩码，E2开关固定C4，E3转发一条屏幕控制命令。
// 不冒充完整WSV2资源服务：其他操作返回4(不支持)，错误长度/取值返回1。
module mega138_models8_diagnostics #(
    parameter [31:0] BUILD_ID=32'h26102501,
    parameter [1:0] ADC_PRESENT_MASK=2'b01,
    parameter [15:0] KEY_ENABLE_MASK=16'h000f,
    parameter [1:0] HEADPHONE_BOOST=2'd2
)(
    input wire clk,rst_n,frame_valid,response_busy,clear_tone,
    input wire [7:0] frame_type,input wire [15:0] frame_seq,frame_length,
    input wire [1055:0] payload,
    input wire [2:0] mode,input wire [5:0] voices,
    input wire calibrated,adc_ready,deadline_error,clipped,param_error,
    input wire [15:0] keys,input wire [191:0] adc,baseline,pressure,
    output reg response_valid,output reg [15:0] response_seq,
    output reg [7:0] response_length,output reg [767:0] response_payload,
    output reg [15:0] key_enable,output reg mask_changed,tone_active,tone_changed,
    output reg [1:0] master_boost,
    input wire [6:0] live_volume,song_volume,
    output reg [7:0] live_fx_target,song_fx_target,
    input wire [7:0] live_fx_gain,song_fx_gain,
    output reg limiter_enabled,output reg [1:0] limiter_release,
    input wire [15:0] limiter_gain,input wire [223:0] gain_stats,
    input wire bus_valid,input wire [2:0] bus_setting,input wire [7:0] bus_value,
    output reg gain_stats_clear,
    input wire [431:0] runtime,
    input wire graph_ready,lock_granted,input wire [31:0] graph_revision,
    input wire [15:0] graph_data,
    output reg graph_lock,output reg [5:0] graph_address,
    output reg control_valid,output reg [7:0] control_op,control_value
);
    localparam [15:0] PRESENT_KEYS={{8{ADC_PRESENT_MASK[1]}},{8{ADC_PRESENT_MASK[0]}}};
    reg clip_seen,parameter_error_seen;reg [2:0] graph_state;reg [5:0] graph_count,graph_total,graph_start;reg [31:0] wanted_revision;
    always @(posedge clk)begin
        response_valid<=0;mask_changed<=0;tone_changed<=0;control_valid<=0;gain_stats_clear<=0;
        if(!rst_n)begin
            response_seq<=0;response_length<=0;response_payload<=0;graph_state<=0;graph_lock<=0;graph_address<=0;graph_count<=0;graph_total<=0;graph_start<=0;wanted_revision<=0;
            key_enable<=KEY_ENABLE_MASK&PRESENT_KEYS;tone_active<=0;master_boost<=HEADPHONE_BOOST;
            clip_seen<=0;parameter_error_seen<=0;control_op<=0;control_value<=0;
            live_fx_target<=128;song_fx_target<=128;limiter_enabled<=0;limiter_release<=1;gain_stats_clear<=0;
        end else begin
            if(clipped)clip_seen<=1;
            if(param_error)parameter_error_seen<=1;
            if(clear_tone)begin tone_active<=0;clip_seen<=0;parameter_error_seen<=0;end
            // 已经唯一控制队列验证的混音事务；参数仍只有本always持有，不新增写入者。
            if(bus_valid)case(bus_setting)
                2:master_boost<=bus_value[1:0];
                3:limiter_enabled<=bus_value[0];
                4:live_fx_target<=bus_value;
                5:song_fx_target<=bus_value;
                6:limiter_release<=bus_value[1:0];
                default:;
            endcase
            if(frame_valid && !response_busy && !response_valid && graph_state==0)begin
                response_valid<=1;response_seq<=frame_seq;response_length<=2;
                response_payload<=0;response_payload[7:0]<=frame_type;response_payload[15:8]<=4;
                case(frame_type)
                    8'h01:begin response_payload[15:8]<=0;response_length<=6;response_payload[47:16]<=BUILD_ID;end
                    8'he0:if(frame_length==0)begin
                        response_length<=90;response_payload[15:8]<=0;
                        response_payload[47:16]<=32'h3130464e; // ASCII NF01
                        response_payload[79:48]<=BUILD_ID;response_payload[95:80]<=key_enable;
                        response_payload[103:96]<={5'd0,mode};response_payload[111:104]<={2'd0,voices};
                        response_payload[119:112]<={master_boost,parameter_error_seen,clip_seen,deadline_error,tone_active,calibrated,adc_ready};
                        response_payload[127:120]<={6'd0,ADC_PRESENT_MASK};response_payload[143:128]<=keys;
                        response_payload[335:144]<=adc;response_payload[527:336]<=baseline;response_payload[719:528]<=pressure;
                    end else response_payload[15:8]<=1;
                    8'he1:if(frame_length==2 && (payload[15:0]&~PRESENT_KEYS)==0)begin
                        key_enable<=payload[15:0];mask_changed<=key_enable!=payload[15:0];response_payload[15:8]<=0;
                    end else response_payload[15:8]<=1;
                    8'he2:if(frame_length==1 && payload[7:0]<=1 && !clear_tone)begin
                        tone_active<=payload[0];tone_changed<=tone_active!=payload[0];response_payload[15:8]<=0;
                    end else response_payload[15:8]<=1;
                    8'he4:if(frame_length==1 && payload[7:0]<=3)begin
                        master_boost<=payload[1:0];response_payload[15:8]<=0;
                    end else response_payload[15:8]<=1;
                    8'he3:if(frame_length==2 && (payload[7:0]==5 || (payload[7:0]>=9 && payload[7:0]<=12) ||
                        payload[7:0]>=8'h40 && payload[7:0]<=8'h56))begin
                        control_valid<=1;control_op<=payload[7:0];control_value<=payload[15:8];
                        // 这里只确认控制已接收；E0错误位回读实际参数校验结果。
                        response_payload[15:8]<=0;
                    end else response_payload[15:8]<=1;
                    8'he5:if(frame_length==2 && payload[7:0]>=8'h60 && payload[7:0]<=8'h69)begin
                        control_valid<=1;control_op<=payload[7:0];control_value<=payload[15:8];response_payload[15:8]<=0;
                    end else response_payload[15:8]<=1;
                    8'he6:if(frame_length==0)begin
                        response_length<=60;response_payload[15:8]<=0;response_payload[47:16]<=32'h3833314e;
                        response_payload[479:48]<=runtime;
                    end else response_payload[15:8]<=1;
                    8'he7:if(frame_length==6 && payload[39:32]<64 && payload[47:40]>0 && payload[47:40]<=32 &&
                        {1'b0,payload[39:32]}+{1'b0,payload[47:40]}<=64 && graph_ready)begin
                        graph_lock<=1;graph_state<=1;response_valid<=0;graph_count<=0;
                        graph_address<=payload[37:32];graph_start<=payload[37:32];graph_total<=payload[45:40];wanted_revision<=payload[31:0];
                    end else response_payload[15:8]<=1;
                    8'he8:if(frame_length==0)begin
                        response_length<=50;response_payload[15:8]<=0;response_payload[47:16]<=32'h4e494147;
                        response_payload[79:48]<=BUILD_ID;
                        response_payload[87:80]<={1'b0,live_volume};response_payload[95:88]<={1'b0,song_volume};
                        response_payload[103:96]<=live_fx_target;response_payload[111:104]<=song_fx_target;
                        response_payload[119:112]<={6'd0,limiter_gain<32768,limiter_enabled};
                        response_payload[127:120]<={6'd0,limiter_release};response_payload[135:128]<={6'd0,master_boost};
                        response_payload[143:136]<=live_fx_gain;response_payload[151:144]<=song_fx_gain;
                        response_payload[159:152]<=1;
                        response_payload[175:160]<=limiter_gain;response_payload[399:176]<=gain_stats;
                    end else if(frame_length==2)begin
                        case(payload[7:0])
                            1:if(payload[15:8]<=128)begin live_fx_target<=payload[15:8];response_payload[15:8]<=0;end else response_payload[15:8]<=1;
                            2:if(payload[15:8]<=128)begin song_fx_target<=payload[15:8];response_payload[15:8]<=0;end else response_payload[15:8]<=1;
                            3:if(payload[15:8]<=1)begin limiter_enabled<=payload[8];response_payload[15:8]<=0;end else response_payload[15:8]<=1;
                            4:if(payload[15:8]<=3)begin limiter_release<=payload[9:8];response_payload[15:8]<=0;end else response_payload[15:8]<=1;
                            5:if(payload[15:8]==0)begin gain_stats_clear<=1;clip_seen<=0;response_payload[15:8]<=0;end else response_payload[15:8]<=1;
                            default:response_payload[15:8]<=1;
                        endcase
                    end else response_payload[15:8]<=1;
                    default:begin end
                endcase
            end
            case(graph_state)
                1:if(lock_granted)begin
                    if(graph_revision!=wanted_revision)begin
                        response_payload[15:8]<=7;response_length<=2;response_valid<=1;graph_lock<=0;graph_state<=0;
                    end else begin
                        response_payload[15:8]<=0;response_payload[47:16]<=graph_revision;
                        response_payload[55:48]<={2'd0,graph_start};response_payload[63:56]<={2'd0,graph_total};
                        response_length<=8+{1'b0,graph_total,1'b0};graph_state<=2;
                    end
                end
                2:graph_state<=3;
                3:begin
                    response_payload[64+graph_count*16+:16]<=graph_data;
                    if(graph_count+1==graph_total)begin graph_state<=0;graph_lock<=0;response_valid<=1;end
                    else begin graph_count<=graph_count+1'b1;graph_address<=graph_address+1'b1;graph_state<=2;end
                end
                default:;
            endcase
        end
    end
endmodule
`default_nettype wire
