// 采样来源边界。
//
// 为什么要拆：一个长尾 A4 就用掉 104/118 个块 RAM（89%），
// 想上 16 键就必须换成片外的 DDR3，而外存的延迟不可能像片上 ROM 这样
// "给地址下一拍就出数据"。所以先把"数据从哪来"和"怎么播"分开。
//
// 前段 72001x16 位、尾段 41367x8 位，两个地址每个时钟都读，
// 什么时候推进由播放器决定。以后换成 DDR3 预取缓存时，替换本模块即可，
// sampled_piano_a4.v 和 PT8211 那条链路不用动。
//
// 唯一要留神的是首次音头：按键可能在任意时钟重新触发，缓存必须已经就绪，
// 不像顺序播放那样能提前几个周期预判下一个地址。
//
// 注意：当前比特流仍然从这里读片上 ROM，还没有接 DDR3。
module piano_a4_sample_store (
    input  wire               clk,
    input  wire [16:0]        front_addr,
    input  wire [15:0]        tail_addr,
    output reg signed [15:0] front_data = 16'sd0,
    output reg signed [7:0]  tail_data = 8'sd0
);
    reg signed [15:0] front_rom [0:72000];
    reg signed [7:0] tail_rom [0:41366];
    initial begin
        $readmemh("mem/sample_a4_v16_front_72001x16.mem", front_rom);
        $readmemh("mem/sample_a4_v16_tail_41367x8.mem", tail_rom);
    end

    always @(posedge clk) begin
        front_data <= front_rom[front_addr];
        tail_data <= tail_rom[tail_addr];
    end
endmodule
