`default_nettype none
// V2资源事务：4首歌曲共享16个4KiB页；8个波表槽；每首32项24字节配器。
// 数据块全部落RAM后ACK，同序号重试只重发响应；CRC32通过才发布目录。
module workstation_v2_resources #(parameter ENABLE_EMERGENCY=0)(
    input wire clk,rst_n,
    input wire frame_valid,input wire [7:0] frame_type,input wire [15:0] frame_seq,frame_length,
    input wire [1055:0] payload,
    output reg response_valid,output reg [15:0] response_seq,output reg [7:0] response_length,
    output reg [767:0] response_payload,input wire response_busy,
    output reg control_valid,output reg [7:0] control_op,output reg [31:0] control_value,control_aux,
    input wire control_done,input wire [7:0] control_result,
    input wire [223:0] status_data,
    input wire [175:0] runtime_data,input wire [111:0] command_feedback,
    output reg validation_start,validation_release,input wire validation_done,validation_busy,validation_error,input wire [31:0] validation_duration,
    input wire [1:0] selected_song,input wire [15:0] song_read_address,output wire [7:0] song_read_data,
    output wire [16:0] selected_size,output wire selected_ready,output wire [31:0] selected_duration,
    output wire [31:0] song_ready_mask,output wire [7:0] patch_ready_mask,
    output reg table_write,output reg [10:0] table_address,output reg signed [15:0] table_data,
    output reg parameter_write,output reg [3:0] parameter_bank,
    output reg [47:0] envelope_parameters,
    input wire external_adsr_valid,input wire [31:0] external_adsr_value,external_adsr_aux,
    output reg external_adsr_done,output reg [7:0] external_adsr_result,
    input wire [3:0] envelope_read_bank,output wire [47:0] envelope_read_data,
    input wire [6:0] section_read_address,output reg [191:0] section_data,
    output wire [5:0] selected_sections,
    input wire [3:0] catalog_index,output reg [255:0] catalog_name,output reg catalog_ready,
    output reg [31:0] catalog_duration,output reg [5:0] catalog_sections,
    output reg [31:0] directory_revision,
    input wire emergency_abort
);
    reg song_ready[0:3],patch_ready[0:7];reg [15:0] pages[0:3];reg [15:0] bases[0:3];
    reg song_data_ready[0:3];reg validation_seen;reg [31:0] validation_timer;
    reg [3:0] state;reg uploading;reg [1:0] kind;reg [3:0] slot;
    reg [31:0] expected_size,expected_crc,received,crc;reg [15:0] base,allocated;
    reg [16:0] sizes[0:3];reg [31:0] duration[0:3];reg [5:0] sections[0:3];
    reg [31:0] revisions[0:11];
    // 每资源64字节：UUID[0..15]、GB2312名称[16..47]。两份镜像分别服务USB和屏幕读口。
    // 按字节写入SDPB，避免384位宽异步读表形成大规模寄存器和多路选择器。
    reg metadata_write;reg [9:0] metadata_write_address,metadata_read_address,screen_read_address;
    reg [7:0] metadata_write_data;wire [31:0] metadata_host_word,metadata_screen_word;
    SDPB #(.READ_MODE(1'b0),.BIT_WIDTH_0(8),.BIT_WIDTH_1(8),.BLK_SEL_0(3'd0),.BLK_SEL_1(3'd0),.RESET_MODE("SYNC")) metadata_host(
        .DO(metadata_host_word),.DI({24'd0,metadata_write_data}),.BLKSELA(3'd0),.BLKSELB(3'd0),
        .ADA({1'b0,metadata_write_address,3'd0}),.ADB({1'b0,metadata_read_address,3'd0}),
        .CLKA(clk),.CLKB(clk),.CEA(metadata_write),.CEB(1'b1),.OCE(1'b1),.RESET(1'b0));
    SDPB #(.READ_MODE(1'b0),.BIT_WIDTH_0(8),.BIT_WIDTH_1(8),.BLK_SEL_0(3'd0),.BLK_SEL_1(3'd0),.RESET_MODE("SYNC")) metadata_screen(
        .DO(metadata_screen_word),.DI({24'd0,metadata_write_data}),.BLKSELA(3'd0),.BLKSELB(3'd0),
        .ADA({1'b0,metadata_write_address,3'd0}),.ADB({1'b0,screen_read_address,3'd0}),
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
        end else if(screen_name_index<32) begin
            case(screen_read_phase)
                0:begin screen_read_address<={catalog_index,6'd16}+{4'd0,screen_name_index};screen_read_phase<=1;end
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
    reg [47:0] stored_envelopes[0:9];
    assign envelope_read_data=envelope_read_bank<10 ? stored_envelopes[envelope_read_bank]:48'd0;
    (* ram_style="block",syn_ramstyle="block_ram" *) reg [191:0] arrangements[0:127];
    (* ram_style="block",syn_ramstyle="block_ram" *) reg [191:0] staged_arrangements[0:31];
    reg [191:0] staged_arrangement_read;
    reg ram_write;reg [15:0] ram_write_address;reg [7:0] ram_write_data;
    midi_file_ram_sdp memory(.clk(clk),.write_enable(ram_write),.write_address(ram_write_address),
        .write_data(ram_write_data),.read_address((state==9 ? base:bases[selected_song])+song_read_address),.read_data(song_read_data));
    assign selected_size=state==9 ? expected_size[16:0]:sizes[selected_song];assign selected_ready=song_ready[selected_song];
    assign selected_duration=duration[selected_song];assign selected_sections=sections[selected_song];
    assign song_ready_mask={28'd0,song_ready[3],song_ready[2],song_ready[1],song_ready[0]};
    genvar g;generate for(g=0;g<8;g=g+1) begin:g_ready assign patch_ready_mask[g]=patch_ready[g];end endgenerate
    always @(posedge clk) section_data<=arrangements[section_read_address];
    always @(*) begin
        catalog_ready=0;catalog_duration=0;catalog_sections=0;
        if(catalog_index<12) begin
            if(catalog_index<4) begin catalog_ready=song_ready[catalog_index];catalog_duration=duration[catalog_index];catalog_sections=sections[catalog_index];end
            else catalog_ready=patch_ready[catalog_index-4];
        end
    end
    function automatic [31:0] crc_next(input [31:0] crc,input [7:0] b);
        reg [31:0] c;integer j;
        begin c=crc^{24'd0,b};for(j=0;j<8;j=j+1)c=c[0] ? (c>>1)^32'hedb88320 : c>>1;crc_next=c;end
    endfunction
    reg [255:0] pending_name;reg [127:0] pending_id;reg [31:0] pending_revision,pending_duration;
    reg [63:0] pending_adsr;reg [1023:0] chunk;reg [7:0] chunk_size,index;
    reg [7:0] low_byte;reg [31:0] header_magic;
    reg [191:0] section_buffer;reg [4:0] section_byte;reg [5:0] section_slot;
    reg [31:0] previous_section_end;reg section_invalid;
    reg [31:0] snapshot_counter;
    reg [15:0] request_seq,last_seq;reg [7:0] request_type,last_length;
    reg [767:0] last_response;reg last_valid;
    reg [7:0] last_type;reg [15:0] last_request_length;reg [31:0] request_first,last_first;
    reg metadata_store,metadata_available;reg [3:0] metadata_slot;reg [5:0] metadata_index;reg [1:0] metadata_phase;
    always @(posedge clk) staged_arrangement_read<=staged_arrangements[metadata_index[4:0]];
    integer i,k,candidate,need;reg [15:0] occupied,mask;reg [7:0] result;
    wire [7:0] byte_data=chunk[7:0];
    task finish(input [7:0] code,input [7:0] count);
        begin response_payload[7:0]<=request_type;response_payload[15:8]<=code;
            response_length<=count;response_seq<=request_seq;state<=3;end
    endtask
    always @(posedge clk) begin
        response_valid<=0;control_valid<=0;table_write<=0;parameter_write<=0;ram_write<=0;external_adsr_done<=0;metadata_write<=0;validation_start<=0;validation_release<=0;
        if(!rst_n) begin
            state<=0;uploading<=0;received<=0;crc<=32'hffffffff;last_valid<=0;last_type<=0;last_request_length<=0;request_first<=0;last_first<=0;
            external_adsr_result<=0;
            validation_start<=0;validation_release<=0;validation_seen<=0;validation_timer<=0;
            previous_section_end<=0;section_invalid<=0;snapshot_counter<=0;
            metadata_write_address<=0;metadata_read_address<=0;metadata_write_data<=0;
            metadata_store<=0;metadata_slot<=0;metadata_index<=0;metadata_phase<=0;metadata_available<=0;
            response_payload<=0;response_seq<=0;response_length<=0;directory_revision<=0;
            control_op<=0;control_value<=0;control_aux<=0;table_address<=0;table_data<=0;
            parameter_bank<=0;envelope_parameters<=0;base<=0;allocated<=0;kind<=0;slot<=0;
            expected_size<=0;expected_crc<=0;pending_name<=0;pending_id<=0;pending_revision<=0;pending_duration<=0;pending_adsr<=0;
            ram_write_address<=0;ram_write_data<=0;chunk<=0;chunk_size<=0;index<=0;low_byte<=0;header_magic<=0;
            section_buffer<=0;section_byte<=0;section_slot<=0;request_seq<=0;request_type<=0;last_seq<=0;last_length<=0;last_response<=0;
            for(i=0;i<4;i=i+1) begin song_ready[i]<=0;song_data_ready[i]<=0;pages[i]<=0;bases[i]<=0;sizes[i]<=0;duration[i]<=0;sections[i]<=0;end
            for(i=0;i<8;i=i+1) patch_ready[i]<=0;
            for(i=0;i<12;i=i+1) revisions[i]<=0;
            for(i=0;i<10;i=i+1) stored_envelopes[i]<={12'd32,12'd3072,12'd8,12'd64};
            stored_envelopes[0]<={12'd24,12'd1024,12'd5,12'd256};stored_envelopes[1]<={12'd12,12'd3500,12'd4,12'd16};
        end else begin
        // 所有ADSR操作经过同一仲裁入口；USB等待CONTROL完成时也能接受参数写入。
        if(external_adsr_valid) begin
            external_adsr_done<=1;external_adsr_result<=0;
            if(uploading || (state!=0 && state!=2) || frame_valid || external_adsr_value[3:0]>=10 ||
                external_adsr_value[15:4]==0 || external_adsr_value[27:16]==0 || external_adsr_aux[23:12]==0 ||
                (external_adsr_value[3:0]>=2 && !patch_ready[external_adsr_value[3:0]-2])) external_adsr_result<=4;
            else begin
                parameter_bank<=external_adsr_value[3:0];parameter_write<=1;
                envelope_parameters<={external_adsr_aux[23:12],external_adsr_aux[11:0],external_adsr_value[27:16],external_adsr_value[15:4]};
                stored_envelopes[external_adsr_value[3:0]]<={external_adsr_aux[23:12],external_adsr_aux[11:0],external_adsr_value[27:16],external_adsr_value[15:4]};
                if(external_adsr_value[3:0]>=2) revisions[external_adsr_value[3:0]+2]<=revisions[external_adsr_value[3:0]+2]+1'b1;
                directory_revision<=directory_revision+1'b1;
            end
        end
        // 紧急取消优先于DATA写入、解析完成和目录发布，未完成资源不得继续变为ready。
        if(ENABLE_EMERGENCY && emergency_abort) begin
            state<=0;uploading<=0;last_valid<=0;metadata_store<=0;validation_release<=1;
            if(uploading || state==9 || (state==7 && metadata_store) || state==8 || state==10) begin
                if(kind==0) begin song_ready[slot[1:0]]<=0;song_data_ready[slot[1:0]]<=0;pages[slot[1:0]]<=0;end
                if(kind==1) patch_ready[slot[2:0]]<=0;
                if(kind==2 && state==8) song_ready[slot[1:0]]<=0;
                directory_revision<=directory_revision+1'b1;
            end
        end else case(state)
            0:if(frame_valid && !response_busy) begin
                request_seq<=frame_seq;request_type<=frame_type;response_payload<=0;request_first<=payload[31:0];last_request_length<=frame_length;
                if(last_valid && frame_seq==last_seq && frame_type==last_type && payload[31:0]==last_first && frame_length==last_request_length) begin
                    response_payload<=last_response;response_seq<=last_seq;response_length<=last_length;state<=4;
                end else case(frame_type)
                    8'h01:begin response_payload[47:16]<=payload[31:0];state<=6;end
                    8'h30:begin
                        response_payload[47:16]<=32'h32565357; // WSV2
                        response_payload[79:48]<={8'd32,8'd8,8'd4,8'd3};
                        response_payload[111:80]<=65536;response_payload[127:112]<=2048;state<=6;
                        response_payload[143:128]<=ENABLE_EMERGENCY ? 16'h0007:16'h0003; // bit2=独立紧急通路
                    end
                    8'h31:begin
                        result=0;candidate=payload[7:0]==0 ? int'(payload[15:8]) : 4+int'(payload[15:8]);
                        if(frame_length!=2 || payload[7:0]>1 || candidate>=12 || (payload[7:0]==0 && payload[15:8]>=4)) result=1;
                        else begin
                            response_payload[31:16]<=payload[15:0];
                            response_payload[39:32]<=candidate<4 ? {7'd0,song_ready[candidate]} : {7'd0,patch_ready[candidate-4]};
                            response_payload[79:48]<=revisions[candidate];
                            response_payload[495:464]<=candidate<4 ? {15'd0,sizes[candidate]} : 32'd512;
                            response_payload[527:496]<=candidate<4 ? duration[candidate] : 0;
                            response_payload[535:528]<=candidate<4 ? {2'd0,sections[candidate]} : 0;
                            if(candidate>=4) begin
                                response_payload[559:544]<={4'd0,stored_envelopes[candidate-2][11:0]};
                                response_payload[575:560]<={4'd0,stored_envelopes[candidate-2][23:12]};
                                response_payload[591:576]<={4'd0,stored_envelopes[candidate-2][35:24]};
                                response_payload[607:592]<={4'd0,stored_envelopes[candidate-2][47:36]};
                            end
                        end
                        response_payload[15:8]<=result;
                        if(result==0) begin
                            metadata_store<=0;metadata_slot<=4'(candidate);metadata_index<=0;metadata_phase<=0;
                            metadata_available<=candidate<4 ? song_ready[candidate]:patch_ready[candidate-4];state<=7;
                        end else state<=6;
                    end
                    8'h32:begin
                        result=0;occupied=0;candidate=-1;need=(int'(payload[47:16])+4095)>>12;mask=0;
                        for(i=0;i<4;i=i+1) if(i!=payload[15:8]) occupied=occupied|pages[i];
                        if(payload[7:0]==0) begin
                            for(k=16;k>=0;k=k-1) begin
                                mask=16'(((32'd1<<need)-1)<<k);
                                if(need>=1 && need<=16 && k+need<=16 && (occupied&mask)==0) candidate=k;
                            end
                        end
                        if(frame_length!=74 || payload[7:0]>2 || payload[47:16]==0 || status_data[8] || status_data[9] ||
                            (payload[7:0]==0 && (payload[15:8]>=4 || payload[47:16]>65536 || candidate<0)) ||
                            (payload[7:0]==1 && (payload[15:8]>=8 || payload[47:16]!=512 ||
                                payload[543:528]==0 || payload[543:528]>4095 || payload[559:544]==0 || payload[559:544]>4095 ||
                                payload[575:560]>4095 || payload[591:576]==0 || payload[591:576]>4095)) ||
                            (payload[7:0]==2 && (payload[15:8]>=4 || payload[47:16]>768 || !song_data_ready[payload[9:8]] ||
                                revisions[payload[9:8]]!=payload[239:208]))) result=1;
                        else begin
                            uploading<=1;kind<=payload[1:0];slot<=payload[11:8];expected_size<=payload[47:16];expected_crc<=payload[79:48];
                            pending_id<=payload[207:80];pending_revision<=payload[239:208];pending_name<=payload[495:240];
                            pending_duration<=payload[527:496];pending_adsr<=payload[591:528];
                            received<=0;crc<=32'hffffffff;header_magic<=0;section_buffer<=0;section_byte<=0;section_slot<=0;
                            previous_section_end<=0;section_invalid<=0;
                            if(payload[7:0]==0) begin
                                base<=16'(candidate<<12);allocated<=16'(((32'd1<<need)-1)<<candidate);
                                song_ready[payload[9:8]]<=0;pages[payload[9:8]]<=0;
                                song_data_ready[payload[9:8]]<=0;
                            end
                            if(payload[7:0]==1) patch_ready[payload[10:8]]<=0;
                            if(payload[7:0]!=2) directory_revision<=directory_revision+1'b1;
                        end
                        response_payload[15:8]<=result;
                        if(result==0 && payload[7:0]==2) begin
                            // 配器必须与已验收曲谱的UUID逐字节一致。
                            metadata_slot<=payload[11:8];metadata_index<=0;metadata_phase<=0;state<=10;
                        end else state<=6;
                    end
                    8'h33:begin
                        if(!uploading || frame_length<5 || frame_length>132 || payload[31:0]!=received || received+frame_length-4>expected_size) begin
                            response_payload[15:8]<=2;state<=6;
                        end else begin chunk<=payload[1055:32];chunk_size<=8'(frame_length-4);index<=0;state<=1;end
                    end
                    8'h34:begin
                        result=0;
                        if(!uploading || frame_length!=4 || received!=expected_size || payload[31:0]!=expected_crc || (crc^32'hffffffff)!=expected_crc ||
                            (kind==0 && header_magic!=32'h6468544d) ||
                            (kind==2 && (section_byte!=0 || section_invalid || section_slot==0 || previous_section_end<duration[slot[1:0]]))) result=3;
                        else if(kind==0) begin
                            pages[slot[1:0]]<=allocated;bases[slot[1:0]]<=base;
                            sizes[slot[1:0]]<=expected_size[16:0];duration[slot[1:0]]<=pending_duration;sections[slot[1:0]]<=0;
                        end else if(kind==1) begin
                            parameter_write<=1;parameter_bank<=slot+2;
                            envelope_parameters<={pending_adsr[59:48],pending_adsr[43:32],pending_adsr[27:16],pending_adsr[11:0]};
                            stored_envelopes[slot+2]<={pending_adsr[59:48],pending_adsr[43:32],pending_adsr[27:16],pending_adsr[11:0]};
                        end
                        if(result==0) begin
                            if(kind!=2) begin
                                revisions[kind==0 ? slot : slot+4]<=pending_revision;
                            end
                        end
                        uploading<=0;response_payload[15:8]<=result;
                        if(result==0 && kind==0) begin
                            validation_start<=1;validation_seen<=0;validation_timer<=0;state<=9;
                        end else if(result==0 && kind!=2) begin
                            metadata_store<=1;metadata_slot<=kind==0 ? slot:slot+4;metadata_index<=0;metadata_phase<=0;state<=7;
                        end else if(result==0 && kind==2) begin metadata_index<=0;metadata_phase<=0;state<=8;end
                        else state<=6;
                    end
                    8'h35:begin
                        if(frame_length!=9 || uploading) begin response_payload[15:8]<=4;state<=6;end
                        else begin control_op<=payload[7:0];control_value<=payload[39:8];control_aux<=payload[71:40];control_valid<=1;state<=2;end
                    end
                    8'h36:begin response_payload[239:16]<=status_data;state<=6;end
                    8'h37:begin
                        response_payload[23:16]<=1;response_payload[31:24]<=command_feedback[7:0];response_payload[39:32]<=command_feedback[15:8];
                        response_payload[79:48]<=command_feedback[47:16];response_payload[303:80]<=status_data;response_payload[479:304]<=runtime_data;
                        response_payload[495:480]<={4'd0,envelope_read_data[11:0]};response_payload[511:496]<={4'd0,envelope_read_data[23:12]};
                        response_payload[527:512]<={4'd0,envelope_read_data[35:24]};response_payload[543:528]<={4'd0,envelope_read_data[47:36]};
                        response_payload[575:544]<=snapshot_counter;snapshot_counter<=snapshot_counter+1'b1;
                        response_payload[607:576]<=command_feedback[79:48];response_payload[639:608]<=command_feedback[111:80];state<=6;
                    end
                    default:begin response_payload[15:8]<=8'h7f;state<=6;end
                endcase
            end
            1:begin
                chunk<=chunk>>8;
                crc<=crc_next(crc,byte_data);
                if(received<4) header_magic[received*8+:8]<=byte_data;
                if(kind==0) begin ram_write<=1;ram_write_address<=base+16'(received);ram_write_data<=byte_data;end
                else if(kind==1) begin
                    if(!received[0]) low_byte<=byte_data;
                    else begin table_write<=1;table_address<={slot[2:0],received[8:1]};table_data<={byte_data,low_byte};end
                end else begin
                    section_buffer[section_byte*8+:8]<=byte_data;
                    if(section_byte==23) begin
                        staged_arrangements[section_slot[4:0]]<={byte_data,section_buffer[183:0]};
                        if(section_buffer[31:0]!=previous_section_end || section_buffer[63:32]<=section_buffer[31:0] ||
                           section_buffer[151:144]>9 || (section_buffer[151:144]>=2 && !patch_ready[section_buffer[151:144]-2]) ||
                           $signed(section_buffer[159:152])>24 || $signed(section_buffer[159:152])< -24 ||
                           section_buffer[135:132]!=0 || section_buffer[143:140]!=0) section_invalid<=1;
                        for(i=0;i<4;i=i+1) begin
                            if(section_buffer[64+i*8+:8]>9 || section_buffer[96+i*8+:8]>100 ||
                               (section_buffer[64+i*8+:8]>=2 && !patch_ready[section_buffer[64+i*8+:8]-2])) section_invalid<=1;
                        end
                        previous_section_end<=section_buffer[63:32];
                        section_byte<=0;section_slot<=section_slot+1'b1;
                    end else section_byte<=section_byte+1'b1;
                end
                received<=received+1'b1;
                if(index+1==chunk_size) state<=6;else index<=index+1'b1;
            end
            2:if(control_done) begin response_payload[15:8]<=control_result;state<=6;end
            6:begin
                response_payload[7:0]<=request_type;response_seq<=request_seq;
                response_length<=request_type==8'h30 ? 18 : request_type==8'h31 ? 76 : request_type==8'h36 ? 30 : request_type==8'h37 ? 80 : request_type==1 ? 6 : 2;
                state<=3;
            end
            3:if(!response_busy) begin
                last_response<=response_payload;last_seq<=response_seq;last_length<=response_length;last_valid<=1;last_type<=request_type;last_first<=request_first;state<=4;
            end
            4:if(!response_busy) begin response_valid<=1;state<=5;end
            5:if(response_busy) state<=0;
            7:begin
                if(metadata_store) begin
                    if(metadata_index<48) begin
                        metadata_write<=1;metadata_write_address<={metadata_slot,metadata_index};
                        metadata_write_data<=metadata_index<16 ? pending_id[7:0]:pending_name[7:0];
                        if(metadata_index<16) pending_id<=pending_id>>8;else pending_name<=pending_name>>8;
                        metadata_index<=metadata_index+1'b1;
                    end else begin
                        // 最后一个字节已在本拍落RAM，然后才公开ready和目录版本。
                        if(kind==0) song_data_ready[slot[1:0]]<=1;else patch_ready[slot[2:0]]<=1;
                        directory_revision<=directory_revision+1'b1;state<=6;
                    end
                end else case(metadata_phase)
                    0:begin metadata_read_address<={metadata_slot,metadata_index};metadata_phase<=1;end
                    1:metadata_phase<=2;
                    2:begin
                        response_payload[80+metadata_index*8+:8]<=metadata_available ? metadata_host_word[7:0]:8'd0;
                        if(metadata_index==47) state<=6;else metadata_index<=metadata_index+1'b1;
                        metadata_phase<=0;
                    end
                    default:metadata_phase<=0;
                endcase
            end
            // 配器暂存在独立RAM，CRC成功后才复制，失败不会破坏已发布歌曲的配器。
            8:case(metadata_phase)
                0:metadata_phase<=1;
                1:metadata_phase<=2;
                2:begin
                    arrangements[{slot[1:0],metadata_index[4:0]}]<=staged_arrangement_read;
                    if(metadata_index+1==section_slot) begin
                        sections[slot[1:0]]<=section_slot;directory_revision<=directory_revision+1'b1;state<=6;
                        song_ready[slot[1:0]]<=1;
                    end else metadata_index<=metadata_index+1'b1;
                    metadata_phase<=0;
                end
                default:metadata_phase<=0;
            endcase
            9:begin
                validation_timer<=validation_timer+1'b1;
                if(validation_busy) validation_seen<=1;
                if((validation_seen && validation_error) || validation_timer==32'd100000000 ||
                   (validation_seen && validation_done && !validation_busy && pending_duration<validation_duration)) begin
                    validation_release<=1;response_payload[15:8]<=5;state<=6;
                end else if(validation_seen && validation_done && !validation_busy) begin
                    validation_release<=1;metadata_store<=1;metadata_slot<=slot;metadata_index<=0;metadata_phase<=0;state<=7;
                end
            end
            10:case(metadata_phase)
                0:begin metadata_read_address<={metadata_slot,metadata_index};metadata_phase<=1;end
                1:metadata_phase<=2;
                2:begin
                    if(metadata_host_word[7:0]!=pending_id[metadata_index*8+:8]) begin uploading<=0;response_payload[15:8]<=6;state<=6;end
                    else if(metadata_index==15) state<=6;
                    else metadata_index<=metadata_index+1'b1;
                    metadata_phase<=0;
                end
                default:metadata_phase<=0;
            endcase
            default:state<=0;
        endcase
        end
    end
endmodule
`default_nettype wire
