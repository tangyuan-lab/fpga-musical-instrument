`timescale 1ns/1ps
`include "sim/workstation_ddr_bridge_46274_reference.sv"
module tb_ddr_response_hardening;
    `include "sim/result.svh"
    reg ac=0,mc=0;always #10 ac=~ac;always #5 mc=~mc;
    reg rst_n=0,cal=0,rv=0,rr=0,rwrite=0,cr=1,dr=1,read_end=1;
    reg [31:0] request_addr=0,request_mask=0;reg [255:0] request_data=0;
    wire [1:0] ready,rready,pv,pe,reinit,ce,we,wend;
    wire [2:0] cmd[0:1];wire [28:0] addr[0:1];
    wire [255:0] wd[0:1],pdata[0:1];wire [31:0] mask[0:1];
    reg [255:0] read_data=0;reg rdvalid=0;integer latency=0,cycles=0,commands=0,words=0;
    genvar g;
    generate for(g=0;g<2;g=g+1)begin:bridges
        if(g==0)begin
            workstation_ddr_bridge_46274_reference #(.TIMEOUT(300)) dut(
                .app_clk(ac),.app_rst_n(rst_n),.mem_clk(mc),.mem_rst_n(rst_n),.calibrated(cal),
                .req_valid(rv),.req_ready(rready[g]),.req_write(rwrite),.req_address(request_addr),.req_data(request_data),.req_mask(request_mask),
                .resp_valid(pv[g]),.resp_ready(rr),.resp_error(pe[g]),.resp_data(pdata[g]),.ready(ready[g]),.reinit_request(reinit[g]),
                .cmd(cmd[g]),.cmd_en(ce[g]),.cmd_ready(cr),.addr(addr[g]),.wr_data(wd[g]),.wr_data_mask(mask[g]),
                .wr_data_en(we[g]),.wr_data_end(wend[g]),.wr_data_rdy(dr),.rd_data(read_data),.rd_data_valid(rdvalid),.rd_data_end(read_end));
        end else begin
            workstation_ddr_bridge #(.TIMEOUT(300)) dut(
                .app_clk(ac),.app_rst_n(rst_n),.mem_clk(mc),.mem_rst_n(rst_n),.calibrated(cal),
                .req_valid(rv),.req_ready(rready[g]),.req_write(rwrite),.req_address(request_addr),.req_data(request_data),.req_mask(request_mask),
                .resp_valid(pv[g]),.resp_ready(rr),.resp_error(pe[g]),.resp_data(pdata[g]),.ready(ready[g]),.reinit_request(reinit[g]),
                .cmd(cmd[g]),.cmd_en(ce[g]),.cmd_ready(cr),.addr(addr[g]),.wr_data(wd[g]),.wr_data_mask(mask[g]),
                .wr_data_en(we[g]),.wr_data_end(wend[g]),.wr_data_rdy(dr),.rd_data(read_data),.rd_data_valid(rdvalid),.rd_data_end(read_end));
        end
    end endgenerate
    always @(negedge mc)begin
        cycles=cycles+1;cr=cycles%5!=0;dr=cycles%7!=0;
        if(rst_n&&cal)begin
            if(ce[0]!==ce[1]||we[0]!==we[1]||reinit[0]!==reinit[1])$fatal(1,"DDR command/write timing changed");
            if(ce[0]&&(cmd[0]!==cmd[1]||addr[0]!==addr[1]))$fatal(1,"DDR command/address changed");
            if(we[0]&&(wd[0]!==wd[1]||mask[0]!==mask[1]||wend[0]!==wend[1]))$fatal(1,"DDR write payload changed");
        end
    end
    always @(posedge mc)begin
        rdvalid<=0;
        if(!rst_n||!cal)latency<=0;
        else begin
            if(latency>0)begin
                latency<=latency-1;
                if(latency==1)rdvalid<=1;
            end
            if(ce[0]&&cr)begin
                commands=commands+1;
                if(addr[0]!=={1'b0,request_addr[29:2]})$fatal(1,"unexpected DDR address");
                if(cmd[0]==1)begin latency<=3;read_data<={8{32'h53c90000^{3'd0,addr[0]}}};end
            end
            if(we[0]&&dr)words=words+1;
        end
    end
    always @(negedge ac)if(rst_n&&cal)begin
        if(ready[0]!==ready[1]||rready[0]!==rready[1]||pv[0]!==pv[1])$fatal(1,"application handshake timing changed");
        if(pv[0]&&(pe[0]!==pe[1]||pdata[0]!==pdata[1]))$fatal(1,"response payload changed while valid/stalled");
    end
    integer checks=0,expected_commands=0,expected_words=0,n;
    reg bad,expected_error;reg [255:0] expected_data;
    initial begin
        repeat(5)@(negedge ac);rst_n=1;cal=1;
        for(integer i=0;i<200;i=i+1)begin
            @(negedge ac);rr=0;rwrite=i%2;request_addr=32'h1000+i*32;
            if(i%6==2)request_addr=request_addr|32'h40000000;
            if(i%6==3)request_addr=request_addr+4;
            request_data={8{32'ha5000000+i}};request_mask=32'(i*13);read_end=i%9!=4;
            bad=request_addr[31:30]!=0||request_addr[4:0]!=0;
            expected_error=bad||(!rwrite&&!read_end);
            expected_data=(bad||rwrite)?256'd0:{8{32'h53c90000^{2'd0,request_addr[31:2]}}};
            if(!bad)begin expected_commands=expected_commands+1;if(rwrite)expected_words=expected_words+1;end
            rv=1;n=0;
            while(rready!==2'b11&&n<100)begin @(negedge ac);n=n+1;end
            if(n==100)$fatal(1,"request stalled");
            @(posedge ac);@(negedge ac);rv=0;
            repeat(i%13)@(negedge ac);
            n=0;while(pv!==2'b11&&n<200)begin @(negedge ac);n=n+1;end
            if(n==200||pe[1]!==expected_error||pdata[1]!==expected_data)$fatal(1,"response %0d wrong error/payload",i);
            repeat(3)@(negedge ac);rr=1;@(posedge ac);@(negedge ac);rr=0;checks=checks+1;
        end
        if(commands!=expected_commands||words!=expected_words||reinit!=0)$fatal(1,"duplicate command/data or reinit");
        complete_test("tb_ddr_response_hardening",checks);
        $display("PASS tb_ddr_response_hardening transactions=%0d cycle_exact_handshakes=1 invalid_address_read_end_backpressure=1",checks);$finish;
    end
    initial begin #1000000;$fatal(1,"DDR response timeout");end
endmodule
