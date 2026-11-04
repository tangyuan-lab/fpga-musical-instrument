`default_nettype none
// 等待式单音教学。实体(source0/key0..15)与屏幕(source1/key16..31)均可完成。
// 同一来源、键号、音符ID的成功新起音/释音配对推进；压力/保活更新和伴奏不能计分。
// action:0退出,1内置小星星,2上传旋律轨,3暂停,4继续,5从头；ACK仅确认准备请求。
module pressure_lesson(
    input wire clk,rst_n,clear,request,input wire [2:0] action,input wire [3:0] selected_track,
    input wire source_available,source_quiet,parser_ready,parser_busy,parser_error,
    input wire [11:0] event_count,input wire [31:0] event_start,event_end,
    input wire [6:0] event_note,input wire [3:0] event_track,
    input wire [111:0] physical_pitch_map,input wire [15:0] enabled_keys,
    input wire signed [6:0] transpose,
    input wire [15:0] physical_down,screen_down,
    input wire accepted_valid,input wire [1:0] accepted_op,accepted_source,
    input wire [4:0] accepted_key,input wire [31:0] accepted_id,
    input wire [6:0] accepted_note,input wire [2:0] accepted_result,
    output reg prepare_parser,output wire reader_enable,output wire [10:0] reader_index,
    output reg done,output reg [7:0] result,
    output wire active,output wire [15:0] guide_keys,output wire [255:0] status
);
    localparam IDLE=0,WAIT_PARSE=1,LOAD=2,WAIT_RELEASE=3,WAIT_PRESS=4,CORRECT=5,FINISHED=6,ERROR=7;
    reg [2:0] state;reg external_source,paused,prepare_seen_busy,course_ready;
    reg [3:0] track;reg [111:0] map_snapshot;reg [15:0] enabled_snapshot;
    reg signed [6:0] transpose_snapshot;
    reg [11:0] load_index,length,position;
    reg [1:0] read_phase,settle;
    reg [31:0] previous_end,prepare_wait,correct_id,revision;
    reg correct_source;
    reg [15:0] wrong_keys;reg [7:0] error_code;reg [6:0] last_note;
    (* ram_style="block",syn_ramstyle="block_ram" *) reg [10:0] steps[0:2047];
    reg [10:0] current_word,next_word;
    wire [6:0] target_note=current_word[10:4];wire [3:0] target_key=current_word[3:0];
    wire target_available=course_ready&&position<length;
    wire source_key_valid=(accepted_source==0&&accepted_key<16)||(accepted_source==1&&accepted_key>=16);
    wire [3:0] event_key=accepted_key[3:0];
    wire [15:0] event_mask=16'd1<<event_key;
    wire one_live_key=accepted_source==0 ? physical_down==event_mask&&screen_down==0 : screen_down==event_mask&&physical_down==0;
    wire correct_released=correct_source ? !screen_down[target_key]:!physical_down[target_key];
    wire signed [8:0] imported_note=$signed({2'd0,event_note})+$signed(transpose_snapshot);
    function automatic [6:0] twinkle(input [5:0] i);
        reg [5:0] p;
        begin
            p=i>=28 ? i-28:i;
            if(p<7)case(p)0,1:twinkle=60;2,3:twinkle=67;4,5:twinkle=69;default:twinkle=67;endcase
            else if(p<14)case(p)7,8:twinkle=65;9,10:twinkle=64;11,12:twinkle=62;default:twinkle=60;endcase
            else begin
                p=p>=21 ? p-21:p-14;
                case(p)0,1:twinkle=67;2,3:twinkle=65;4,5:twinkle=64;default:twinkle=62;endcase
            end
        end
    endfunction
    wire [6:0] candidate_note=external_source ? imported_note[6:0]:twinkle(load_index[5:0]);
    reg key_found;reg [3:0] candidate_key;integer k;
    always @*begin
        key_found=0;candidate_key=0;
        for(k=0;k<16;k=k+1)if(!key_found&&enabled_snapshot[k]&&map_snapshot[k*7+:7]==candidate_note)begin
            key_found=1;candidate_key=k;
        end
    end
    assign active=state>=WAIT_PARSE&&state<=CORRECT;
    assign reader_enable=external_source&&state==LOAD;
    assign reader_index=load_index[10:0];
    assign guide_keys=course_ready&&!paused&&(state==WAIT_PRESS||state==CORRECT) ? (16'd1<<target_key):16'd0;
    // 低字节起：阶段/暂停/错误/轨、位置/长度、目标/下一音、真实键/错键、版本号。
    assign status={revision,32'd0,correct_id,15'd0,correct_source,screen_down,physical_down,wrong_keys,
        1'b0,last_note,(course_ready&&position+1<length?{1'b0,next_word[10:4]}:8'hff),
        (target_available?{1'b0,target_note}:8'hff),(target_available?{4'd0,target_key}:8'hff),
        4'd0,length,4'd0,position,4'd0,track,error_code,7'd0,paused,5'd0,state};
    always @(posedge clk)begin
        current_word<=steps[position[10:0]];
        next_word<=steps[11'(position+1'b1)];
        prepare_parser<=0;done<=0;
        if(!rst_n||clear)begin
            state<=IDLE;external_source<=0;paused<=0;track<=0;map_snapshot<=0;enabled_snapshot<=0;
            transpose_snapshot<=0;load_index<=0;length<=0;position<=0;read_phase<=0;settle<=0;
            previous_end<=0;prepare_wait<=0;prepare_seen_busy<=0;course_ready<=0;correct_id<=0;correct_source<=0;revision<=0;wrong_keys<=0;error_code<=0;last_note<=0;result<=0;
        end else begin
            if(!request)begin
            case(state)
                WAIT_PARSE:begin
                    if(parser_busy||!parser_ready)prepare_seen_busy<=1;
                    if(parser_error)begin state<=ERROR;error_code<=3;end
                    else if(prepare_seen_busy&&parser_ready&&!parser_busy&&source_quiet)begin state<=LOAD;load_index<=0;read_phase<=0;end
                    else if(prepare_wait==25_000_000)begin state<=ERROR;error_code<=8'hfd;end
                    else prepare_wait<=prepare_wait+1'b1;
                end
                LOAD:begin
                    if(read_phase!=2)read_phase<=read_phase+1'b1;
                    else if(load_index>=(external_source?event_count:12'd42))begin
                        if(length==0)begin state<=ERROR;error_code<=2;end
                        else begin state<=WAIT_RELEASE;settle<=3;position<=0;revision<=revision+1'b1;course_ready<=1;end
                    end else begin
                        read_phase<=0;load_index<=load_index+1'b1;
                        if(!external_source||event_track==track)begin
                            if((external_source&&(imported_note<21||imported_note>108))||!key_found)begin state<=ERROR;error_code<=5;end
                            else if(external_source&&(event_start<previous_end||event_end<=event_start))begin state<=ERROR;error_code<=6;end
                            else if(length>=2048)begin state<=ERROR;error_code<=7;end
                            else begin
                                steps[length[10:0]]<={candidate_note,candidate_key};length<=length+1'b1;
                                previous_end<=event_end;
                            end
                        end
                    end
                end
                WAIT_RELEASE:if(settle!=0)settle<=settle-1'b1;
                    else if(!paused&&physical_down==0&&screen_down==0)begin state<=WAIT_PRESS;wrong_keys<=0;end
                WAIT_PRESS:if(!paused&&accepted_valid&&source_key_valid&&accepted_op==1&&accepted_result==0)begin
                    last_note<=accepted_note;
                    if(event_key==target_key&&accepted_note==target_note&&one_live_key)begin
                        state<=CORRECT;correct_id<=accepted_id;correct_source<=accepted_source[0];wrong_keys<=0;revision<=revision+1'b1;
                    end else wrong_keys[event_key]<=1;
                end
                CORRECT:if(!paused&&accepted_valid&&source_key_valid&&accepted_source=={1'b0,correct_source}&&accepted_op==0&&
                    event_key==target_key&&accepted_id==correct_id&&accepted_result==0&&correct_released)begin
                    revision<=revision+1'b1;
                    if(position+1>=length)begin state<=FINISHED;position<=length;end
                    else begin position<=position+1'b1;state<=WAIT_RELEASE;settle<=3;end
                end
                default:;
            endcase
            end
            if(request)begin
                done<=1;result<=0;
                case(action)
                    0:begin state<=IDLE;paused<=0;wrong_keys<=0;end
                    1,2:begin
                        if(action==2&&!source_available)result<=2;
                        else begin
                            external_source<=action==2;map_snapshot<=physical_pitch_map;enabled_snapshot<=enabled_keys;
                            transpose_snapshot<=transpose;track<=selected_track;length<=0;position<=0;load_index<=0;read_phase<=0;
                            paused<=0;error_code<=0;wrong_keys<=0;previous_end<=0;prepare_wait<=0;prepare_seen_busy<=0;course_ready<=0;
                            if(action==2)begin prepare_parser<=1;state<=WAIT_PARSE;end else state<=LOAD;
                        end
                    end
                    // 预载尚未完成时不能通过暂停/继续绕过课程有效性检查。
                    3:if(active&&course_ready)begin paused<=1;state<=WAIT_RELEASE;settle<=3;end else result<=4;
                    4:if(active&&paused&&course_ready)begin paused<=0;state<=WAIT_RELEASE;settle<=3;end else result<=4;
                    5:if(course_ready)begin position<=0;state<=WAIT_RELEASE;settle<=3;paused<=0;wrong_keys<=0;end else result<=2;
                    default:result<=1;
                endcase
            end
        end
    end
endmodule
`default_nettype wire
