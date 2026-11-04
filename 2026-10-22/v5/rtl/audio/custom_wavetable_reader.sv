`default_nettype none

// 四路同步读、一路写的 256x16 FTB 波表。每个读口单独推断一块 BSRAM，
// 这样四声部不会形成 4096 位组合多路器；上传完成后写口保持不活动。
module custom_wavetable_reader (
    input wire clk, input wire write_enable, input wire [7:0] write_address,
    input wire signed [15:0] write_data,
    input wire [7:0] read_address0, input wire [7:0] read_address1,
    input wire [7:0] read_address2, input wire [7:0] read_address3,
    output reg signed [15:0] read_data0, output reg signed [15:0] read_data1,
    output reg signed [15:0] read_data2, output reg signed [15:0] read_data3
);
    (* ram_style = "block", syn_ramstyle = "block_ram" *) reg signed [15:0] mem0 [0:255];
    (* ram_style = "block", syn_ramstyle = "block_ram" *) reg signed [15:0] mem1 [0:255];
    (* ram_style = "block", syn_ramstyle = "block_ram" *) reg signed [15:0] mem2 [0:255];
    (* ram_style = "block", syn_ramstyle = "block_ram" *) reg signed [15:0] mem3 [0:255];
    always @(posedge clk) begin
        if (write_enable) begin
            mem0[write_address] <= write_data;
            mem1[write_address] <= write_data;
            mem2[write_address] <= write_data;
            mem3[write_address] <= write_data;
        end
        read_data0 <= mem0[read_address0];
        read_data1 <= mem1[read_address1];
        read_data2 <= mem2[read_address2];
        read_data3 <= mem3[read_address3];
    end
endmodule
`default_nettype wire
