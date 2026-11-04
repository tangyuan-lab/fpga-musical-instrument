`default_nettype none
// 单曲DDR后备存储：两个32KiB槽用于已发布/暂存版本；片内仅一份解析缓存。
// 上传按字节掩码写DDR，END后从DDR完整回读，解析器从不直接等待DDR。
module workstation_song_store(
    input wire clk,rst_n,storage_ready,
    input wire upload_begin,byte_valid,input wire [15:0] byte_address,input wire [7:0] byte_data,
    output wire byte_ready,input wire load_stage,load_active,commit_stage,
    output reg load_done,load_error,output wire loading,
    input wire [15:0] read_address,output wire [7:0] read_data,
    output reg req_valid,input wire req_ready,output reg req_write,
    output reg [31:0] req_address,output reg [255:0] req_data,output reg [31:0] req_mask,
    input wire resp_valid,resp_error,input wire [255:0] resp_data,output wire resp_ready
);
    localparam IDLE=0,WRITE_REQUEST=1,WRITE_RESPONSE=2,READ_REQUEST=3,READ_RESPONSE=4,CACHE_WRITE=5;
    reg [2:0] state;
    reg active_bank,active_valid,load_bank;
    reg [9:0] burst_index;
    reg [4:0] byte_index;
    reg [255:0] read_word;
    wire cache_write=state==CACHE_WRITE;
    wire [15:0] cache_address={1'b0,burst_index,byte_index};
    midi_file_ram32_sdp cache(.clk(clk),.write_enable(cache_write),.write_address(cache_address),
        .write_data(read_word[byte_index*8+:8]),.read_address(read_address),.read_data(read_data));
    assign byte_ready=storage_ready&&state==IDLE&&!load_stage&&!load_active;
    assign loading=state>=READ_REQUEST;
    assign resp_ready=state==WRITE_RESPONSE||state==READ_RESPONSE;
    always @(posedge clk)begin
        load_done<=0;
        if(!rst_n||!storage_ready)begin
            state<=IDLE;active_bank<=0;active_valid<=0;load_bank<=0;load_error<=0;
            burst_index<=0;byte_index<=0;read_word<=0;req_valid<=0;
            req_write<=0;req_address<=0;req_data<=0;req_mask<=32'hffffffff;
        end else begin
            if(commit_stage)begin active_bank<=~active_bank;active_valid<=1;end
            if(upload_begin)load_error<=0;
            case(state)
                IDLE:begin
                    if(load_stage||load_active)begin
                        load_error<=0;burst_index<=0;load_bank<=load_stage ? ~active_bank:active_bank;
                        if(load_active&&!active_valid)begin load_done<=1;load_error<=1;end
                        else state<=READ_REQUEST;
                    end else if(byte_valid&&byte_ready)begin
                        req_address<={16'd0,~active_bank,byte_address[14:5],5'd0};
                        req_data<=256'(byte_data)<<(byte_address[4:0]*8);
                        req_mask<=~(32'd1<<byte_address[4:0]);req_write<=1;req_valid<=1;state<=WRITE_REQUEST;
                    end
                end
                WRITE_REQUEST:if(req_valid&&req_ready)begin req_valid<=0;state<=WRITE_RESPONSE;end
                WRITE_RESPONSE:if(resp_valid)begin if(resp_error)load_error<=1;state<=IDLE;end
                READ_REQUEST:begin
                    req_address<={16'd0,load_bank,burst_index,5'd0};req_write<=0;req_mask<=32'hffffffff;req_data<=0;
                    if(!req_valid)req_valid<=1;
                    else if(req_ready)begin req_valid<=0;state<=READ_RESPONSE;end
                end
                READ_RESPONSE:if(resp_valid)begin
                    if(resp_error)begin load_error<=1;load_done<=1;state<=IDLE;end
                    else begin read_word<=resp_data;byte_index<=0;state<=CACHE_WRITE;end
                end
                CACHE_WRITE:if(byte_index==31)begin
                    if(burst_index==1023)begin load_done<=1;state<=IDLE;end
                    else begin burst_index<=burst_index+1'b1;state<=READ_REQUEST;end
                end else byte_index<=byte_index+1'b1;
                default:state<=IDLE;
            endcase
        end
    end
endmodule
`default_nettype wire
