// One physical table, four independently addressed clients. Round-robin
// service accepts one request each clock; response follows one clock later.
// A client holds request/address until ready, then captures its tagged response.
module shared_rom_4 #(
    parameter integer ADDR_WIDTH=11,
    parameter integer DATA_WIDTH=128,
    parameter INIT_FILE=""
)(
    input wire clk,rst_n,
    input wire [3:0] request,
    input wire [4*ADDR_WIDTH-1:0] address,
    output reg [3:0] ready,
    output reg [3:0] response_valid,
    output wire [4*DATA_WIDTH-1:0] response_data
);
    reg [1:0] next_client,chosen;
    reg found;
    integer i,candidate;
    always @*begin
        found=0;chosen=next_client;ready=0;
        for(i=0;i<4;i=i+1)begin
            candidate=(next_client+i)&3;
            if(!found&&request[candidate]&&rst_n)begin
                chosen=candidate;found=1;ready[candidate]=1;
            end
        end
    end
    wire [ADDR_WIDTH-1:0] selected_address=address[chosen*ADDR_WIDTH+:ADDR_WIDTH];
    wire [DATA_WIDTH-1:0] data;
    generate if(ADDR_WIDTH==4)begin:small_table
        reg [DATA_WIDTH-1:0] memory[0:(1<<ADDR_WIDTH)-1] /* synthesis syn_romstyle="logic" */;
        reg [DATA_WIDTH-1:0] q;
        initial $readmemh(INIT_FILE,memory);
        always @(posedge clk)q<=memory[selected_address];
        assign data=q;
    end else begin:block_table
        reg [DATA_WIDTH-1:0] memory[0:(1<<ADDR_WIDTH)-1] /* synthesis syn_romstyle="block_rom" */;
        reg [DATA_WIDTH-1:0] q;
        initial $readmemh(INIT_FILE,memory);
        always @(posedge clk)q<=memory[selected_address];
        assign data=q;
    end endgenerate
    assign response_data={4{data}};
    always @(posedge clk)begin
        if(!rst_n)begin next_client<=0;response_valid<=0;end
        else begin
            response_valid<=ready;
            if(found)next_client<=chosen+1'b1;
        end
    end
endmodule
