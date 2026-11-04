`default_nettype none
// 选中最后一次成功起音且仍按住的现场音。写偏移后等待同身份音高提交才ACK。
// 32位音符ID属于按键代次；抢占/旧更新不能把设置施加到新音符或歌曲声部。
module live_note_pitch(
    input wire clk,rst_n,clear,
    input wire request,input wire signed [31:0] requested_offset,
    input wire [31:0] pressed,
    input wire event_valid,input wire [1:0] event_op,event_source,
    input wire [4:0] event_key,input wire [31:0] event_id,
    input wire [6:0] event_note,input wire [2:0] event_result,
    input wire [4:0] event_slot,input wire [31:0] active_slots,
    output reg offset_write,output reg [4:0] offset_key,
    output reg [31:0] offset_id,output reg signed [6:0] offset_value,
    output reg done,output reg [7:0] result,
    output wire [127:0] status
);
    reg selected,pending;
    reg [4:0] selected_key,selected_slot;reg [1:0] selected_source;
    reg [31:0] selected_id,revision;
    reg [6:0] base_note,current_note,pending_note;
    reg signed [6:0] applied_offset,pending_offset;
    reg [15:0] wait_cycles;
    wire signed [32:0] candidate=$signed({26'd0,base_note})+$signed(requested_offset);
    wire matches_id=event_source==selected_source&&event_id==selected_id&&event_key==selected_key;
    wire selection_lost=selected&&(!pressed[selected_key]||!active_slots[selected_slot]||
        (event_valid&&event_op==1&&event_result==0&&event_slot==selected_slot&&event_source>=2));
    wire new_selection=event_valid&&event_source<2&&event_op==1&&event_result==0&&pressed[event_key];
    wire selection_retired=selected&&event_valid&&event_source<2&&matches_id&&(event_result!=0||event_op==0);
    assign status={16'd0,revision,selected_id,{applied_offset[6],applied_offset},1'b0,current_note,
        1'b0,base_note,3'd0,selected_key,6'd0,selected_source,6'd0,pending,selected};
    always @(posedge clk)begin
        offset_write<=0;done<=0;
        if(!rst_n||clear)begin
            selected<=0;pending<=0;selected_key<=0;selected_slot<=0;selected_source<=0;selected_id<=0;revision<=0;
            base_note<=0;current_note<=0;pending_note<=0;applied_offset<=0;pending_offset<=0;
            wait_cycles<=0;offset_key<=0;offset_id<=0;offset_value<=0;result<=0;
        end else begin
            if(pending)begin
                if(wait_cycles==16'd40000)begin pending<=0;done<=1;result<=8'hfd;end
                else wait_cycles<=wait_cycles+1'b1;
            end
            if(selection_lost)begin
                selected<=0;
                if(pending)begin pending<=0;done<=1;result<=4;end
            end
            if(event_valid&&event_source<2)begin
                if(event_op==1&&event_result==0&&pressed[event_key])begin
                    selected<=1;selected_key<=event_key;selected_slot<=event_slot;selected_source<=event_source;selected_id<=event_id;
                    base_note<=event_note;current_note<=event_note;applied_offset<=0;revision<=revision+1'b1;
                    if(pending)begin pending<=0;done<=1;result<=4;end
                end else if(selected&&matches_id&&!selection_lost)begin
                    if(event_result!=0||event_op==0)begin
                        selected<=0;if(pending)begin pending<=0;done<=1;result<=1;end
                    end else if(event_op==3)begin
                        current_note<=event_note;
                        // 全局移调/八度改变后，后续单音偏移继续相对已提交的基准音。
                        if(!pending)base_note<=7'($signed({2'd0,event_note})-$signed(applied_offset));
                        if(pending&&event_note==pending_note)begin
                            applied_offset<=pending_offset;pending<=0;done<=1;result<=0;revision<=revision+1'b1;
                        end
                    end
                end
            end
            if(request)begin
                // 目标发生变化与用户请求同拍时拒绝旧目标写入；取消优先于音高提交。
                if(new_selection||selection_lost||selection_retired||pending)begin done<=1;result<=4;end
                else if(!selected||!pressed[selected_key])begin done<=1;result<=2;end
                else if(requested_offset< -12||requested_offset>12||candidate<21||candidate>108)begin done<=1;result<=1;end
                else if(requested_offset==applied_offset)begin done<=1;result<=0;end
                else begin
                    offset_write<=1;offset_key<=selected_key;offset_id<=selected_id;offset_value<=7'(requested_offset);
                    pending<=1;pending_offset<=7'(requested_offset);pending_note<=7'(candidate);wait_cycles<=0;
                end
            end
        end
    end
endmodule
`default_nettype wire
