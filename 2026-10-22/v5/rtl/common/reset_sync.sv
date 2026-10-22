`default_nettype none
// 复位可异步拉低；释放必须经过目标时钟的两个上升沿。
module reset_sync(input wire clk, input wire arst_n, output wire rst_n);
    reg [1:0] stages;
    always @(posedge clk or negedge arst_n)
        if (!arst_n) stages <= 2'b00;
        else stages <= {stages[0], 1'b1};
    assign rst_n = stages[1];
endmodule
`default_nettype wire
