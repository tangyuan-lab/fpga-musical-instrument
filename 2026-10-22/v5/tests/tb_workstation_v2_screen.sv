`timescale 1ns/1ps
module tb_workstation_v2_screen;
    reg clk=0,rst_n=0;always #10 clk=~clk;
    reg [223:0] status=0;wire [3:0] index;wire tx;
    reg [255:0] name;
    always @(*) begin
        if(index==0) name=256'h4141414141414141414141414141414141414141414141414141414141414141;
        else name={232'd0,8'h30+{4'd0,index},8'hd4,8'hb2};
    end
    workstation_v2_screen #(.CLKS_PER_BIT(4),.REFRESH_CLOCKS(4)) dut(.clk(clk),.rst_n(rst_n),.status_data(status),.directory_revision(32'd7),
        .envelope_data({12'd32,12'd3000,12'd8,12'd64}),.catalog_index(index),.catalog_name(name),.catalog_ready(index[0]),
        .runtime_data({32'd379747,32'd1800,8'd3,8'hfe,16'd125,8'd5,8'd2,32'h64636261,32'h03020100}),
        .command_feedback({32'd7,32'd11,32'd9,8'd0,8'd24}),
        .catalog_duration(32'd1920),.catalog_sections(6'd2),.tx(tx));
    wire [7:0] byte_data;wire byte_valid,bad;
    uart_rx #(.CLKS_PER_BIT(4)) receive(.clk(clk),.rst_n(rst_n),.rx(tx),.data(byte_data),.valid(byte_valid),.framing_error(bad));
    integer file,ends=0,commands=0;
    initial begin
        file=$fopen("build/tests/workstation_v2_screen.hex","w");
        status[7:0]=3;status[79:48]=123456;status[111:80]=1920;status[143:112]=7;
        repeat(8) @(negedge clk);rst_n=1;
    end
    always @(posedge clk) begin
        if(bad) $fatal(1,"screen UART framing error");
        if(byte_valid) begin
            $fwrite(file,"%02x\n",byte_data);
            if(byte_data==255) ends=ends+1;else ends=0;
            if(ends==3) begin
                ends=0;commands=commands+1;
                if(commands==65) begin $fclose(file);$display("PASS tb_workstation_v2_screen 65 commands captured");$finish;end
            end
        end
    end
    initial begin #20_000_000;$fatal(1,"screen timeout %d",commands);end
endmodule
