`default_nettype none
// 蓝牙租约期间，USB普通请求得到BUSY；0x3B急停在本模块上游处理，始终保留。
// 不缓存第二份普通事务，回复字段保持到原USB UART实际锁存普通ACK。
module r7_bt_usb_guard(
    input wire clk,rst_n,lease_active,external_cancel,
    input wire frame_valid,input wire [7:0] frame_type,input wire [15:0] frame_seq,
    input wire response_busy,ordinary_tx_fire,resources_idle,remote_idle,
    input wire any_usb_frame,any_response,
    output wire forward_valid,claim_idle,
    output reg reject_valid,output reg [15:0] reject_seq,output reg [7:0] reject_type,
    output reg reject_selected
);
    reg outstanding;
    wire can_take=frame_valid===1'b1 && response_busy===1'b0 && !outstanding && !reject_selected;
    assign forward_valid=can_take && lease_active===1'b0;
    assign claim_idle=resources_idle===1'b1 && remote_idle===1'b1 && !outstanding &&
        any_usb_frame===1'b0 && any_response===1'b0 && response_busy===1'b0 && !reject_valid && !reject_selected;
    always @(posedge clk)begin
        reject_valid<=0;
        if(!rst_n)begin outstanding<=0;reject_selected<=0;reject_seq<=0;reject_type<=0;end
        else begin
            if(ordinary_tx_fire===1'b1)begin outstanding<=0;reject_selected<=0;end
            if(external_cancel===1'b1)outstanding<=0;
            if(can_take)begin
                outstanding<=1;
                if(lease_active===1'b1)begin
                    reject_valid<=1;reject_selected<=1;reject_seq<=frame_seq;reject_type<=frame_type;
                end
            end
        end
    end
endmodule
`default_nettype wire
