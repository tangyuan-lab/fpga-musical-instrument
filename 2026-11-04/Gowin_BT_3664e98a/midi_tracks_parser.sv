`default_nettype none
// 16通道Type0候选解析器。只在整曲上传后运行，不承担电脑逐音符串流。
// 通道归属由WSMX映射表解释，通道9不再被硬编码为鼓。
// RAM无整阵列复位：每次解析前串行清除2048项挂起表，随后每3拍消费一字节。
// 只接受实际支持的音符消息；同通道同音重叠、孤立释音、缺释音、速度溢出均报错。
module midi_tracks_parser #(
    parameter integer MAX_EVENTS=2048,
    parameter integer MAX_TEMPOS=64
)(
    input wire clk,rst_n,start,stop,
    input wire [16:0] file_size,
    output wire [15:0] file_read_address,input wire [7:0] file_read_data,
    output reg busy,ready,error,output reg [3:0] error_code,
    output reg [11:0] event_count,input wire [10:0] event_read_index,
    output wire [31:0] event_start_tick,event_end_tick,
    output wire [3:0] event_channel,output wire [6:0] event_note,output wire [7:0] event_velocity,
    output reg [6:0] tempo_count,input wire [5:0] tempo_read_index,
    output wire [31:0] tempo_tick,output wire [23:0] tempo_us_per_quarter,
    output reg [15:0] division_ppqn,output reg [31:0] parsed_duration
);
    localparam IDLE=4'd0,CLEAR=4'd1,HEADER=4'd2,DELTA=4'd3,STATUS=4'd4,
        DATA1=4'd5,DATA2=4'd6,META_TYPE=4'd7,META_LENGTH=4'd8,META_SKIP=4'd9,TEMPO=4'd10;
    reg [3:0] state;reg [1:0] phase;reg [10:0] clear_index;
    // The selected resource changes outside a parse transaction. Keep its length
    // local and immutable while parsing instead of routing the live directory mux
    // through every byte-boundary check and event-memory enable.
    reg [16:0] accepted_size;
    always @(posedge clk)if(rst_n&&!stop&&!busy&&start)accepted_size<=file_size;
    reg [16:0] position;reg [31:0] track_length,absolute_tick,vlq,remaining,tempo_work,last_tempo_tick;
    reg [2:0] vlq_count;reg [7:0] running_status,data1,meta_type;
    reg [1:0] tempo_byte;reg [11:0] active_count;
    wire consume=busy && state!=CLEAR && phase==2;
    wire [31:0] vlq_next={vlq[24:0],file_read_data[6:0]};
    wire [32:0] tick_next={1'b0,absolute_tick}+{1'b0,vlq_next};
    wire [10:0] key={running_status[3:0],data1[6:0]};
    (* ram_style="block",syn_ramstyle="block_ram" *) reg [11:0] active_slots[0:2047];
    reg [11:0] active_read;
    reg [50:0] info_read;reg [31:0] end_read;reg [55:0] tempo_read;
    // 有效位与事件索引一起存入BRAM，不展开2048位异步复位标志。
    wire note_on=running_status[7:4]==4'h9 && file_read_data!=0;
    wire valid_note=rst_n && !stop && consume && state==DATA2 && !file_read_data[7] && position<accepted_size;
    wire write_on=valid_note && note_on && !active_read[11] && event_count<MAX_EVENTS;
    wire write_off=valid_note && !note_on && active_read[11] && absolute_tick>info_read[50:19];
    wire slot_write=rst_n && ((busy && state==CLEAR) || write_on || write_off);
    wire [10:0] slot_address=state==CLEAR ? clear_index:key;
    wire [11:0] slot_data=state==CLEAR || write_off ? 12'd0:{1'b1,event_count[10:0]};
    (* ram_style="block",syn_ramstyle="block_ram" *) reg [50:0] info_mem[0:MAX_EVENTS-1];
    (* ram_style="block",syn_ramstyle="block_ram" *) reg [31:0] end_mem[0:MAX_EVENTS-1];
    (* ram_style="block",syn_ramstyle="block_ram" *) reg [55:0] tempo_mem[0:MAX_TEMPOS-1];
    wire tempo_commit=rst_n && !stop && consume && state==TEMPO && tempo_byte==2 && position<accepted_size;
    wire [23:0] tempo_value={tempo_work[15:0],file_read_data};
    wire tempo_replace=absolute_tick==0 && tempo_count==1;
    wire tempo_valid=tempo_commit && tempo_value!=0 &&
        (tempo_replace || (tempo_count<MAX_TEMPOS && absolute_tick>last_tempo_tick));
    wire tempo_clear=rst_n && !stop && busy && state==CLEAR && clear_index==0;
    wire tempo_write=tempo_clear || tempo_valid;
    wire [5:0] tempo_write_address=tempo_clear || tempo_replace ? 6'd0:tempo_count[5:0];
    wire [55:0] tempo_write_data=tempo_clear ? {32'd0,24'd500000}:{absolute_tick,tempo_value};
    assign file_read_address=position[15:0];
    assign {event_start_tick,event_channel,event_note,event_velocity}=info_read;
    assign event_end_tick=end_read;
    assign {tempo_tick,tempo_us_per_quarter}=tempo_read;
    always @(posedge clk) begin
        active_read<=active_slots[key];
        if(slot_write) active_slots[slot_address]<=slot_data;
        if(write_on) info_mem[event_count[10:0]]<={absolute_tick,running_status[3:0],data1[6:0],file_read_data};
        if(write_off) end_mem[active_read[10:0]]<=absolute_tick;
        // 默认值与后续速度共用同一写口，避免被综合成两写口寄存器阵列。
        if(tempo_write) tempo_mem[tempo_write_address]<=tempo_write_data;
        // 上传解析期借用信息读口校验释音晚于起音；ready后才向播放器开放读索引。
        info_read<=info_mem[busy ? active_read[10:0]:event_read_index];
        end_read<=end_mem[event_read_index];tempo_read<=tempo_mem[tempo_read_index];
    end
    function automatic [7:0] header_byte(input [4:0] index);
        case(index)
            0:header_byte="M";1:header_byte="T";2:header_byte="h";3:header_byte="d";
            7:header_byte=6;11:header_byte=1;
            14:header_byte="M";15:header_byte="T";16:header_byte="r";17:header_byte="k";
            default:header_byte=0;
        endcase
    endfunction
    task automatic fail(input [3:0] code);
        begin error<=1;error_code<=code;busy<=0;ready<=0;state<=IDLE;end
    endtask
    always @(posedge clk) begin
        if(!rst_n) begin
            state<=IDLE;phase<=0;clear_index<=0;position<=0;track_length<=0;
            absolute_tick<=0;vlq<=0;vlq_count<=0;remaining<=0;tempo_work<=0;tempo_byte<=0;
            running_status<=0;data1<=0;meta_type<=0;active_count<=0;last_tempo_tick<=0;
            busy<=0;ready<=0;error<=0;error_code<=0;event_count<=0;tempo_count<=1;
            division_ppqn<=480;parsed_duration<=0;
        end else if(stop) begin busy<=0;ready<=0;state<=IDLE;phase<=0;end
        else if(!busy) begin
            if(start) begin
                ready<=0;error<=0;error_code<=0;event_count<=0;tempo_count<=1;last_tempo_tick<=0;
                parsed_duration<=0;absolute_tick<=0;active_count<=0;running_status<=0;
                position<=0;phase<=0;clear_index<=0;state<=CLEAR;busy<=1;
                vlq<=0;vlq_count<=0;track_length<=0;
                if(file_size<26 || file_size>65536) fail(1);
            end
        end else if(state==CLEAR) begin
            if(clear_index==2047) begin state<=HEADER;phase<=0;end
            else clear_index<=clear_index+1'b1;
        end else if(phase!=2) phase<=phase+1'b1;
        else begin
            phase<=0;position<=position+1'b1;
            if(position>=accepted_size) fail(2);
            else case(state)
                HEADER:begin
                    if(position==12) begin
                        division_ppqn[15:8]<=file_read_data;
                        if(file_read_data[7]) fail(3);
                    end else if(position==13) begin
                        division_ppqn[7:0]<=file_read_data;
                        if({division_ppqn[15:8],file_read_data}==0) fail(3);
                    end else if(position>=18) begin
                        track_length<={track_length[23:0],file_read_data};
                        if(position==21) begin
                            if({track_length[23:0],file_read_data}+33'd22!={16'd0,accepted_size}) fail(4);
                            else begin state<=DELTA;vlq<=0;vlq_count<=0;end
                        end
                    end else if(file_read_data!=header_byte(position[4:0])) fail(4);
                end
                DELTA:begin
                    vlq<=vlq_next;vlq_count<=vlq_count+1'b1;
                    if(vlq_count==3 && file_read_data[7]) fail(5);
                    else if(!file_read_data[7]) begin
                        if(tick_next[32]) fail(5);
                        else begin absolute_tick<=tick_next[31:0];state<=STATUS;end
                    end
                end
                STATUS:begin
                    if(file_read_data==8'hff) begin state<=META_TYPE;running_status<=0;end
                    else if(file_read_data[7]) begin
                        if(file_read_data[7:4]!=4'h8 && file_read_data[7:4]!=4'h9) fail(6);
                        else begin running_status<=file_read_data;state<=DATA1;end
                    end else if(running_status[7:4]==4'h8 || running_status[7:4]==4'h9) begin
                        data1<=file_read_data;state<=DATA2;
                    end else fail(6);
                end
                DATA1:begin
                    if(file_read_data[7]) fail(6);
                    else begin data1<=file_read_data;state<=DATA2;end
                end
                DATA2:begin
                    state<=DELTA;vlq<=0;vlq_count<=0;
                    if(file_read_data[7]) fail(6);
                    else if(note_on) begin
                        if(active_read[11]) fail(7);
                        else if(event_count>=MAX_EVENTS) fail(8);
                        else begin event_count<=event_count+1'b1;active_count<=active_count+1'b1;end
                    end else if(!active_read[11] || absolute_tick<=info_read[50:19]) fail(7);
                    else active_count<=active_count-1'b1;
                end
                META_TYPE:begin meta_type<=file_read_data;state<=META_LENGTH;vlq<=0;vlq_count<=0;end
                META_LENGTH:begin
                    vlq<=vlq_next;vlq_count<=vlq_count+1'b1;
                    if(vlq_count==3 && file_read_data[7]) fail(5);
                    else if(!file_read_data[7]) begin
                        if(vlq_next>{15'd0,accepted_size-position-1'b1}) fail(2);
                        else if(meta_type==8'h2f) begin
                            if(vlq_next!=0 || active_count!=0 || position+1'b1!=accepted_size) fail(9);
                            else begin parsed_duration<=absolute_tick;busy<=0;ready<=1;state<=IDLE;end
                        end else if(meta_type==8'h51) begin
                            if(vlq_next!=3) fail(10);
                            else begin tempo_byte<=0;tempo_work<=0;state<=TEMPO;end
                        end else if(vlq_next==0) begin state<=DELTA;vlq<=0;vlq_count<=0;end
                        else begin remaining<=vlq_next;state<=META_SKIP;end
                    end
                end
                META_SKIP:begin
                    if(remaining==1) begin state<=DELTA;vlq<=0;vlq_count<=0;end
                    else remaining<=remaining-1'b1;
                end
                TEMPO:begin
                    tempo_work<={tempo_work[23:0],file_read_data};tempo_byte<=tempo_byte+1'b1;
                    if(tempo_byte==2) begin
                        if(!tempo_valid) fail(10);
                        else begin
                            if(!tempo_replace) tempo_count<=tempo_count+1'b1;
                            last_tempo_tick<=absolute_tick;state<=DELTA;vlq<=0;vlq_count<=0;
                        end
                    end
                end
                default:fail(15);
            endcase
        end
    end
endmodule
`default_nettype wire
