`timescale 1ns/1ps
module tb_ddr_song;
    reg test_pass=0;
    `include "sim/result.svh"
    GSR GSR(.GSRI(1'b1));
    reg app_clk=0,mem_clk=0;always #10 app_clk=~app_clk;always #5 mem_clk=~mem_clk;
    reg rst_n=0,calibrated=0;
    reg upload_begin=0,byte_valid=0,load_stage=0,load_active=0,commit_stage=0;
    reg [15:0] byte_address=0,read_address=0;reg [7:0] byte_data=0;
    wire [7:0] read_data;wire byte_ready,load_done,load_error,loading,ready,reinit;
    wire req_valid,req_ready,req_write,resp_valid,resp_ready,resp_error;
    wire [31:0] req_address,req_mask;wire [255:0] req_data,resp_data;
    wire [2:0] cmd;wire [28:0] addr;wire cmd_en,wr_data_en,wr_data_end;
    wire [255:0] wr_data;wire [31:0] wr_mask;
    reg [255:0] rd_data=0;reg rd_valid=0,rd_end=0;
    integer mem_cycle=0;
    wire cmd_ready=mem_cycle%7!=2&&mem_cycle%7!=3;
    wire data_ready=mem_cycle%11>=4;
    workstation_song_store store(.clk(app_clk),.rst_n(rst_n),.storage_ready(ready),
        .upload_begin(upload_begin),.byte_valid(byte_valid),.byte_address(byte_address),.byte_data(byte_data),.byte_ready(byte_ready),
        .load_stage(load_stage),.load_active(load_active),.commit_stage(commit_stage),.load_done(load_done),.load_error(load_error),.loading(loading),
        .read_address(read_address),.read_data(read_data),.req_valid(req_valid),.req_ready(req_ready),.req_write(req_write),
        .req_address(req_address),.req_data(req_data),.req_mask(req_mask),.resp_valid(resp_valid),.resp_ready(resp_ready),.resp_error(resp_error),.resp_data(resp_data));
    workstation_ddr_bridge bridge(.app_clk(app_clk),.app_rst_n(rst_n),.mem_clk(mem_clk),.mem_rst_n(rst_n),.calibrated(calibrated),
        .ready(ready),.reinit_request(reinit),.req_valid(req_valid),.req_ready(req_ready),.req_write(req_write),.req_address(req_address),
        .req_data(req_data),.req_mask(req_mask),.resp_valid(resp_valid),.resp_ready(resp_ready),.resp_error(resp_error),.resp_data(resp_data),
        .cmd(cmd),.cmd_en(cmd_en),.cmd_ready(cmd_ready),.addr(addr),.wr_data(wr_data),.wr_data_mask(wr_mask),
        .wr_data_en(wr_data_en),.wr_data_end(wr_data_end),.wr_data_rdy(data_ready),.rd_data(rd_data),.rd_data_valid(rd_valid),.rd_data_end(rd_end));
    reg [255:0] memory[0:2047];
    reg have_command=0,have_data=0;reg [2:0] saved_cmd;reg [28:0] saved_addr;
    reg [255:0] saved_data;reg [31:0] saved_mask;integer return_delay=0;
    integer writes=0,reads=0,commands=0,data_accepts=0,stalls=0;
    always @(posedge mem_clk)begin
        mem_cycle<=mem_cycle+1;rd_valid<=0;rd_end<=0;
        if(!rst_n||!calibrated)begin have_command<=0;have_data<=0;return_delay<=0;end
        else begin
            if((^{cmd_en,wr_data_en})===1'bx)$fatal(1,"DDR command valid X");
            if(cmd_en&&cmd_ready)begin
                if(have_command)$fatal(1,"duplicate command");
                if((^{cmd,addr})===1'bx||addr[2:0]!=0||addr>=16384)$fatal(1,"bad DDR address %h",addr);
                have_command<=1;saved_cmd<=cmd;saved_addr<=addr;commands<=commands+1;
            end
            if(wr_data_en&&data_ready)begin
                if(have_data||wr_data_end!==1'b1||(^{wr_data,wr_mask})===1'bx)$fatal(1,"duplicate/unknown data");
                have_data<=1;saved_data<=wr_data;saved_mask<=wr_mask;data_accepts<=data_accepts+1;
            end
            if((cmd_en&&!cmd_ready)||(wr_data_en&&!data_ready))stalls<=stalls+1;
            if(have_command&&saved_cmd==0&&have_data)begin
                for(integer b=0;b<32;b=b+1)if(!saved_mask[b])memory[saved_addr>>3][b*8+:8]<=saved_data[b*8+:8];
                have_command<=0;have_data<=0;writes<=writes+1;
            end else if(have_command&&saved_cmd==1)begin
                if(return_delay==0)return_delay<=8;
                else if(return_delay==1)begin
                    rd_data<=memory[saved_addr>>3];rd_valid<=1;rd_end<=1;return_delay<=0;have_command<=0;reads<=reads+1;
                    if($test$plusargs("MUTATE_READ")&&saved_addr==8192)rd_data<=memory[saved_addr>>3]^256'd1;
                end else return_delay<=return_delay-1;
            end
        end
    end
    task automatic upload(input integer version);
        begin
            @(negedge app_clk);upload_begin=1;@(negedge app_clk);upload_begin=0;
            for(integer a=0;a<64;a=a+1)begin
                while(byte_ready!==1'b1)@(negedge app_clk);
                byte_address=a;byte_data=8'(a+version*17);byte_valid=1;
                @(negedge app_clk);byte_valid=0;
                while(byte_ready!==1'b1)@(negedge app_clk);
            end
        end
    endtask
    task automatic load(input integer old);
        integer n;
        begin
            @(negedge app_clk);load_active=old;load_stage=!old;
            @(negedge app_clk);load_active=0;load_stage=0;n=0;
            while(load_done!==1'b1&&n<200000)begin @(negedge app_clk);n=n+1;end
            if(load_done!==1'b1||load_error!==1'b0)$fatal(1,"song load failure n=%0d error=%b",n,load_error);
        end
    endtask
    task automatic check(input integer version);
        begin
            for(integer a=0;a<64;a=a+1)begin
                @(negedge app_clk);read_address=a;repeat(3)@(negedge app_clk);
                if(read_data!==8'(a+version*17))$fatal(1,"cache compare address=%0d data=%h",a,read_data);
            end
        end
    endtask
    integer i;
    initial begin
        for(i=0;i<2048;i=i+1)memory[i]=0;
        repeat(5)@(negedge app_clk);rst_n=1;
        repeat(5)@(negedge app_clk);if(ready!==0)$fatal(1,"ready before calibration");
        calibrated=1;repeat(8)@(negedge app_clk);
        upload(1);load(0);check(1);
        @(negedge app_clk);commit_stage=1;@(negedge app_clk);commit_stage=0;
        upload(2);load(0);check(2);load(1);check(1);
        if(writes!=128||data_accepts!=128||reads!=3072||stalls==0)$fatal(1,"DDR counts w=%0d d=%0d r=%0d stalls=%0d",writes,data_accepts,reads,stalls);
        // 在途请求校准丢失作废；重新校准后不得收到旧响应。
        @(negedge app_clk);load_stage=1;@(negedge app_clk);load_stage=0;repeat(9)@(negedge app_clk);
        calibrated=0;repeat(8)@(negedge app_clk);if(resp_valid!==0||ready!==0)$fatal(1,"stale response after loss");
        calibrated=1;repeat(12)@(negedge app_clk);
        upload(3);load(0);check(3);
        test_pass=1;complete_test("tb_ddr_song",5);$display("PASS tb_ddr_song uploads=3 rollback=1 calibration_loss=1 writes=%0d reads=%0d stalls=%0d",writes,reads,stalls);$finish;
    end
    initial begin #30000000;$fatal(1,"DDR song timeout");end
endmodule
