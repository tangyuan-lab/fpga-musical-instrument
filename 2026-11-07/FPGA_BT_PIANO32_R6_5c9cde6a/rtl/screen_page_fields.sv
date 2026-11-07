`default_nettype none
// 页面字段读口；只选当前字段，480位快照由发布者保存一次。
module screen_page_fields #(parameter STREAM_SUPPORT=0,TELEMETRY_SUPPORT=0,PIANO32_SUPPORT=0)(
    input wire [7:0] field,input wire [31:0] build_id,voice_mask,timeout_count,
    input wire [2:0] mode,test_kind,input wire [15:0] keys,flags,input wire [5:0] voices,peak_voices,
    input wire [7:0] result,input wire [63:0] peaks,input wire song_ready,ddr_ready,
    input wire [223:0] song_status,input wire [111:0] command_feedback,
    input wire scope_active,scope_overflow,scope_fault,input wire [15:0] graph_data,
    input wire [7:0] saved_graph_config,input wire [31:0] saved_revision,telemetry_word,
    input wire [23:0] scope_pair,input wire packet_gap,packet_channel,input wire [6:0] packet_epoch,
    input wire [15:0] scope_sequence,input wire [3:0] saved_kind,input wire [23:0] saved_sequence,
    input wire [191:0] pressure,output reg [127:0] field_name,output reg [31:0] field_value
);
    always @*begin
        field_name=0;field_value=0;
                case(field)
                    0:begin field_name={"rxBuild.val=",32'd0};field_value=build_id;end
                    1:begin field_name={"rxMode.val=",40'd0};field_value={29'd0,mode};end
                    2:begin field_name={"rxKeys.val=",40'd0};field_value={16'd0,keys};end
                    3:begin field_name={"rxFlags.val=",32'd0};field_value={16'd0,flags};end
                    4:begin field_name={"rxVoices.val=",24'd0};field_value={26'd0,voices};end
                    5:begin field_name={"rxPeak.val=",40'd0};field_value={26'd0,peak_voices};end
                    6:begin field_name={"rxMask.val=",40'd0};field_value=voice_mask&32'h7fffffff;end
                    7:begin field_name={"rxMaskHi.val=",24'd0};field_value={31'd0,voice_mask[31]};end
                    8:begin field_name={"rxLate.val=",40'd0};field_value=timeout_count&32'h7fffffff;end
                    9:begin field_name={"rxTest.val=",40'd0};field_value={29'd0,test_kind};end
                    10:begin field_name={"rxResult.val=",24'd0};field_value={24'd0,result};end
                    11:begin field_name={"rxLink.val=",40'd0};field_value=1;end
                    12,13,14,15:begin
                        field_name={"rxHz",8'(48+field-12),".val=",48'd0};
                        field_value=({16'd0,peaks[(field-12)*16+:16]}*32'd375)>>2;
                    end
                    32:begin field_name="rxSongReady.val=";field_value={31'd0,song_ready};end
                    33:begin field_name={"rxPlay.val=",40'd0};field_value={31'd0,song_status[8]};end
                    34:begin field_name={"rxPause.val=",32'd0};field_value={31'd0,song_status[9]};end
                    35:begin field_name={"rxPosition.val=",8'd0};field_value=song_status[79:48];end
                    36:begin field_name={"rxSection.val=",16'd0};field_value={24'd0,song_status[39:32]};end
                    37:begin field_name={"rxLoop.val=",40'd0};field_value={31'd0,song_status[208]};end
                    38:begin field_name={"rxControl.val=",16'd0};field_value={24'd0,command_feedback[15:8]};end
                    39:begin field_name={"rxDdrReady.val=",8'd0};field_value={31'd0,ddr_ready};end
                    40:if(STREAM_SUPPORT && scope_active)begin field_name={"rxWaveErr.val=",16'd0};field_value={30'd0,scope_overflow,scope_fault};end
                       else begin field_name={"rxG00.val=",48'd0};field_value={16'd0,graph_data};end
                    104:if(TELEMETRY_SUPPORT)begin field_name={"rxWMeta.val=",32'd0};field_value={8'h40,saved_graph_config,saved_revision[15:0]};end
                        else begin field_name={"rxFrame.val=",32'd0};field_value=saved_revision&32'h7fffffff;end
                    105:if(TELEMETRY_SUPPORT)begin field_name={"rxFrame.val=",32'd0};field_value=saved_revision&32'h7fffffff;end
                    128,129,130,131,132,133,134,135:begin
                        field_name={"rxG0",8'(48+field-128),".val=",48'd0};field_value={8'd0,scope_pair};
                    end
                    136:begin field_name={"rxWMeta.val=",32'd0};field_value={23'd0,packet_gap,packet_epoch,packet_channel};end
                    137:begin field_name={"rxFrame.val=",32'd0};field_value={16'd0,scope_sequence};end
                    138:begin field_name="click wavePlot,1";field_value=0;end
                    default:if(field>=16&&field<32)begin
                        field_name={"rxP",8'(48+(field-16)/10),8'(48+(field-16)%10),".val=",48'd0};
                        if(TELEMETRY_SUPPORT&&(saved_kind>=9 || (PIANO32_SUPPORT && saved_kind==8)))
                            field_value=field==31 ? {4'h7,saved_sequence,saved_kind}:telemetry_word&32'h7fffffff;
                        else field_value={20'd0,pressure[(field-16)*12+:12]};
                    end else if(field>=40&&field<104)begin
                        field_name={"rxG",8'(48+(field-40)/10),8'(48+(field-40)%10),".val=",48'd0};field_value={16'd0,graph_data};
                    end
                endcase
    end
endmodule
`default_nettype wire
