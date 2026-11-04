`timescale 1ns/1ps

module workstation_ddr_phy(

    input wire clk50,rst_n,reinit_request,

    output wire user_clk,user_rst_n,calibrated,pll_locked,fabric_clk50,

    input wire [2:0] cmd,input wire cmd_en,output wire cmd_ready,input wire [28:0] addr,

    input wire [255:0] wr_data,input wire [31:0] wr_data_mask,input wire wr_data_en,wr_data_end,

    output wire wr_data_rdy,output wire [255:0] rd_data,output wire rd_data_valid,rd_data_end,

    output wire [14:0] ddr_addr,output wire [2:0] ddr_bank,

    output wire ddr_cs,ddr_ras,ddr_cas,ddr_we,ddr_ck,ddr_ck_n,ddr_cke,ddr_odt,ddr_reset_n,

    output wire [3:0] ddr_dm,inout wire [31:0] ddr_dq,inout wire [3:0] ddr_dqs,ddr_dqs_n

);

    // 仿真仅替换受保护的模拟PHY；桥、FIFO、资源、播放器和音源仍为生产RTL。

    reg user_clock=0;always #5 user_clock=~user_clock;

    assign fabric_clk50=clk50;
    assign user_clk=user_clock;assign user_rst_n=rst_n;assign pll_locked=rst_n;

    reg online=1;reg [8:0] calibration_count=0;

    always @(posedge clk50)if(!rst_n||reinit_request)calibration_count<=0;

        else if(calibration_count<200)calibration_count<=calibration_count+1'b1;

    assign calibrated=online&&calibration_count==200;

    assign ddr_addr=0;assign ddr_bank=0;assign ddr_cs=1;assign ddr_ras=1;assign ddr_cas=1;assign ddr_we=1;

    assign ddr_ck=user_clk;assign ddr_ck_n=~user_clk;assign ddr_cke=calibrated;assign ddr_odt=0;assign ddr_reset_n=rst_n;assign ddr_dm=0;

    assign ddr_dq=32'bz;assign ddr_dqs=4'bz;assign ddr_dqs_n=4'bz;

    reg [255:0] memory[0:2047];

    integer cycles=0,writes=0,reads=0,delay_count=0;

    assign cmd_ready=calibrated&&cycles%7>=2;

    assign wr_data_rdy=calibrated&&cycles%11>=5;

    reg command_pending=0,data_pending=0;reg [2:0] command;reg [28:0] address;

    reg [255:0] data,read_word=0;reg [31:0] mask;reg read_valid=0,read_end=0;

    assign rd_data=read_word;assign rd_data_valid=read_valid;assign rd_data_end=read_end;

    initial for(integer i=0;i<2048;i=i+1)memory[i]=0;

    always @(posedge user_clk)begin

        cycles<=cycles+1;read_valid<=0;read_end<=0;

        if(!calibrated)begin command_pending<=0;data_pending<=0;delay_count<=0;end

        else begin

            if(cmd_en&&cmd_ready)begin

                if(command_pending||addr>=16384||addr[2:0]!=0)$fatal(1,"PHY model bad/duplicate command");

                command_pending<=1;command<=cmd;address<=addr;

            end

            if(wr_data_en&&wr_data_rdy)begin

                if(data_pending||wr_data_end!==1)$fatal(1,"PHY model bad/duplicate data");

                data_pending<=1;data<=wr_data;mask<=wr_data_mask;

            end

            if(command_pending&&command==0&&data_pending)begin

                for(integer b=0;b<32;b=b+1)if(!mask[b])memory[address>>3][b*8+:8]<=data[b*8+:8];

                command_pending<=0;data_pending<=0;writes<=writes+1;

            end else if(command_pending&&command==1)begin

                if(delay_count==0)delay_count<=17;

                else if(delay_count==1)begin

                    read_word<=memory[address>>3];read_valid<=1;read_end<=1;delay_count<=0;command_pending<=0;reads<=reads+1;

                end else delay_count<=delay_count-1;

            end

        end

    end

endmodule

