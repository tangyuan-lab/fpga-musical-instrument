`default_nettype none
// 演奏版仅含控制器、PLL和复位恢复；完整BIST及其UART留在独立调试工程。
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
    wire pll_lock,memory_clk,pll_stop,ddr_rst;
    assign pll_locked=pll_lock;
    // PLL CLKOUT1固定50MHz且ENCLK1恒1；PLL启动仍用板载参考，控制域不依赖DDR校准。
    wire control_request_n=rst_n&&pll_lock;
    (* async_reg="true" *) reg [2:0] control_release;
    always @(posedge fabric_clk50 or negedge control_request_n)
        if(!control_request_n)control_release<=0;
        else control_release<={control_release[1:0],1'b1};
    wire control_rst_n=control_release[2];
    (* async_reg="true" *) reg [1:0] reinit_sync;
    reg [7:0] recovery;
    always @(posedge fabric_clk50 or negedge control_rst_n)begin
        if(!control_rst_n)begin reinit_sync<=0;recovery<=8'hff;end
        else begin
            reinit_sync<={reinit_sync[0],reinit_request};
            if(reinit_sync[1])recovery<=8'hff;
            else if(recovery!=0)recovery<=recovery-1'b1;
        end
    end
    wire ip_reset_request_n=control_rst_n&&recovery==0;
    // IP要求rst_n在它的clk输入域同步释放；此副本clk接持续运行的PLL 50MHz。
    // 断锁/外部复位/恢复请求可异步断言，释放必须经过三个完整fabric_clk50采样沿。
    (* async_reg="true" *) reg [2:0] ip_release_sync;
    always @(posedge fabric_clk50 or negedge ip_reset_request_n)
        if(!ip_reset_request_n)ip_release_sync<=0;
        else ip_release_sync<={ip_release_sync[1:0],1'b1};
    wire ip_rst_n=ip_release_sync[2];
    (* async_reg="true" *) reg [2:0] release_sync;
    always @(posedge user_clk or negedge ip_rst_n)
        if(!ip_rst_n)release_sync<=0;else release_sync<={release_sync[1:0],1'b1};
    assign user_rst_n=release_sync[2];
    // 异步关门、同步开门：五级释放至少跨过四个完整控制周期。
    // 使用PLL专用ENCLK2，所有复位脉冲均先清保护链；物理静止下界另扣时钟偏斜。
    wire clock_guard_reset_n=ip_rst_n&&!ddr_rst;
    (* async_reg="true", syn_preserve=1 *) reg [4:0] clock_guard;
    always @(posedge fabric_clk50 or negedge clock_guard_reset_n)begin
        if(!clock_guard_reset_n)clock_guard<=0;
        else clock_guard<={clock_guard[3:0],1'b1};
    end
    wire memory_clock_enable=pll_stop&&clock_guard[4]&&ip_rst_n;
    Gowin_PLL Gowin_PLL_inst(.lock(pll_lock),.clkout0(),.clkout1(fabric_clk50),.clkout2(memory_clk),
        .clkin(clk50),.init_clk(clk50),.reset(~rst_n),.enclk0(1'b1),.enclk1(1'b1),.enclk2(memory_clock_enable));
    DDR3_Memory_Interface_Top u_ddr3(
        .memory_clk(memory_clk),.pll_stop(pll_stop),.clk(fabric_clk50),.rst_n(ip_rst_n),.pll_lock(pll_lock),
        .cmd(cmd),.cmd_en(cmd_en),.cmd_ready(cmd_ready),.addr(addr),.wr_data(wr_data),.wr_data_mask(wr_data_mask),
        .wr_data_en(wr_data_en),.wr_data_end(wr_data_end),.wr_data_rdy(wr_data_rdy),
        .rd_data(rd_data),.rd_data_valid(rd_data_valid),.rd_data_end(rd_data_end),
        .sr_req(1'b0),.ref_req(1'b0),.sr_ack(),.ref_ack(),.init_calib_complete(calibrated),
        .clk_out(user_clk),.burst(1'b0),.ddr_rst(ddr_rst),
        .O_ddr_addr(ddr_addr),.O_ddr_ba(ddr_bank),.O_ddr_cs_n(ddr_cs),.O_ddr_ras_n(ddr_ras),
        .O_ddr_cas_n(ddr_cas),.O_ddr_we_n(ddr_we),.O_ddr_clk(ddr_ck),.O_ddr_clk_n(ddr_ck_n),
        .O_ddr_cke(ddr_cke),.O_ddr_odt(ddr_odt),.O_ddr_reset_n(ddr_reset_n),.O_ddr_dqm(ddr_dm),
        .IO_ddr_dq(ddr_dq),.IO_ddr_dqs(ddr_dqs),.IO_ddr_dqs_n(ddr_dqs_n));
endmodule
`default_nettype wire
