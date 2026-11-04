`default_nettype none
// 每次只发送一个短数值指令，RX独立。图像64字发送完成后rxFrame才变化，屏幕原子重绘。
// 无有效图像时不发送垃圾RAM；页面非观察/测试时不传图，控制及演奏不等待图形。
module mega138_screen_tx #(
    parameter integer CLKS_PER_BIT=434,UPDATE_CYCLES=5_000_000,STARTUP_CYCLES=50_000_000,
    STREAM_SUPPORT=0,TELEMETRY_SUPPORT=0,STREAM_UPDATE_CYCLES=12_500_000,ACK_TIMEOUT_CYCLES=25_000_000
)(
    input wire clk,rst_n,
    input wire [3:0] view,input wire [2:0] mode,test_kind,
    input wire [31:0] build_id,voice_mask,timeout_count,revision,
    input wire [5:0] voices,peak_voices,
    input wire [15:0] keys,flags,
    input wire [191:0] pressure,
    input wire [479:0] telemetry,input wire [7:0] graph_config,
    input wire [7:0] result,
    input wire [223:0] song_status,input wire song_ready,ddr_ready,
    input wire [111:0] command_feedback,
    input wire [63:0] peaks,
    input wire graph_ready,lock_granted,
    input wire [15:0] graph_data,
    input wire [1:0] graph_kind,
    input wire freeze_graph,right_channel,
    input wire scope_command_valid,input wire [7:0] scope_command_op,scope_command_value,
    input wire [6:0] scope_available,input wire [23:0] scope_pair,input wire scope_overflow,
    output reg scope_pop,scope_clear,output wire scope_capture_enable,
    output reg graph_lock,output wire [5:0] graph_address,
    output wire tx
);
    reg [31:0] timer;reg [7:0] field;reg [3:0] state;
    // 0x7/24位序号/4位视图是提交标记；15个数据字先发送，rxP15最后提交。
    // 整组在field0锁存，页面中途切换不能把两页状态拼成同一帧。
    reg [479:0] saved_telemetry;reg [3:0] saved_kind;
    reg [23:0] telemetry_sequence,saved_sequence;reg [7:0] saved_graph_config;
    // 同一帧首抓取480位；这是数据CE，禁止被当作时钟使用或重新合并成大范围控制网。
    (* syn_keep=1 *) wire telemetry_capture_enable=TELEMETRY_SUPPORT && state==4'd1 && field==8'd0;
    reg [31:0] telemetry_word;
    // 字段16..30只使用低4位索引15个固定字，避免8位减法/32位移位选择网络。
    // 字段31仍由独立提交标记覆盖；其他字段不使用这个选择结果。
    always @*begin
        case(field[3:0])
            0:telemetry_word=saved_telemetry[0*32+:32];
            1:telemetry_word=saved_telemetry[1*32+:32];
            2:telemetry_word=saved_telemetry[2*32+:32];
            3:telemetry_word=saved_telemetry[3*32+:32];
            4:telemetry_word=saved_telemetry[4*32+:32];
            5:telemetry_word=saved_telemetry[5*32+:32];
            6:telemetry_word=saved_telemetry[6*32+:32];
            7:telemetry_word=saved_telemetry[7*32+:32];
            8:telemetry_word=saved_telemetry[8*32+:32];
            9:telemetry_word=saved_telemetry[9*32+:32];
            10:telemetry_word=saved_telemetry[10*32+:32];
            11:telemetry_word=saved_telemetry[11*32+:32];
            12:telemetry_word=saved_telemetry[12*32+:32];
            13:telemetry_word=saved_telemetry[13*32+:32];
            14:telemetry_word=saved_telemetry[14*32+:32];
            default:telemetry_word=32'd0;
        endcase
    end
    reg [127:0] name;reg [31:0] value,saved_revision;reg [7:0] byte_index;
    reg [79:0] digits;reg [3:0] digit_count;
    reg [31:0] binary_value;reg [39:0] bcd_value,bcd_adjusted;reg [5:0] convert_step;
    integer bcd_digit,ascii_digit;
    reg send;reg [7:0] data;wire busy;reg [3:0] ff_count;
    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) uart(.clk(clk),.rst_n(rst_n),.data(data),.start(send),.tx(tx),.busy(busy),.done());
    assign graph_address=field>=40 ? 6'(field-40):6'd0;
    wire graph_page=view==7||view==8;
    reg [6:0] scope_epoch,packet_epoch;
    reg packet_channel,packet_gap,gap_pending,reset_pending,scope_fault;
    reg previous_active,previous_freeze,previous_channel;
    reg [7:0] resume_field,ack_low;reg ack_low_valid;
    reg [15:0] scope_sequence;reg waiting_ack,retry_pending;reg [1:0] retries;
    reg [24:0] ack_timer;
    wire scope_active=STREAM_SUPPORT && scope_epoch!=0 && view==7 && graph_kind==0;
    wire new_epoch=STREAM_SUPPORT && scope_command_valid && scope_command_op==8'h6a &&
                   scope_command_value<=127 && scope_command_value[6:0]!=scope_epoch;
    wire reconfigure=new_epoch || (STREAM_SUPPORT && (previous_active!=scope_active || previous_freeze!=freeze_graph || previous_channel!=right_channel));
    wire matched_ack=STREAM_SUPPORT && waiting_ack && scope_command_valid && scope_command_op==8'h6d &&
                     ack_low_valid && ack_low==scope_sequence[7:0] && scope_command_value==scope_sequence[15:8];
    assign scope_capture_enable=scope_active && !freeze_graph && !reset_pending && !reconfigure && !scope_overflow && !scope_fault;
    // 逐拍double-dabble：每拍十个独立4位加3后移1位，32拍覆盖整个uint32。
    // 比组合32位除10多几十拍，但仍远短于UART一字节时间；不修改音频与采样调度。
    always @*begin
        bcd_adjusted=bcd_value;
        for(bcd_digit=0;bcd_digit<10;bcd_digit=bcd_digit+1)
            if(bcd_value[bcd_digit*4+:4]>=5)bcd_adjusted[bcd_digit*4+:4]=bcd_value[bcd_digit*4+:4]+4'd3;
    end
    // 前缀名称左对齐、零结束；数值仅非负十进制，主机/屏幕负责单位及符号显示。
    always @(posedge clk)begin
        send<=0;scope_pop<=0;scope_clear<=0;
        if(!rst_n)begin timer<=STARTUP_CYCLES;field<=0;state<=0;name<=0;value<=0;byte_index<=0;
            saved_telemetry<=0;saved_kind<=0;telemetry_sequence<=0;saved_sequence<=0;saved_graph_config<=0;
            digits<=0;digit_count<=0;binary_value<=0;bcd_value<=0;convert_step<=0;graph_lock<=0;ff_count<=0;saved_revision<=0;
            scope_epoch<=0;packet_epoch<=0;packet_channel<=0;packet_gap<=0;gap_pending<=0;reset_pending<=1;scope_fault<=0;
            previous_active<=0;previous_freeze<=0;previous_channel<=0;resume_field<=0;ack_low<=0;ack_low_valid<=0;
            scope_sequence<=0;waiting_ack<=0;retry_pending<=0;retries<=0;ack_timer<=0;
        end else begin
          if(STREAM_SUPPORT)begin
            previous_active<=scope_active;previous_freeze<=freeze_graph;previous_channel<=right_channel;
            if(new_epoch)begin scope_epoch<=scope_command_value[6:0];scope_fault<=0;end
            if(reconfigure)begin reset_pending<=1;waiting_ack<=0;retry_pending<=0;gap_pending<=0;ack_low_valid<=0;end
            if(scope_overflow)begin reset_pending<=1;gap_pending<=1;end
            if(scope_command_valid && scope_command_op==8'h6c && waiting_ack)begin ack_low<=scope_command_value;ack_low_valid<=1;end
            if(matched_ack)begin waiting_ack<=0;retry_pending<=0;ack_timer<=0;ack_low_valid<=0;end
            else if(waiting_ack && !retry_pending && !reconfigure)begin
                if(ack_timer==ACK_TIMEOUT_CYCLES-1)begin
                    ack_timer<=0;
                    if(retries==2)begin scope_fault<=1;waiting_ack<=0;reset_pending<=1;end
                    else retry_pending<=1;
                end else ack_timer<=ack_timer+1'b1;
            end
          end
          case(state)
            0:if(STREAM_SUPPORT && (reset_pending || retry_pending ||
                    (scope_active && !freeze_graph && !scope_fault && !waiting_ack && scope_available>=8)))begin field<=127;state<=1;end
              else if(timer!=0)timer<=timer-1'b1;else begin field<=0;state<=1;end
            1:begin
                name<=0;value<=0;byte_index<=0;
                if(telemetry_capture_enable)begin
                    saved_telemetry<=telemetry;saved_kind<=view;
                    telemetry_sequence<=telemetry_sequence+1'b1;saved_sequence<=telemetry_sequence+1'b1;
                end
                case(field)
                    0:begin name<={"rxBuild.val=",32'd0};value<=build_id;end
                    1:begin name<={"rxMode.val=",40'd0};value<={29'd0,mode};end
                    2:begin name<={"rxKeys.val=",40'd0};value<={16'd0,keys};end
                    3:begin name<={"rxFlags.val=",32'd0};value<={16'd0,flags};end
                    4:begin name<={"rxVoices.val=",24'd0};value<={26'd0,voices};end
                    5:begin name<={"rxPeak.val=",40'd0};value<={26'd0,peak_voices};end
                    6:begin name<={"rxMask.val=",40'd0};value<=voice_mask&32'h7fffffff;end
                    7:begin name<={"rxMaskHi.val=",24'd0};value<={31'd0,voice_mask[31]};end
                    8:begin name<={"rxLate.val=",40'd0};value<=timeout_count&32'h7fffffff;end
                    9:begin name<={"rxTest.val=",40'd0};value<={29'd0,test_kind};end
                    10:begin name<={"rxResult.val=",24'd0};value<={24'd0,result};end
                    11:begin name<={"rxLink.val=",40'd0};value<=1;end
                    12,13,14,15:begin
                        name<={"rxHz",8'(48+field-12),".val=",48'd0};
                        value<=({16'd0,peaks[(field-12)*16+:16]}*32'd375)>>2;
                    end
                    32:begin name<="rxSongReady.val=";value<={31'd0,song_ready};end
                    33:begin name<={"rxPlay.val=",40'd0};value<={31'd0,song_status[8]};end
                    34:begin name<={"rxPause.val=",32'd0};value<={31'd0,song_status[9]};end
                    35:begin name<={"rxPosition.val=",8'd0};value<=song_status[79:48];end
                    36:begin name<={"rxSection.val=",16'd0};value<={24'd0,song_status[39:32]};end
                    37:begin name<={"rxLoop.val=",40'd0};value<={31'd0,song_status[208]};end
                    38:begin name<={"rxControl.val=",16'd0};value<={24'd0,command_feedback[15:8]};end
                    39:begin name<={"rxDdrReady.val=",8'd0};value<={31'd0,ddr_ready};end
                    40:if(STREAM_SUPPORT && scope_active)begin name<={"rxWaveErr.val=",16'd0};value<={30'd0,scope_overflow,scope_fault};end
                       else begin name<={"rxG00.val=",48'd0};value<={16'd0,graph_data};end
                    104:if(TELEMETRY_SUPPORT)begin name<={"rxWMeta.val=",32'd0};value<={8'h40,saved_graph_config,saved_revision[15:0]};end
                        else begin name<={"rxFrame.val=",32'd0};value<=saved_revision&32'h7fffffff;end
                    105:if(TELEMETRY_SUPPORT)begin name<={"rxFrame.val=",32'd0};value<=saved_revision&32'h7fffffff;end
                    128,129,130,131,132,133,134,135:begin
                        name<={"rxG0",8'(48+field-128),".val=",48'd0};value<={8'd0,scope_pair};
                    end
                    136:begin name<={"rxWMeta.val=",32'd0};value<={23'd0,packet_gap,packet_epoch,packet_channel};end
                    137:begin name<={"rxFrame.val=",32'd0};value<={16'd0,scope_sequence};end
                    138:begin name<="click wavePlot,1";value<=0;end
                    default:if(field>=16&&field<32)begin
                        name<={"rxP",8'(48+(field-16)/10),8'(48+(field-16)%10),".val=",48'd0};
                        if(TELEMETRY_SUPPORT&&saved_kind>=9)
                            value<=field==31 ? {4'h7,saved_sequence,saved_kind}:telemetry_word&32'h7fffffff;
                        else value<={20'd0,pressure[(field-16)*12+:12]};
                    end else if(field>=40&&field<104)begin
                        name<={"rxG",8'(48+(field-40)/10),8'(48+(field-40)%10),".val=",48'd0};value<={16'd0,graph_data};
                    end
                endcase
                // 取锁只执行一次；取得锁后field仍为40，必须进入发送，不能再次取锁形成死循环。
                if(STREAM_SUPPORT && field<128 && reset_pending && !reconfigure && !waiting_ack)begin
                    scope_clear<=1;reset_pending<=0;
                end else if(STREAM_SUPPORT && field<128 && retry_pending && waiting_ack && !reconfigure && !matched_ack)begin
                    resume_field<=field;field<=138;retries<=retries+1'b1;retry_pending<=0;ack_low_valid<=0;
                end else if(STREAM_SUPPORT && field<128 && scope_active && !freeze_graph && !scope_fault && !waiting_ack &&
                            !reset_pending && !reconfigure && !scope_overflow && scope_available>=8)begin
                    resume_field<=field;field<=128;scope_sequence<=scope_sequence+1'b1;packet_epoch<=scope_epoch;
                    packet_channel<=right_channel;packet_gap<=gap_pending;gap_pending<=0;retries<=0;ack_low_valid<=0;
                end else if(STREAM_SUPPORT && field==127)begin state<=0;end
                else if(STREAM_SUPPORT && field==139)begin
                    field<=resume_field;waiting_ack<=!reset_pending && !reconfigure;ack_timer<=0;state<=1;
                end else if(STREAM_SUPPORT && scope_active && field==41)begin timer<=STREAM_UPDATE_CYCLES;state<=0;end
                else if(field==40&&!graph_lock && !(STREAM_SUPPORT && scope_active))begin
                    if(graph_page&&graph_ready)begin graph_lock<=1;state<=9;end
                    else begin timer<=UPDATE_CYCLES;state<=0;end
                end else if((!TELEMETRY_SUPPORT&&field==105)||(TELEMETRY_SUPPORT&&field==106))begin graph_lock<=0;timer<=UPDATE_CYCLES;state<=0;end
                else begin
                    if(STREAM_SUPPORT && field>=128 && field<=135)scope_pop<=1;
                    state<=2;
                end
            end
            2:begin binary_value<=value;bcd_value<=0;convert_step<=0;digits<=0;digit_count<=0;state<=3;end
            3:begin
                bcd_value<={bcd_adjusted[38:0],binary_value[31]};binary_value<=binary_value<<1;
                convert_step<=convert_step+1'b1;
                if(convert_step==31)state<=10;
            end
            4:if(!busy&&!send)begin
                if(name[127:120]!=0)begin data<=name[127:120];name<=name<<8;send<=1;end
                else if(STREAM_SUPPORT && field==138)begin ff_count<=0;state<=6;end
                else state<=5;
            end
            5:if(!busy&&!send)begin
                if(digit_count!=0)begin data<=digits[7:0];digits<=digits>>8;digit_count<=digit_count-1'b1;send<=1;end
                else begin ff_count<=0;state<=6;end
            end
            6:if(!busy&&!send)begin data<=8'hff;send<=1;
                if(ff_count==2)begin field<=field+1'b1;state<=7;end else ff_count<=ff_count+1'b1;end
            7:if(!busy&&!send)state<=8;
            8:state<=1; // 同步RAM读口地址更换后至少两拍才能取数据。
            9:if(lock_granted)begin saved_revision<=revision;saved_graph_config<=graph_config;field<=40;state<=7;end
            10:begin
                for(ascii_digit=0;ascii_digit<10;ascii_digit=ascii_digit+1)
                    digits[ascii_digit*8+:8]<={4'd3,bcd_value[39-ascii_digit*4-:4]};
                digit_count<=10;state<=11;
            end
            11:if(digit_count>1 && digits[7:0]==8'd48)begin digits<=digits>>8;digit_count<=digit_count-1'b1;end
                else state<=4;
            default:state<=0;
          endcase
        end
    end
endmodule
`default_nettype wire
