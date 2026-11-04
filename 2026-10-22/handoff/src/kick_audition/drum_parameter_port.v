// One physical ROM and one client; same one-clock handshake as shared_rom_4.
module audition_parameter_port #(
    parameter integer ADDR_WIDTH=11,
    parameter integer DATA_WIDTH=128,
    parameter INIT_FILE=""
)(
    input wire clk,rst_n,request,
    input wire [ADDR_WIDTH-1:0] address,
    output wire ready,
    output reg response_valid,
    output reg [DATA_WIDTH-1:0] response_data
);
    assign ready=request&&rst_n;
    generate if(ADDR_WIDTH==4)begin:g_small_table
        reg [DATA_WIDTH-1:0] memory[0:(1<<ADDR_WIDTH)-1] /* synthesis syn_romstyle="logic" */;
        initial $readmemh(INIT_FILE,memory);
        always @(posedge clk)response_data<=memory[address];
    end else begin:g_block_table
        reg [DATA_WIDTH-1:0] memory[0:(1<<ADDR_WIDTH)-1] /* synthesis syn_romstyle="block_rom" */;
        initial $readmemh(INIT_FILE,memory);
        always @(posedge clk)response_data<=memory[address];
    end endgenerate
    always @(posedge clk)begin
        if(!rst_n)response_valid<=0;
        else response_valid<=ready;
    end
endmodule

// Bank 0: accepted low C tom. Bank 1: analytic kick parameters.
module kick_parameter_port(
 input wire clk,rst_n,request,bank,input wire [7:0] address,
 output wire ready,output reg response_valid,output wire [287:0] response_data);
 assign ready=request&&rst_n;
 drum_parameter_storage storage(.clk(clk),.address({bank,address}),.data(response_data));
 always @(posedge clk)begin
  if(!rst_n)response_valid<=0;else response_valid<=ready;
 end
endmodule
