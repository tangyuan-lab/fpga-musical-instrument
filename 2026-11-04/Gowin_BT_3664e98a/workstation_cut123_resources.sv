`default_nettype none
// 曲谱资源管理：单曲共享8个4 KiB页，固定内置音源；支持32段配器，不支持动态音色上传。
// 数据块全部落RAM后ACK，同序号重试只重发响应；CRC32通过才发布目录。
module workstation_cut123_resources #(parameter ENABLE_EMERGENCY=0,BUILTIN_PIANO=0)(
    input wire clk,rst_n,
    output wire remote_idle,
    input wire frame_valid,input wire [7:0] frame_type,input wire [15:0] frame_seq,frame_length,
    input wire [1055:0] payload,
    output reg response_valid,output reg [15:0] response_seq,output reg [7:0] response_length,
    output reg [767:0] response_payload,input wire response_busy,
    output reg control_valid,output reg [7:0] control_op,output reg [31:0] control_value,control_aux,
    input wire control_done,input wire [7:0] control_result,
    input wire [223:0] status_data,input wire [399:0] hardware_status,
    input wire [63:0] chord_status,
    input wire [511:0] demo_audio_status,demo_fx_status,
    input wire [127:0] demo_note_status,input wire [255:0] demo_lesson_status,
    input wire [95:0] damping_settings,
    input wire [1:0] velocity_tone_setting,
    output reg [10:0] pressure_touch_settings,
    input wire [175:0] runtime_data,input wire [111:0] command_feedback,
    input wire [255:0] track_gains,input wire [127:0] track_timbres,track_volumes,
    input wire [15:0] track_mutes,track_solos,input wire [63:0] channel_map,
    output reg validation_start,validation_release,input wire validation_done,validation_busy,validation_error,input wire [31:0] validation_duration,
    input wire [1:0] selected_song,input wire [15:0] song_read_address,output wire [7:0] song_read_data,
    output wire [16:0] selected_size,output wire selected_ready,output wire [31:0] selected_duration,
    output wire [31:0] song_ready_mask,output wire [7:0] patch_ready_mask,
    output wire table_write,output wire [10:0] table_address,output wire signed [15:0] table_data,
    output reg parameter_write,output reg [4:0] parameter_bank,
    output reg [47:0] envelope_parameters,
    input wire external_adsr_valid,input wire [31:0] external_adsr_value,external_adsr_aux,
    output reg external_adsr_done,output reg [7:0] external_adsr_result,
    input wire [4:0] envelope_read_bank,output wire [47:0] envelope_read_data,
    input wire [6:0] section_read_address,output reg [191:0] section_data,
    output wire [5:0] selected_sections,
    input wire [3:0] catalog_index,output reg [255:0] catalog_name,output reg catalog_ready,
    output reg [31:0] catalog_duration,output reg [5:0] catalog_sections,
    output reg [31:0] directory_revision,
    input wire emergency_abort,
    input wire storage_ready,
    output wire ddr_req_valid,input wire ddr_req_ready,output wire ddr_req_write,
    output wire [31:0] ddr_req_address,output wire [255:0] ddr_req_data,output wire [31:0] ddr_req_mask,
    input wire ddr_resp_valid,ddr_resp_error,input wire [255:0] ddr_resp_data,output wire ddr_resp_ready
);
    assign table_write=1'b0;assign table_address=11'd0;assign table_data=16'sd0;
    reg storage_was_ready;
    always @(posedge clk)if(!rst_n)storage_was_ready<=0;else storage_was_ready<=storage_ready;
    reg arrangement_version,staged_song;
    reg [15:0] staged_base;reg [7:0] staged_pages;
    reg [16:0] staged_size;reg [31:0] staged_duration,staged_revision;
    reg song_ready[0:0];reg [7:0] pages[0:0];reg [15:0] bases[0:0];
    function automatic arrangement_timbre_valid(input [7:0] v);
        arrangement_timbre_valid=v==10||v==19||v==20;
    endfunction
    reg song_data_ready[0:0];reg validation_seen;reg [31:0] validation_timer;
    reg [63:0] query_map;reg [255:0] query_gains;reg [127:0] query_timbres,query_volumes;reg [15:0] query_mutes,query_solos;
    reg [4:0] state;
    reg [7:0] request_type;
    // Freeze all fields of a status reply at one edge before the wide reply mux.
    // This breaks live control/panic decode -> status -> response_payload paths.
    reg [223:0] reply_status;
    reg [175:0] reply_runtime;
    reg [111:0] reply_feedback;
    reg [47:0] reply_envelope;
    (* syn_keep=1 *) wire status_snapshot_enable=state==13 && (request_type==8'h36 || request_type==8'h37);
    always @(posedge clk)if(status_snapshot_enable)begin
        reply_status<=status_data;reply_runtime<=runtime_data;
        reply_feedback<=command_feedback;reply_envelope<=envelope_read_data;
    end
    (* syn_keep=1 *) wire query_snapshot_enable=state==0;
    always @(posedge clk)if(query_snapshot_enable)begin
        query_map<=channel_map;query_gains<=track_gains;query_timbres<=track_timbres;
        query_volumes<=track_volumes;query_mutes<=track_mutes;query_solos<=track_solos;
    end
    reg header_repeat_q,header_conflict_q,header_oversize_q;reg uploading;reg [1:0] kind;reg [3:0] slot;
    reg [31:0] expected_size,expected_crc,received,crc;reg [15:0] base,allocated;
    reg [16:0] sizes[0:0];reg [31:0] duration[0:0];reg [5:0] sections[0:0];
    reg [31:0] revisions[0:0];
    // 每资源64字节：UUID[0..15]、GB2312名称[16..47]。两份镜像分别服务USB和屏幕读口。
    // 按字节写入SDPB，避免384位宽异步读表形成大规模寄存器和多路选择器。
    reg metadata_write;reg [10:0] metadata_write_address,metadata_read_address,screen_read_address;
    // 元数据RAM为2KiB，原来只用768B；高位增加四首歌曲的影子页，不增加RAM块。
    reg [3:0] song_metadata_versions;
    function automatic [10:0] metadata_address(input [3:0] resource_slot,input [5:0] byte_index,input writing);
        reg version_bit;
        begin
            version_bit=resource_slot<4 ? song_metadata_versions[resource_slot[1:0]]:1'b0;
            if(writing && resource_slot<4)version_bit=~version_bit;
            metadata_address={version_bit,resource_slot,byte_index};
        end
    endfunction
    reg metadata_store;reg [7:0] metadata_write_data;wire [31:0] metadata_host_word;
    wire metadata_host_read=(state==7&&!metadata_store)||state==10;
    wire [10:0] shared_metadata_read_address=metadata_host_read ? metadata_read_address:screen_read_address;
    wire [31:0] metadata_screen_word=metadata_host_word;
    SDPB #(.READ_MODE(1'b0),.BIT_WIDTH_0(8),.BIT_WIDTH_1(8),.BLK_SEL_0(3'd0),.BLK_SEL_1(3'd0),.RESET_MODE("SYNC")) metadata_host(
        .DO(metadata_host_word),.DI({24'd0,metadata_write_data}),.BLKSELA(3'd0),.BLKSELB(3'd0),
        .ADA({metadata_write_address,3'd0}),.ADB({shared_metadata_read_address,3'd0}),
        .CLKA(clk),.CLKB(clk),.CEA(metadata_write),.CEB(1'b1),.OCE(1'b1),.RESET(1'b0));
    reg [3:0] screen_loaded_index;reg [31:0] screen_loaded_revision;
    reg [5:0] screen_name_index;reg [1:0] screen_read_phase;reg [255:0] screen_name_buffer;
    always @(posedge clk) begin
        if(!rst_n) begin
            catalog_name<=0;screen_loaded_index<=15;screen_loaded_revision<=0;
            screen_name_index<=0;screen_read_phase<=0;screen_read_address<=0;screen_name_buffer<=0;
        end else if(catalog_index!=screen_loaded_index || directory_revision!=screen_loaded_revision) begin
            screen_loaded_index<=catalog_index;screen_loaded_revision<=directory_revision;
            screen_name_index<=0;screen_read_phase<=0;screen_name_buffer<=0;catalog_name<=0;
        end else if(metadata_host_read)begin
            // 主机读期间冻结屏幕字节索引，重新从地址阶段启动，禁止采入主机返回字节。
            screen_read_phase<=0;
        end else if(screen_name_index<32) begin
            case(screen_read_phase)
                0:begin screen_read_address<=metadata_address(catalog_index,6'd16+screen_name_index,1'b0);screen_read_phase<=1;end
                1:screen_read_phase<=2;
                2:begin
                    screen_name_buffer[screen_name_index*8+:8]<=metadata_screen_word[7:0];
                    if(screen_name_index==31) catalog_name<=catalog_ready ? {metadata_screen_word[7:0],screen_name_buffer[247:0]}:256'd0;
                    screen_name_index<=screen_name_index+1'b1;screen_read_phase<=0;
                end
                default:screen_read_phase<=0;
            endcase
        end
    end
    reg [47:0] piano_envelope;
    assign envelope_read_data=envelope_read_bank==10 ? piano_envelope:48'd0;
    wire [159:0] published_arrangement;wire published_busy,published_valid;
    wire [159:0] staged_arrangement;wire staged_busy,staged_valid;
    reg [191:0] staged_arrangement_read;
    reg ram_write;reg [15:0] ram_write_address;reg [7:0] ram_write_data;
    reg store_load_stage,store_load_active,store_commit,store_begin;
    wire store_byte_ready,store_done,store_error,store_loading;
    workstation_song_store memory(.clk(clk),.rst_n(rst_n),.storage_ready(storage_ready),
        .upload_begin(store_begin),.byte_valid(ram_write),.byte_ready(store_byte_ready),
        .byte_address(ram_write_address),.byte_data(ram_write_data),
        .load_stage(store_load_stage),.load_active(store_load_active),.commit_stage(store_commit),
        .load_done(store_done),.load_error(store_error),.loading(store_loading),
        .read_address(song_read_address),.read_data(song_read_data),
        .req_valid(ddr_req_valid),.req_ready(ddr_req_ready),.req_write(ddr_req_write),
        .req_address(ddr_req_address),.req_data(ddr_req_data),.req_mask(ddr_req_mask),
        .resp_valid(ddr_resp_valid),.resp_error(ddr_resp_error),.resp_data(ddr_resp_data),.resp_ready(ddr_resp_ready));
    assign remote_idle=state==0 && !uploading && !staged_song && !store_loading && !validation_busy && !response_valid;
    assign selected_size=state==9 ? expected_size[16:0]:sizes[0];assign selected_ready=storage_ready&&song_ready[0]&&!uploading&&!staged_song&&!store_loading&&state!=9&&state!=14&&state!=15&&state!=16;
    assign selected_duration=duration[0];assign selected_sections=sections[0];
    assign song_ready_mask={31'd0,selected_ready};
    assign patch_ready_mask=8'd0;
    always @(*) section_data={32'd0,published_arrangement};
    always @(*) begin
        catalog_ready=0;catalog_duration=0;catalog_sections=0;
        if(catalog_index==0) begin catalog_ready=song_ready[0];catalog_duration=duration[0];catalog_sections=sections[0];end
    end
    function automatic [31:0] crc_next(input [31:0] crc,input [7:0] b);
        reg [31:0] c;integer j;
        begin c=crc^{24'd0,b};for(j=0;j<8;j=j+1)c=c[0] ? (c>>1)^32'hedb88320 : c>>1;crc_next=c;end
    endfunction
    reg [255:0] pending_name;reg [127:0] pending_id;reg [31:0] pending_revision,pending_duration;
    reg [7:0] chunk_size,index;
    // DATA头检查、末地址计算和边界比较分拍，避免长度减法/加法/比较串入状态使能。
    reg data_header_invalid_q;reg [7:0] data_chunk_q;reg [32:0] data_end_q;
    reg [7:0] low_byte;reg [31:0] header_magic;
    reg [191:0] section_buffer;reg [4:0] section_byte;reg [5:0] section_slot;
    reg [31:0] previous_section_end;reg section_invalid;
    reg [31:0] snapshot_counter;
    reg [15:0] request_seq,last_seq;reg [7:0] last_length;
    reg [767:0] last_response;reg last_valid;
    reg [7:0] last_type;reg [15:0] last_request_length,request_length;
    // 单个2KiB RAM保存最后一次完整请求；只有完整内容相等才复用原ACK。
    // 新请求缓存写完后再解码；DATA也从此RAM按字节消费，取消1024位移位链。
    reg replay_check,replay_mismatch,cache_response;
    reg [7:0] replay_index,replay_byte_q;reg replay_last_q;reg [1:0] replay_phase,byte_phase;
    wire [7:0] request_read_index=state==1 ? index+8'd4:replay_index;
    wire [31:0] request_word;
    wire request_write=rst_n && state==12 && !replay_check && replay_phase==1;
    SDPB #(.READ_MODE(1'b0),.BIT_WIDTH_0(8),.BIT_WIDTH_1(8),.BLK_SEL_0(3'd0),.BLK_SEL_1(3'd0),.RESET_MODE("SYNC")) request_cache(
        .DO(request_word),.DI({24'd0,replay_byte_q}),.BLKSELA(3'd0),.BLKSELB(3'd0),
        .ADA({3'd0,replay_index,3'd0}),.ADB({3'd0,request_read_index,3'd0}),
        .CLKA(clk),.CLKB(clk),.CEA(request_write),.CEB(1'b1),.OCE(1'b1),.RESET(1'b0));
    reg metadata_available;reg [3:0] metadata_slot;reg [5:0] metadata_index;reg [1:0] metadata_phase;
    // 元数据同步读至少等待两拍；在等待拍形成终点/下标，避免索引直接绕回自身CE。
    reg metadata_read_last_q,metadata_uuid_last_q,metadata_section_last_q;
    reg [5:0] metadata_next_q;
    reg demo_request_ok_q;reg [1:0] demo_group_q;
    always @(posedge clk)begin
        metadata_read_last_q<=metadata_index==47;
        metadata_uuid_last_q<=metadata_index==15;
        metadata_section_last_q<=metadata_index+1==section_slot;
        metadata_next_q<=metadata_index+1'b1;
    end
    always @(*) staged_arrangement_read={32'd0,staged_arrangement};
    (* syn_keep=1 *) wire reply_cache_enable=rst_n&&!(storage_was_ready&&!storage_ready)&&
        !(ENABLE_EMERGENCY&&emergency_abort)&&state==3&&!response_busy&&cache_response;
    always @(posedge clk)begin
        if(!rst_n)begin last_response<=0;last_seq<=0;last_length<=0;last_type<=0;last_request_length<=0;end
        else if(reply_cache_enable)begin
            last_response<=response_payload;last_seq<=response_seq;last_length<=response_length;
            last_type<=request_type;last_request_length<=request_length;
        end
    end
    integer i,candidate;reg [7:0] occupied;reg [7:0] result;
    // BEGIN最多检查16个起点；只有找到连续空页后才改变目录，响应允许增加16拍。
    reg [7:0] allocation_occupied,allocation_mask;
    reg [4:0] allocation_index,allocation_need;
    wire [4:0] request_pages={1'b0,payload[31:28]}+{4'd0,(|payload[27:16])};
    wire [7:0] byte_data=request_word[7:0];
    packed_table_sp32 #(.WIDTH(160),.ADDRESS_WIDTH(6)) published_table(.clk(clk),.rst_n(rst_n),
        .write_enable(state==8&&metadata_phase==2),.write_address({~arrangement_version,metadata_index[4:0]}),.read_address({arrangement_version,section_read_address[4:0]}),
        .write_data(staged_arrangement),.read_data(published_arrangement),.read_valid(published_valid),.write_busy(published_busy),.overflow());
    packed_table_sp32 #(.WIDTH(160),.ADDRESS_WIDTH(5)) staged_table(.clk(clk),.rst_n(rst_n),
        .write_enable(state==1&&kind==2&&section_byte==23),.write_address(section_slot[4:0]),.read_address(metadata_index[4:0]),
        .write_data(section_buffer[159:0]),.read_data(staged_arrangement),.read_valid(staged_valid),.write_busy(staged_busy),.overflow());
    task finish(input [7:0] code,input [7:0] count);
        begin response_payload[7:0]<=request_type;response_payload[15:8]<=code;
            response_length<=count;response_seq<=request_seq;state<=3;end
    endtask
    always @(posedge clk) begin
        store_load_stage<=0;store_load_active<=0;store_commit<=0;store_begin<=0;
        response_valid<=0;control_valid<=0;parameter_write<=0;ram_write<=0;external_adsr_done<=0;metadata_write<=0;validation_start<=0;validation_release<=0;
        if(!rst_n) begin
            // [1:0]灵敏度移位，[3:2]曲线，[10:4]最低力度。默认2倍/轻触/16。
            // 与0x3F写入同属本时序块，禁止在屏幕目录线程再驱动此寄存器。
            pressure_touch_settings<=11'd261;
            arrangement_version<=0;staged_song<=0;staged_base<=0;staged_pages<=0;
            staged_size<=0;staged_duration<=0;staged_revision<=0;
            state<=0;header_repeat_q<=0;header_conflict_q<=0;header_oversize_q<=0;uploading<=0;received<=0;crc<=32'hffffffff;last_valid<=0;request_length<=0;replay_check<=0;replay_mismatch<=0;cache_response<=0;replay_index<=0;replay_phase<=0;byte_phase<=0;replay_byte_q<=0;replay_last_q<=0;
            external_adsr_result<=0;data_header_invalid_q<=0;data_chunk_q<=0;data_end_q<=0;
            validation_start<=0;validation_release<=0;validation_seen<=0;validation_timer<=0;
            previous_section_end<=0;section_invalid<=0;snapshot_counter<=0;
            allocation_occupied<=0;allocation_mask<=0;allocation_index<=0;allocation_need<=0;
            metadata_write_address<=0;metadata_read_address<=0;metadata_write_data<=0;song_metadata_versions<=0;
            metadata_store<=0;metadata_slot<=0;metadata_index<=0;metadata_phase<=0;metadata_available<=0;
            response_payload<=0;response_seq<=0;response_length<=0;directory_revision<=0;
            control_op<=0;control_value<=0;control_aux<=0;
            parameter_bank<=0;envelope_parameters<=0;base<=0;allocated<=0;kind<=0;slot<=0;
            expected_size<=0;expected_crc<=0;pending_name<=0;pending_id<=0;pending_revision<=0;pending_duration<=0;
            ram_write_address<=0;ram_write_data<=0;chunk_size<=0;index<=0;low_byte<=0;header_magic<=0;
            section_buffer<=0;section_byte<=0;section_slot<=0;request_seq<=0;request_type<=0;
            for(i=0;i<1;i=i+1) begin song_ready[i]<=0;song_data_ready[i]<=0;pages[i]<=0;bases[i]<=0;sizes[i]<=0;duration[i]<=0;sections[i]<=0;end
            revisions[0]<=0;
            piano_envelope<={12'd32,12'd3072,12'd8,12'd64};
        end else begin
        // 所有ADSR操作经过同一仲裁入口；USB等待CONTROL完成时也能接受参数写入。
        if(external_adsr_valid) begin
            external_adsr_done<=1;external_adsr_result<=0;
            if(uploading || (state!=0 && state!=2) || frame_valid || external_adsr_value[3:0]!=10 ||
                external_adsr_value[15:4]==0 || external_adsr_value[27:16]==0 || external_adsr_aux[23:12]==0) external_adsr_result<=4;
            else begin
                parameter_bank<=external_adsr_value[3:0];parameter_write<=1;
                envelope_parameters<={external_adsr_aux[23:12],external_adsr_aux[11:0],external_adsr_value[27:16],external_adsr_value[15:4]};
                piano_envelope<={external_adsr_aux[23:12],external_adsr_aux[11:0],external_adsr_value[27:16],external_adsr_value[15:4]};
                directory_revision<=directory_revision+1'b1;
            end
        end
        // 紧急取消优先于DATA写入、解析完成和目录发布，未完成资源不得继续变为ready。
        if(storage_was_ready&&!storage_ready)begin
            state<=0;uploading<=0;staged_song<=0;song_ready[0]<=0;song_data_ready[0]<=0;
            validation_release<=1;last_valid<=0;
        end else if(ENABLE_EMERGENCY && emergency_abort) begin
            state<=0;uploading<=0;staged_song<=0;last_valid<=0;metadata_store<=0;validation_release<=1;
            if(uploading || state==9 || (state==7 && metadata_store) || state==8 || state==10) begin
                // 曲谱暂存页不在pages目录内；取消只丢弃暂存状态，旧页与ready保持。
            end
        end else case(state)
            0:if(frame_valid && !response_busy) begin
                request_seq<=frame_seq;request_type<=frame_type;request_length<=frame_length;
                response_payload<=0;cache_response<=1;replay_index<=0;replay_phase<=0;replay_mismatch<=0;
                // 先寄存请求头判定，下一拍再选择宽响应缓存，避免last_type驱动宽CE。
                header_repeat_q<=last_valid&&frame_seq==last_seq;
                header_conflict_q<=frame_type!=last_type||frame_length!=last_request_length;
                header_oversize_q<=frame_length>132;
                state<=20;
            end
            20:begin
                if(header_oversize_q)begin response_payload[15:8]<=1;cache_response<=0;state<=6;end
                else if(header_repeat_q)begin
                    cache_response<=0;
                    if(header_conflict_q)begin response_payload[15:8]<=7;state<=6;end
                    else if(request_length==0)begin response_payload<=last_response;response_seq<=last_seq;response_length<=last_length;state<=4;end
                    else begin replay_check<=1;state<=12;end
                end else begin replay_check<=0;state<=request_length==0 ? 13:12;end
            end

            // BEGIN资格已在上一拍确认，本拍无条件保存元数据；CRC/回滚/UUID契约不变。
            19:begin
                            uploading<=1;kind<={payload[1],1'b0};slot<=payload[11:8];expected_size<=payload[47:16];expected_crc<=payload[79:48];
                            pending_id<=payload[207:80];pending_revision<=payload[239:208];pending_name<=payload[495:240];
                            pending_duration<=payload[527:496];
                            received<=0;crc<=32'hffffffff;header_magic<=0;section_buffer<=0;section_byte<=0;section_slot<=0;
                            previous_section_end<=0;section_invalid<=0;
                            if(payload[7:0]==0) begin
                                staged_song<=0;store_begin<=1;
                                allocation_occupied<=0;allocation_index<=0;
                                // 总池32KiB包含当前曲和暂存曲；没有空页时拒绝，不能覆盖旧曲。
                                allocation_need<=request_pages;
                                allocation_mask<=8'hff >> (8-request_pages);
                            end
                if(payload[7:0]==2)begin
                    metadata_slot<=payload[11:8];metadata_index<=0;metadata_phase<=0;state<=10;
                end else state<=11;
            end
            13:begin
                case(request_type)
                    8'h01:begin response_payload[47:16]<=payload[31:0];state<=6;end
                    8'h3d:begin
                        response_length<=16;response_payload[15:8]<=request_length==0 ? 0:1;
                        response_payload[31:16]<=16'h0301;
                        response_payload[127:32]<=damping_settings;state<=6;
                    end
                    8'h3e:begin
                        response_payload[15:8]<=request_length==0 ? 0:1;
                        response_payload[31:16]<=16'h0101;
                        response_payload[63:32]<={30'd0,velocity_tone_setting};state<=6;
                    end
                    8'h3f:begin
                        // 独立PKEY/v1接口：空请求读；写入为版本/移位/曲线/最低力度四字节。
                        // 配置在同一拍原子更新，不改变声音身份或触发新起音；复位恢复默认。
                        response_payload[23:16]<=8'd1;
                        response_payload[31:24]<={6'd0,pressure_touch_settings[1:0]};
                        response_payload[39:32]<={6'd0,pressure_touch_settings[3:2]};
                        response_payload[47:40]<={1'b0,pressure_touch_settings[10:4]};
                        response_payload[79:48]<=hardware_status[47:16];
                        if(request_length!=0)begin
                            if(request_length!=4||payload[7:0]!=1||payload[15:8]>3||
                               payload[23:16]>2||payload[31:24]<8||payload[31:24]>64)
                                response_payload[15:8]<=1;
                            else begin
                                pressure_touch_settings<={payload[30:24],payload[17:16],payload[9:8]};
                                response_payload[47:24]<=payload[31:8];
                            end
                        end
                        state<=6;
                    end
                    8'h30:begin
                        response_payload[47:16]<=BUILTIN_PIANO ? 32'h33565357:32'h32565357; // WSV3 / WSV2
                        response_payload[79:48]<={8'd32,8'd0,8'd1,8'd3};
                        response_payload[111:80]<=32768;response_payload[127:112]<=2048;state<=6;
                        response_payload[143:128]<=ENABLE_EMERGENCY ? 16'h00cf:16'h00cb; // bit7=混音总线52；bit2=独立紧急通路
                        if(BUILTIN_PIANO)begin
                            response_payload[175:144]<=48000;response_payload[191:176]<=4;
                            response_payload[199:192]<=16;response_payload[207:200]<=3;
                            response_payload[215:208]<=21;response_payload[223:216]<=108;response_payload[239:224]<=3;
                        end
                    end
                    8'h31:begin
                        result=0;candidate=0;
                        if(request_length!=2 || payload[7:0]!=0 || payload[15:8]!=0) result=1;
                        else begin
                            response_payload[31:16]<=payload[15:0];
                            response_payload[39:32]<={7'd0,song_ready[0]};
                            response_payload[79:48]<=revisions[0];
                            response_payload[495:464]<=1'b1 ? {15'd0,sizes[0]} : 32'd512;
                            response_payload[527:496]<=1'b1 ? duration[0] : 0;
                            response_payload[535:528]<=1'b1 ? {2'd0,sections[0]} : 0;
                            if(candidate>=4) begin
                                response_payload[559:544]<={4'd0,piano_envelope[11:0]};
                                response_payload[575:560]<={4'd0,piano_envelope[23:12]};
                                response_payload[591:576]<={4'd0,piano_envelope[35:24]};
                                response_payload[607:592]<={4'd0,piano_envelope[47:36]};
                            end
                        end
                        response_payload[15:8]<=result;
                        if(result==0) begin
                            metadata_store<=0;metadata_slot<=4'(candidate);metadata_index<=0;metadata_phase<=0;
                            metadata_available<=song_ready[0];state<=7;
                        end else state<=6;
                    end
                    8'h32:begin
                        result=0;occupied=0;
                        occupied=pages[0];
                        if(!storage_ready || request_length!=74 || (payload[7:0]!=0 && payload[7:0]!=2) || payload[47:16]==0 || status_data[8] || status_data[9] ||
                            (payload[7:0]==0 && (payload[15:8]!=0 || payload[47:16]>32768)) ||
                            (payload[7:0]==2 && (payload[15:8]!=0 || payload[47:16]>768 || (!song_data_ready[0]&&!staged_song) ||
                                (staged_song ? staged_revision:revisions[0])!=payload[239:208]))) result=1;
                        response_payload[15:8]<=(status_data[8]||status_data[9]) ? 8'd4:(payload[7:0]==1 || payload[7:0]==3) ? 8'h7f:result;
                        if(result==0)state<=19;else state<=6;
                    end
                    8'h33:begin
                        data_header_invalid_q<=!uploading || request_length<5 || request_length>132 || payload[31:0]!=received;
                        data_chunk_q<=request_length[7:0]-8'd4;
                        state<=22;
                    end
                    8'h34:begin
                        result=0;
                        if(!uploading || request_length!=4 || received!=expected_size || payload[31:0]!=expected_crc || (crc^32'hffffffff)!=expected_crc ||
                            (kind==0 && header_magic!=32'h6468544d) ||
                            (kind==2 && (section_byte!=0 || section_invalid || section_slot==0 || previous_section_end<(staged_song ? staged_duration:duration[0])))) result=3;
                        else if(kind==0) begin
                            // CRC通过后仍须完成MIDI结构校验；不提前改变已发布描述符。
                        end
                        uploading<=0;response_payload[15:8]<=result;
                if(result==0 && kind==0) begin
                            state<=17;
                        end else if(result==0 && kind!=2) begin
                            metadata_store<=1;metadata_slot<=kind==0 ? slot:slot+4;metadata_index<=0;metadata_phase<=0;state<=7;
                        end else if(result==0 && kind==2) begin metadata_index<=0;metadata_phase<=0;state<=8;end
                        else if(staged_song)begin store_load_active<=1;staged_song<=0;state<=15;end
                        else state<=6;
                    end
                    8'h35:begin
                        if(request_length!=9 || uploading) begin response_payload[15:8]<=4;state<=6;end
                        else begin control_op<=payload[7:0];control_value<=payload[39:8];control_aux<=payload[71:40];control_valid<=1;state<=2;end
                    end
                    8'h38:begin
                        if(request_length!=1 || payload[7:0]!=0 || uploading || status_data[8] || status_data[9] || validation_busy)
                            response_payload[15:8]<=4;
                        else begin song_ready[0]<=0;song_data_ready[0]<=0;staged_song<=0;
                            pages[0]<=0;sizes[0]<=0;sections[0]<=0;duration[0]<=0;
                            directory_revision<=directory_revision+1'b1;end
                        state<=6;
                    end
                    8'h36:state<=28;
                    8'h3a:begin
                        if(request_length!=0)response_payload[15:8]<=1;
                        else response_payload[415:16]<=hardware_status;
                        state<=6;
                    end
                    // 扩展快照版本2：16轨独立配置，旧0x37快照保持布局不变。
                    8'h3c:begin
                        if(request_length!=0)response_payload[15:8]<=1;
                        else begin response_payload[23:16]<=1;response_payload[31:24]<=0;response_payload[95:32]<=chord_status;end
                        state<=6;
                    end
                    8'h40:begin
                        // 请求资格先寄存，再选择512位回包；只增加控制面一拍，不改变协议。
                        demo_request_ok_q<=request_length==2&&payload[7:0]==1&&payload[15:8]<=3;
                        demo_group_q<=payload[9:8];state<=29;
                    end
                    8'h39:begin
                        state<=21;
                    end
                    8'h37:state<=28;
                    default:begin response_payload[15:8]<=8'h7f;state<=6;end
                endcase
            end
            29:begin
                        // v1分组整包：头8字节+64字节状态。旧0x3A/0x3C/0x3F布局保持。
                        if(!demo_request_ok_q)response_payload[15:8]<=1;
                        else begin
                            response_payload[23:16]<=1;response_payload[31:24]<={6'd0,demo_group_q};
                            response_payload[63:32]<=hardware_status[47:16];
                            case(demo_group_q)
                                0:response_payload[575:64]<=demo_fx_status;
                                1:response_payload[575:64]<=demo_audio_status;
                                2:response_payload[575:64]<={384'd0,demo_note_status};
                                3:response_payload[575:64]<={256'd0,demo_lesson_status};
                            endcase
                        end
                        state<=6;
            end
            1:begin
                if(byte_phase!=2)byte_phase<=byte_phase+1'b1;
                else if(kind!=0||store_byte_ready)begin
                byte_phase<=0;
                crc<=crc_next(crc,byte_data);
                if(received<4) header_magic[received*8+:8]<=byte_data;
                if(kind==0) begin ram_write<=1;ram_write_address<=16'(received);ram_write_data<=byte_data;end
                                else begin
                    section_buffer[section_byte*8+:8]<=byte_data;
                    if(section_byte==23) begin
                        if(section_buffer[31:0]!=previous_section_end || section_buffer[63:32]<=section_buffer[31:0] ||
                           !arrangement_timbre_valid(section_buffer[151:144]) ||
                           $signed(section_buffer[159:152])>24 || $signed(section_buffer[159:152])< -24 ||
                           section_buffer[135:132]!=0 || section_buffer[143:140]!=0 || byte_data!=0 || section_buffer[183:160]!=0) section_invalid<=1;
                        for(i=0;i<4;i=i+1) begin
                            if(!arrangement_timbre_valid(section_buffer[64+i*8+:8]) || section_buffer[96+i*8+:8]>100) section_invalid<=1;
                        end
                        previous_section_end<=section_buffer[63:32];
                        section_byte<=0;section_slot<=section_slot+1'b1;
                    end else section_byte<=section_byte+1'b1;
                end
                received<=received+1'b1;
                if(index+1==chunk_size) state<=kind==0 ? 18:6;else index<=index+1'b1;
                end
            end
            21:begin
                response_payload[23:16]<=2;response_payload[31:24]<=16;
                response_payload[95:32]<=query_map;response_payload[351:96]<=query_gains;
                response_payload[479:352]<=query_timbres;response_payload[607:480]<=query_volumes;
                response_payload[623:608]<=query_mutes;response_payload[639:624]<=query_solos;state<=6;
            end
            28:begin
                if(request_type==8'h36)response_payload[239:16]<=reply_status;
                else begin
                    response_payload[23:16]<=1;response_payload[31:24]<=reply_feedback[7:0];response_payload[39:32]<=reply_feedback[15:8];
                    response_payload[79:48]<=reply_feedback[47:16];response_payload[303:80]<=reply_status;response_payload[479:304]<=reply_runtime;
                    response_payload[495:480]<={4'd0,reply_envelope[11:0]};response_payload[511:496]<={4'd0,reply_envelope[23:12]};
                    response_payload[527:512]<={4'd0,reply_envelope[35:24]};response_payload[543:528]<={4'd0,reply_envelope[47:36]};
                    response_payload[575:544]<=snapshot_counter;snapshot_counter<=snapshot_counter+1'b1;
                    response_payload[607:576]<=reply_feedback[79:48];response_payload[639:608]<=reply_feedback[111:80];
                end
                state<=6;
            end
            2:if(control_done) begin response_payload[15:8]<=control_result;state<=6;end
            6:begin
                response_payload[7:0]<=request_type;response_seq<=request_seq;
                response_length<=request_type==8'h30 ? (BUILTIN_PIANO ? 30:18) : request_type==8'h31 ? 76 : request_type==8'h36 ? 30 : request_type==8'h3a ? 52 : request_type==8'h3c ? 12 : request_type==8'h3d ? 16 : request_type==8'h3e ? 8 : request_type==8'h3f ? 10 : request_type==8'h40 ? 72 : (request_type==8'h37||request_type==8'h39) ? 80 : request_type==1 ? 6 : 2;
                state<=3;
            end
            3:if(!response_busy) begin
                if(cache_response)begin
                    last_valid<=1;
                end
                state<=4;
            end
            4:if(!response_busy) begin response_valid<=1;state<=5;end
            5:if(response_busy) state<=0;
            7:begin
                if(metadata_store) begin
                    if(metadata_index<48) begin
                        metadata_write<=1;metadata_write_address<=metadata_address(metadata_slot,metadata_index,1'b1);
                        metadata_write_data<=metadata_index<16 ? pending_id[7:0]:pending_name[7:0];
                        if(metadata_index<16) pending_id<=pending_id>>8;else pending_name<=pending_name>>8;
                        metadata_index<=metadata_index+1'b1;
                    end else begin
                        // 最后一个字节已在本拍落RAM，然后才公开ready和目录版本。
                        if(kind==0)begin
                            staged_pages<=allocated;staged_base<=base;staged_size<=expected_size[16:0];
                            staged_duration<=pending_duration;staged_revision<=pending_revision;staged_song<=1;
                        end
                        state<=6;
                    end
                end else case(metadata_phase)
                    0:begin metadata_read_address<=metadata_address(metadata_slot,metadata_index,1'b0);metadata_phase<=1;end
                    1:metadata_phase<=2;
                    2:begin
                        response_payload[80+metadata_index*8+:8]<=metadata_available ? metadata_host_word[7:0]:8'd0;
                        if(metadata_read_last_q) state<=6;else metadata_index<=metadata_next_q;
                        metadata_phase<=0;
                    end
                    default:metadata_phase<=0;
                endcase
            end
            // 配器暂存在独立RAM，CRC成功后才复制，失败不会破坏已发布歌曲的配器。
            8:case(metadata_phase)
                0:if(staged_valid&&!published_busy)metadata_phase<=1;
                1:metadata_phase<=2;
                2:metadata_phase<=3;
                3:if(!published_busy)begin
                    if(metadata_section_last_q)begin
                        sections[0]<=section_slot;directory_revision<=directory_revision+1'b1;state<=6;
                        song_ready[0]<=1;arrangement_version<=~arrangement_version;
                        if(staged_song)begin
                            pages[0]<=staged_pages;bases[0]<=staged_base;sizes[0]<=staged_size;
                            duration[0]<=staged_duration;revisions[0]<=staged_revision;
                            song_metadata_versions[0]<=~song_metadata_versions[0];
                            song_data_ready[0]<=1;staged_song<=0;store_commit<=1;
                        end
                    end else metadata_index<=metadata_next_q;
                    metadata_phase<=0;
                end
            endcase
            9:begin
                validation_timer<=validation_timer+1'b1;
                if(validation_busy) validation_seen<=1;
                if((validation_seen && validation_error) || validation_timer==32'd100000000 ||
                   (validation_seen && validation_done && !validation_busy && pending_duration<validation_duration)) begin
                    validation_release<=1;response_payload[15:8]<=5;store_load_active<=1;staged_song<=0;state<=15;
                end else if(validation_seen && validation_done && !validation_busy) begin
                    validation_release<=1;metadata_store<=1;metadata_slot<=slot;metadata_index<=0;metadata_phase<=0;state<=7;
                end
            end
            18:if(store_byte_ready&&!ram_write)begin
                if(store_error)response_payload[15:8]<=8;
                state<=6;
            end
            17:if(store_byte_ready)begin store_load_stage<=1;state<=14;end
            14:if(store_done)begin
                if(store_error)begin response_payload[15:8]<=8;store_load_active<=1;state<=15;end
                else begin validation_start<=1;validation_seen<=0;validation_timer<=0;state<=9;end
            end
            15:if(store_done)begin
                if(store_error||!song_ready[0])begin song_ready[0]<=0;validation_release<=1;state<=6;end
                else begin validation_start<=1;validation_seen<=0;validation_timer<=0;state<=16;end
            end
            16:begin
                validation_timer<=validation_timer+1'b1;
                if(validation_busy)validation_seen<=1;
                if(validation_seen&&!validation_busy&&(validation_done||validation_error))begin
                    if(validation_error)song_ready[0]<=0;
                    state<=6;
                end else if(validation_timer==100000000)begin song_ready[0]<=0;validation_release<=1;state<=6;end
            end
            10:case(metadata_phase)
                0:begin metadata_read_address<=metadata_address(metadata_slot,metadata_index,staged_song);metadata_phase<=1;end
                1:metadata_phase<=2;
                2:begin
                    if(metadata_host_word[7:0]!=pending_id[metadata_index*8+:8]) begin uploading<=0;response_payload[15:8]<=6;state<=6;end
                    else if(metadata_uuid_last_q) state<=6;
                    else metadata_index<=metadata_next_q;
                    metadata_phase<=0;
                end
                default:metadata_phase<=0;
            endcase
            11:begin base<=0;allocated<=8'hff;state<=6;end
            22:begin
                // 保留进位；越界或32位回绕都拒绝，不改变合法DATA及重试的ACK含义。
                data_end_q<={1'b0,received}+{25'd0,data_chunk_q};state<=23;
            end
            23:begin
                if(data_header_invalid_q || data_end_q>{1'b0,expected_size})begin
                    response_payload[15:8]<=2;state<=6;
                end else begin byte_phase<=0;chunk_size<=data_chunk_q;index<=0;state<=1;end
            end
            12:begin
                // 索引读取、RAM等待、比较、分支四拍分离；注册结果后才使能宽响应寄存器。
                case(replay_phase)
                    0:begin replay_byte_q<=payload[replay_index*8+:8];replay_phase<=1;end
                    1:replay_phase<=2;
                    2:begin
                        if(replay_check&&request_word[7:0]!=replay_byte_q)replay_mismatch<=1;
                        replay_last_q<=({8'd0,replay_index}+16'd1==request_length);
                        replay_phase<=3;
                    end
                    3:begin
                        replay_phase<=0;
                        if(replay_last_q)begin
                            if(!replay_check)state<=13;
                            else if(replay_mismatch)begin response_payload[15:8]<=7;state<=6;end
                            else begin response_payload<=last_response;response_seq<=last_seq;response_length<=last_length;state<=4;end
                        end else replay_index<=replay_index+1'b1;
                    end
                endcase
            end
            default:state<=0;
        endcase
        end
    end
endmodule
`default_nettype wire
