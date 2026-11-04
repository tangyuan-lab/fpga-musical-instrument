`timescale 1ns/1ps
// Verbatim control cone of the published model. This is not a replacement DDR controller.
module ddr_startup_slice(input clk,memory_clk,rst_n,pll_lock,recalib_feedback,training_complete_feedback,
output pll_stop,clk_out,ddr_rst);
supply1 VCC; supply0 GND;
wire [31:0] IO_ddr_dq;
wire [3:0] IO_ddr_dqs;
wire [3:0] IO_ddr_dqs_n;
wire [14:0] O_ddr_addr;
wire [2:0] O_ddr_ba;
wire O_ddr_cas_n;
wire O_ddr_cke;
wire O_ddr_clk;
wire O_ddr_clk_n;
wire O_ddr_cs_n;
wire [3:0] O_ddr_dqm;
wire O_ddr_odt;
wire O_ddr_ras_n;
wire O_ddr_reset_n;
wire O_ddr_we_n;
wire [28:0] addr;
wire burst;
wire [2:0] cmd;
wire cmd_en;
wire cmd_ready;
wire init_calib_complete;
wire [255:0] rd_data;
wire rd_data_end;
wire rd_data_valid;
wire ref_ack;
wire ref_req;
wire sr_ack;
wire sr_req;
wire [255:0] wr_data;
wire wr_data_en;
wire wr_data_end;
wire [31:0] wr_data_mask;
wire wr_data_rdy;
wire \gw3_top/full ;
wire \gw3_top/init_complete_r ;
wire \gw3_top/phy_rd_data_valid ;
wire \gw3_top/eye_app_cmd_en_Z ;
wire \gw3_top/eye_app_wdf_wren_Z ;
wire \gw3_top/eye_calib_start_Z ;
wire \gw3_top/ddr_init_internal ;
wire [3:2] \gw3_top/mc_ras_n_Z ;
wire [3:2] \gw3_top/mc_cas_n_Z ;
wire [3:2] \gw3_top/mc_we_n_Z ;
wire [54:30] \gw3_top/mc_address_Z ;
wire [11:6] \gw3_top/mc_bank_Z ;
wire [3:2] \gw3_top/mc_cs_n_Z ;
wire [1:1] \gw3_top/mc_odt_Z ;
wire [3:3] \gw3_top/mc_cke_Z ;
wire [255:0] \gw3_top/mc_wrdata ;
wire [31:0] \gw3_top/mc_wrdata_mask_Z ;
wire [255:0] \gw3_top/eye_calib_rdata ;
wire [255:195] \gw3_top/eye_app_wdf_wdata_Z ;
wire [0:0] \gw3_top/eye_app_cmd_Z ;
wire [12:3] \gw3_top/eye_app_addr_Z ;
wire \gw3_top/u_gwmc_top/n8_4 ;
wire \gw3_top/u_gwmc_top/n11_3 ;
wire \gw3_top/u_gwmc_top/n35_3 ;
wire \gw3_top/u_gwmc_top/n36_3 ;
wire \gw3_top/u_gwmc_top/n37_3 ;
wire \gw3_top/u_gwmc_top/n41_3 ;
wire \gw3_top/u_gwmc_top/n42_3 ;
wire \gw3_top/u_gwmc_top/n43_3 ;
wire \gw3_top/u_gwmc_top/n44_3 ;
wire \gw3_top/u_gwmc_top/n113_3 ;
wire \gw3_top/u_gwmc_top/n40_7 ;
wire \gw3_top/u_gwmc_top/n39_7 ;
wire \gw3_top/u_gwmc_top/n38_7 ;
wire \gw3_top/u_gwmc_top/n34_7 ;
wire \gw3_top/u_gwmc_top/n33_7 ;
wire \gw3_top/u_gwmc_top/n32_7 ;
wire \gw3_top/u_gwmc_top/n31_7 ;
wire \gw3_top/u_gwmc_top/n30_7 ;
wire \gw3_top/u_gwmc_top/n29_7 ;
wire \gw3_top/u_gwmc_top/n28_7 ;
wire \gw3_top/u_gwmc_top/n27_7 ;
wire \gw3_top/u_gwmc_top/n26_7 ;
wire \gw3_top/u_gwmc_top/n25_7 ;
wire \gw3_top/u_gwmc_top/n24_7 ;
wire \gw3_top/u_gwmc_top/n23_7 ;
wire \gw3_top/u_gwmc_top/n22_7 ;
wire \gw3_top/u_gwmc_top/n21_7 ;
wire \gw3_top/u_gwmc_top/n20_7 ;
wire \gw3_top/u_gwmc_top/n9_7 ;
wire \gw3_top/u_gwmc_top/n10_7 ;
wire \gw3_top/u_gwmc_top/n45_7 ;
wire \gw3_top/u_gwmc_top/n46_7 ;
wire \gw3_top/u_gwmc_top/n47_7 ;
wire \gw3_top/u_gwmc_top/eye_calib_start_addr ;
wire \gw3_top/u_gwmc_top/app_en ;
wire \gw3_top/u_gwmc_top/eye_calib_start_cmd ;
wire \gw3_top/u_gwmc_top/cmd_empty_Z ;
wire \gw3_top/u_gwmc_top/mem_RAMOUT_175_G[0]_2 ;
wire \gw3_top/u_gwmc_top/mem_RAMOUT_182_G[0]_2 ;
wire \gw3_top/u_gwmc_top/mem_RAMOUT_189_G[0]_2 ;
wire \gw3_top/u_gwmc_top/mem_RAMOUT_0_G[0]_4 ;
wire \gw3_top/u_gwmc_top/mem_RAMOUT_7_G[0]_4 ;
wire \gw3_top/u_gwmc_top/mem_RAMOUT_14_G[0]_4 ;
wire \gw3_top/u_gwmc_top/mem_RAMOUT_21_G[0]_4 ;
wire \gw3_top/u_gwmc_top/mem_RAMOUT_28_G[0]_4 ;
wire \gw3_top/u_gwmc_top/mem_RAMOUT_35_G[0]_4 ;
wire \gw3_top/u_gwmc_top/mem_RAMOUT_42_G[0]_4 ;
wire \gw3_top/u_gwmc_top/mem_RAMOUT_49_G[0]_4 ;
wire \gw3_top/u_gwmc_top/mem_RAMOUT_56_G[0]_4 ;
wire \gw3_top/u_gwmc_top/mem_RAMOUT_63_G[0]_4 ;
wire \gw3_top/u_gwmc_top/mem_RAMOUT_70_G[0]_4 ;
wire \gw3_top/u_gwmc_top/mem_RAMOUT_77_G[0]_4 ;
wire \gw3_top/u_gwmc_top/mem_RAMOUT_84_G[0]_4 ;
wire \gw3_top/u_gwmc_top/mem_RAMOUT_91_G[0]_4 ;
wire \gw3_top/u_gwmc_top/mem_RAMOUT_98_G[0]_4 ;
wire \gw3_top/u_gwmc_top/mem_RAMOUT_105_G[0]_4 ;
wire \gw3_top/u_gwmc_top/mem_RAMOUT_112_G[0]_4 ;
wire \gw3_top/u_gwmc_top/mem_RAMOUT_119_G[0]_4 ;
wire \gw3_top/u_gwmc_top/mem_RAMOUT_126_G[0]_4 ;
wire \gw3_top/u_gwmc_top/mem_RAMOUT_133_G[0]_4 ;
wire \gw3_top/u_gwmc_top/mem_RAMOUT_140_G[0]_4 ;
wire \gw3_top/u_gwmc_top/mem_RAMOUT_147_G[0]_4 ;
wire \gw3_top/u_gwmc_top/mem_RAMOUT_154_G[0]_4 ;
wire \gw3_top/u_gwmc_top/mem_RAMOUT_161_G[0]_4 ;
wire \gw3_top/u_gwmc_top/mem_RAMOUT_168_G[0]_4 ;
wire \gw3_top/u_gwmc_top/mem_RAMOUT_196_G[0]_4 ;
wire \gw3_top/u_gwmc_top/mem_RAMOUT_203_G[0]_4 ;
wire \gw3_top/u_gwmc_top/mem_RAMOUT_210_G[0]_4 ;
wire \gw3_top/u_gwmc_top/mem_RAMOUT_217_G[0]_4 ;
wire \gw3_top/u_gwmc_top/cmd_write_Z ;
wire \gw3_top/u_gwmc_top/cmd_read_Z ;
wire \gw3_top/u_gwmc_top/send_zqcs_Z ;
wire \gw3_top/u_gwmc_top/idle1 ;
wire \gw3_top/u_gwmc_top/idle2 ;
wire \gw3_top/u_gwmc_top/idle3 ;
wire \gw3_top/u_gwmc_top/send_wr ;
wire \gw3_top/u_gwmc_top/send_rd ;
wire \gw3_top/u_gwmc_top/send_pre_Z ;
wire \gw3_top/u_gwmc_top/pre_all_Z ;
wire \gw3_top/u_gwmc_top/send_ref_Z ;
wire \gw3_top/u_gwmc_top/send_sre_Z ;
wire \gw3_top/u_gwmc_top/cke_set_Z ;
wire \gw3_top/u_gwmc_top/gwmc_pstate.GWMCST_WRITE ;
wire \gw3_top/u_gwmc_top/gwmc_pstate.GWMCST_READ ;
wire \gw3_top/u_gwmc_top/cmd_accept_ref_Z_3 ;
wire \gw3_top/u_gwmc_top/cmd_accept_sre_Z ;
wire \gw3_top/u_gwmc_top/cmd_accept_ref_Z ;
wire \gw3_top/u_gwmc_top/cmd_accept_Z ;
wire \gw3_top/u_gwmc_top/refresh_request_Z ;
wire \gw3_top/u_gwmc_top/sre_request_Z ;
wire [2:0] \gw3_top/u_gwmc_top/app_cmd ;
wire [27:0] \gw3_top/u_gwmc_top/app_addr ;
wire [3:2] \gw3_top/u_gwmc_top/mc_ras_n_dly ;
wire [3:2] \gw3_top/u_gwmc_top/mc_cas_n_dly ;
wire [3:2] \gw3_top/u_gwmc_top/mc_we_n_dly ;
wire [54:30] \gw3_top/u_gwmc_top/mc_address_dly ;
wire [11:6] \gw3_top/u_gwmc_top/mc_bank_dly ;
wire [3:2] \gw3_top/u_gwmc_top/mc_cs_n_dly ;
wire [1:1] \gw3_top/u_gwmc_top/mc_odt_dly ;
wire [3:3] \gw3_top/u_gwmc_top/mc_cke_dly ;
wire [0:0] \gw3_top/u_gwmc_top/act_shift_reg ;
wire [2:0] \gw3_top/u_gwmc_top/bank_d ;
wire [14:0] \gw3_top/u_gwmc_top/row_d ;
wire [9:0] \gw3_top/u_gwmc_top/col_d ;
wire [255:0] \gw3_top/u_gwmc_top/mc_wrdata_dly ;
wire [31:0] \gw3_top/u_gwmc_top/mc_wrdata_mask_dly ;
wire [11:6] \gw3_top/u_gwmc_top/mc_bank_out ;
wire [54:30] \gw3_top/u_gwmc_top/mc_address_out ;
wire [2:2] \gw3_top/u_gwmc_top/mc_ras_n_out ;
wire [2:2] \gw3_top/u_gwmc_top/mc_cas_n_out ;
wire [3:2] \gw3_top/u_gwmc_top/mc_we_n_out ;
wire [21:21] \gw3_top/u_gwmc_top/cmd3 ;
wire [3:2] \gw3_top/u_gwmc_top/mc_cs_n_out ;
wire [0:0] \gw3_top/u_gwmc_top/mc_odt_out ;
wire [3:3] \gw3_top/u_gwmc_top/mc_cke_out ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_178_G[2]_1 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_179_G[2]_1 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_180_G[2]_1 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_181_G[2]_1 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_185_G[2]_1 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_186_G[2]_1 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_187_G[2]_1 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_188_G[2]_1 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_192_G[2]_1 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_193_G[2]_1 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_194_G[2]_1 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_195_G[2]_1 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n468_20 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n468_21 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n468_22 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n468_23 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n469_20 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n469_21 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n469_22 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n469_23 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n470_20 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n470_21 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n470_22 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n470_23 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n471_20 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n471_21 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n471_22 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n471_23 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n472_20 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n472_21 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n472_22 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n472_23 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n473_20 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n473_21 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n473_22 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n473_23 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n474_20 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n474_21 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n474_22 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n474_23 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n475_20 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n475_21 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n475_22 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n475_23 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n476_20 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n476_21 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n476_22 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n476_23 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n477_20 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n477_21 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n477_22 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n477_23 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n478_20 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n478_21 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n478_22 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n478_23 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n479_20 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n479_21 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n479_22 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n479_23 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n480_20 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n480_21 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n480_22 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n480_23 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n481_20 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n481_21 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n481_22 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n481_23 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n482_20 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n482_21 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n482_22 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n482_23 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_3_G[2]_9 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_3_G[2]_10 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_3_G[2]_11 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_3_G[2]_12 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_10_G[2]_9 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_10_G[2]_10 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_10_G[2]_11 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_10_G[2]_12 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_17_G[2]_9 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_17_G[2]_10 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_17_G[2]_11 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_17_G[2]_12 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_24_G[2]_9 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_24_G[2]_10 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_24_G[2]_11 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_24_G[2]_12 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_31_G[2]_9 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_31_G[2]_10 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_31_G[2]_11 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_31_G[2]_12 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_38_G[2]_9 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_38_G[2]_10 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_38_G[2]_11 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_38_G[2]_12 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_45_G[2]_9 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_45_G[2]_10 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_45_G[2]_11 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_45_G[2]_12 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_52_G[2]_9 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_52_G[2]_10 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_52_G[2]_11 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_52_G[2]_12 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_59_G[2]_9 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_59_G[2]_10 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_59_G[2]_11 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_59_G[2]_12 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_66_G[2]_9 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_66_G[2]_10 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_66_G[2]_11 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_66_G[2]_12 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_73_G[2]_9 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_73_G[2]_10 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_73_G[2]_11 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_73_G[2]_12 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_80_G[2]_9 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_80_G[2]_10 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_80_G[2]_11 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_80_G[2]_12 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_87_G[2]_9 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_87_G[2]_10 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_87_G[2]_11 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_87_G[2]_12 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_94_G[2]_9 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_94_G[2]_10 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_94_G[2]_11 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_94_G[2]_12 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_101_G[2]_9 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_101_G[2]_10 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_101_G[2]_11 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_101_G[2]_12 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_108_G[2]_9 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_108_G[2]_10 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_108_G[2]_11 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_108_G[2]_12 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_115_G[2]_9 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_115_G[2]_10 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_115_G[2]_11 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_115_G[2]_12 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_122_G[2]_9 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_122_G[2]_10 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_122_G[2]_11 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_122_G[2]_12 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_129_G[2]_9 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_129_G[2]_10 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_129_G[2]_11 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_129_G[2]_12 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_136_G[2]_9 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_136_G[2]_10 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_136_G[2]_11 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_136_G[2]_12 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_143_G[2]_9 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_143_G[2]_10 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_143_G[2]_11 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_143_G[2]_12 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_150_G[2]_9 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_150_G[2]_10 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_150_G[2]_11 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_150_G[2]_12 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_157_G[2]_9 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_157_G[2]_10 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_157_G[2]_11 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_157_G[2]_12 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_164_G[2]_9 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_164_G[2]_10 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_164_G[2]_11 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_164_G[2]_12 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_171_G[2]_9 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_171_G[2]_10 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_171_G[2]_11 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_171_G[2]_12 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_199_G[2]_9 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_199_G[2]_10 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_199_G[2]_11 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_199_G[2]_12 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_206_G[2]_9 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_206_G[2]_10 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_206_G[2]_11 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_206_G[2]_12 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_213_G[2]_9 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_213_G[2]_10 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_213_G[2]_11 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_213_G[2]_12 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_220_G[2]_9 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_220_G[2]_10 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_220_G[2]_11 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_220_G[2]_12 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n41_3 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n183_3 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n218_3 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n253_3 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n289_3 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n324_3 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n360_3 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n396_3 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n433_3 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/write ;
wire \gw3_top/u_gwmc_top/gw_cmd0/read ;
wire \gw3_top/u_gwmc_top/gw_cmd0/cmd_empty_5 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_335 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_337 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_339 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_341 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_343 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_345 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_347 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_349 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n34_6 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n75_7 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n41_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n253_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/cmd_empty_6 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/cmd_empty_7 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/cmd_empty_8 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/write_6 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n360_6 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n218_6 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n183_6 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/next_waddr_0_15 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n510_5 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/next_raddr_0_12 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/full_invalid_10 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/full_rr ;
wire \gw3_top/u_gwmc_top/gw_cmd0/full_r ;
wire \gw3_top/u_gwmc_top/gw_cmd0/full_invalid ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_0_G[0]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_0_G[1]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_0_G[2]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_0_G[3]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_0_G[4]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_0_G[5]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_0_G[6]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_0_G[7]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_0_G[8]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_0_G[9]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_0_G[10]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_0_G[11]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_0_G[12]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_0_G[13]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_0_G[14]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_0_G[15]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_0_G[16]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_0_G[17]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_0_G[18]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_0_G[19]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_0_G[20]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_0_G[21]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_0_G[22]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_0_G[23]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_0_G[24]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_0_G[25]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_0_G[26]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_0_G[27]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_0_G[28]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_0_G[29]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_0_G[30]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_0_G[31]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_1_G[0]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_1_G[1]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_1_G[2]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_1_G[3]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_1_G[4]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_1_G[5]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_1_G[6]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_1_G[7]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_1_G[8]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_1_G[9]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_1_G[10]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_1_G[11]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_1_G[12]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_1_G[13]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_1_G[14]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_1_G[15]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_1_G[16]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_1_G[17]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_1_G[18]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_1_G[19]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_1_G[20]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_1_G[21]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_1_G[22]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_1_G[23]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_1_G[24]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_1_G[25]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_1_G[26]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_1_G[27]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_1_G[28]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_1_G[29]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_1_G[30]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_1_G[31]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_2_G[0]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_2_G[1]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_2_G[2]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_2_G[3]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_2_G[4]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_2_G[5]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_2_G[6]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_2_G[7]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_2_G[8]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_2_G[9]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_2_G[10]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_2_G[11]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_2_G[12]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_2_G[13]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_2_G[14]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_2_G[15]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_2_G[16]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_2_G[17]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_2_G[18]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_2_G[19]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_2_G[20]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_2_G[21]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_2_G[22]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_2_G[23]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_2_G[24]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_2_G[25]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_2_G[26]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_2_G[27]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_2_G[28]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_2_G[29]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_2_G[30]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_2_G[31]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_3_G[0]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_3_G[1]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_3_G[2]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_3_G[3]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_3_G[4]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_3_G[5]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_3_G[6]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_3_G[7]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_3_G[8]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_3_G[9]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_3_G[10]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_3_G[11]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_3_G[12]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_3_G[13]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_3_G[14]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_3_G[15]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_3_G[16]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_3_G[17]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_3_G[18]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_3_G[19]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_3_G[20]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_3_G[21]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_3_G[22]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_3_G[23]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_3_G[24]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_3_G[25]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_3_G[26]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_3_G[27]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_3_G[28]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_3_G[29]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_3_G[30]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_3_G[31]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_4_G[0]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_4_G[1]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_4_G[2]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_4_G[3]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_4_G[4]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_4_G[5]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_4_G[6]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_4_G[7]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_4_G[8]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_4_G[9]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_4_G[10]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_4_G[11]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_4_G[12]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_4_G[13]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_4_G[14]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_4_G[15]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_4_G[16]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_4_G[17]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_4_G[18]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_4_G[19]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_4_G[20]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_4_G[21]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_4_G[22]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_4_G[23]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_4_G[24]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_4_G[25]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_4_G[26]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_4_G[27]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_4_G[28]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_4_G[29]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_4_G[30]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_4_G[31]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_5_G[0]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_5_G[1]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_5_G[2]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_5_G[3]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_5_G[4]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_5_G[5]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_5_G[6]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_5_G[7]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_5_G[8]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_5_G[9]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_5_G[10]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_5_G[11]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_5_G[12]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_5_G[13]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_5_G[14]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_5_G[15]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_5_G[16]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_5_G[17]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_5_G[18]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_5_G[19]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_5_G[20]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_5_G[21]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_5_G[22]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_5_G[23]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_5_G[24]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_5_G[25]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_5_G[26]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_5_G[27]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_5_G[28]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_5_G[29]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_5_G[30]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_5_G[31]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_6_G[0]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_6_G[1]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_6_G[2]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_6_G[3]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_6_G[4]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_6_G[5]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_6_G[6]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_6_G[7]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_6_G[8]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_6_G[9]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_6_G[10]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_6_G[11]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_6_G[12]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_6_G[13]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_6_G[14]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_6_G[15]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_6_G[16]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_6_G[17]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_6_G[18]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_6_G[19]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_6_G[20]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_6_G[21]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_6_G[22]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_6_G[23]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_6_G[24]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_6_G[25]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_6_G[26]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_6_G[27]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_6_G[28]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_6_G[29]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_6_G[30]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_6_G[31]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_7_G[0]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_7_G[1]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_7_G[2]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_7_G[3]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_7_G[4]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_7_G[5]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_7_G[6]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_7_G[7]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_7_G[8]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_7_G[9]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_7_G[10]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_7_G[11]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_7_G[12]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_7_G[13]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_7_G[14]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_7_G[15]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_7_G[16]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_7_G[17]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_7_G[18]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_7_G[19]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_7_G[20]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_7_G[21]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_7_G[22]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_7_G[23]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_7_G[24]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_7_G[25]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_7_G[26]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_7_G[27]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_7_G[28]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_7_G[29]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_7_G[30]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_mem_RAMREG_7_G[31]_4 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n29_0_SUM ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n29_3 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n28_0_SUM ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n28_3 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n27_2 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n27_0_COUT ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n17_1_SUM ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n17_3 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n18_1_SUM ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n18_3 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n19_1_SUM ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n19_3 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n464_1_SUM ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n464_3 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n465_1_SUM ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n465_3 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n466_1_SUM ;
wire \gw3_top/u_gwmc_top/gw_cmd0/bank_change ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n483_1_SUM ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n483_3 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n484_1_SUM ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n484_3 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n485_1_SUM ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n485_3 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n486_1_SUM ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n486_3 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n487_1_SUM ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n487_3 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n488_1_SUM ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n488_3 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n489_1_SUM ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n489_3 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n490_1_SUM ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n490_3 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n491_1_SUM ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n491_3 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n492_1_SUM ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n492_3 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n493_1_SUM ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n493_3 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n494_1_SUM ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n494_3 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n495_1_SUM ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n495_3 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n496_1_SUM ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n496_3 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n497_1_SUM ;
wire \gw3_top/u_gwmc_top/gw_cmd0/row_change ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_176_G[1]_2 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_177_G[1]_2 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_183_G[1]_2 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_184_G[1]_2 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_190_G[1]_2 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_191_G[1]_2 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n468_25 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n468_27 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n469_25 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n469_27 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n470_25 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n470_27 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n471_25 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n471_27 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n472_25 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n472_27 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n473_25 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n473_27 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n474_25 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n474_27 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n475_25 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n475_27 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n476_25 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n476_27 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n477_25 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n477_27 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n478_25 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n478_27 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n479_25 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n479_27 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n480_25 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n480_27 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n481_25 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n481_27 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n482_25 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n482_27 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_3_G[2]_14 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_3_G[2]_16 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_10_G[2]_14 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_10_G[2]_16 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_17_G[2]_14 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_17_G[2]_16 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_24_G[2]_14 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_24_G[2]_16 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_31_G[2]_14 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_31_G[2]_16 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_38_G[2]_14 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_38_G[2]_16 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_45_G[2]_14 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_45_G[2]_16 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_52_G[2]_14 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_52_G[2]_16 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_59_G[2]_14 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_59_G[2]_16 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_66_G[2]_14 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_66_G[2]_16 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_73_G[2]_14 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_73_G[2]_16 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_80_G[2]_14 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_80_G[2]_16 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_87_G[2]_14 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_87_G[2]_16 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_94_G[2]_14 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_94_G[2]_16 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_101_G[2]_14 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_101_G[2]_16 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_108_G[2]_14 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_108_G[2]_16 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_115_G[2]_14 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_115_G[2]_16 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_122_G[2]_14 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_122_G[2]_16 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_129_G[2]_14 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_129_G[2]_16 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_136_G[2]_14 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_136_G[2]_16 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_143_G[2]_14 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_143_G[2]_16 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_150_G[2]_14 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_150_G[2]_16 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_157_G[2]_14 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_157_G[2]_16 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_164_G[2]_14 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_164_G[2]_16 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_171_G[2]_14 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_171_G[2]_16 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_199_G[2]_14 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_199_G[2]_16 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_206_G[2]_14 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_206_G[2]_16 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_213_G[2]_14 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_213_G[2]_16 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_220_G[2]_14 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/mem_RAMOUT_220_G[2]_16 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n468_29 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n469_29 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n470_29 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n471_29 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n472_29 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n473_29 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n474_29 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n475_29 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n476_29 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n477_29 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n478_29 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n479_29 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n480_29 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n481_29 ;
wire \gw3_top/u_gwmc_top/gw_cmd0/n482_29 ;
wire [2:1] \gw3_top/u_gwmc_top/gw_cmd0/next_waddr ;
wire [2:1] \gw3_top/u_gwmc_top/gw_cmd0/next_raddr ;
wire [2:0] \gw3_top/u_gwmc_top/gw_cmd0/bank_in_tmp ;
wire [14:0] \gw3_top/u_gwmc_top/gw_cmd0/row_in_tmp[0] ;
wire [14:0] \gw3_top/u_gwmc_top/gw_cmd0/row_in_tmp[1] ;
wire [14:0] \gw3_top/u_gwmc_top/gw_cmd0/row_in_tmp[2] ;
wire [14:0] \gw3_top/u_gwmc_top/gw_cmd0/row_in_tmp[3] ;
wire [14:0] \gw3_top/u_gwmc_top/gw_cmd0/row_in_tmp[4] ;
wire [14:0] \gw3_top/u_gwmc_top/gw_cmd0/row_in_tmp[5] ;
wire [14:0] \gw3_top/u_gwmc_top/gw_cmd0/row_in_tmp[6] ;
wire [14:0] \gw3_top/u_gwmc_top/gw_cmd0/row_in_tmp[7] ;
wire [2:0] \gw3_top/u_gwmc_top/gw_cmd0/waddr ;
wire [2:0] \gw3_top/u_gwmc_top/gw_cmd0/raddr ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n951_20 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n951_21 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n951_22 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n951_23 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n60_3 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n119_3 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n340_4 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n345_3 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n2063_3 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n2080_3 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n2093_3 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/s_satisfied_8 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/bank_acted_7_8 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/bank_acted_6_8 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/bank_acted_5_8 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/bank_acted_4_8 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/bank_acted_3_8 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/bank_acted_2_8 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/bank_acted_1_8 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/bank_acted_0_8 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_SRE_58 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_WRITE_74 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_READ_74 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_IDLE_74 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_REF_62 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_ZQ_60 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_SREI_60 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_ACT_WR_71 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_ACT_RD_72 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_W2R_61 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_WP2AW_60 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_WP2AR_59 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_R2W_61 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_RP2AW_60 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_RP2AR_59 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_ACT2WR_60 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_WP2REF_58 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_WP2SRE_58 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_ACT2RD_60 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_RP2REF_58 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_RP2SRE_58 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_SRE_60 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_SREE_56 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n1778_7 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n1777_7 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n317_7 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n314_7 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n313_7 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n138_7 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n135_7 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n133_7 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n131_7 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n78_7 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n76_7 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n73_7 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n72_7 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n2028_6 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n2024_6 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n35_6 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n33_6 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n32_6 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n30_6 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n29_6 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n1687_7 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n1947_6 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n1945_6 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n1944_6 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n1943_6 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n1942_6 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n1776_6 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n9_5 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n9_6 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n9_7 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n60_4 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n60_5 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n119_4 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n340_5 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n340_6 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/cmd_accept_sre_Z_3 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/act_one_bank_4 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/act_one_bank_5 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n2063_4 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n2063_5 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n2063_6 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n2080_4 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n2080_5 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/tZQCS_cnt_7_9 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/bank_acted_7_9 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/bank_acted_3_9 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/tRP_cnt_1_9 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/tRFC_cnt_4_9 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/tRFC_cnt_4_10 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/tRCD_cnt_1_9 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/tWTR_cnt_2_9 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/tRAS_cnt_2_9 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/tXSDLL_cnt_7_9 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_REF_64 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_REF_65 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_WRITE_75 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_WRITE_76 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_WRITE_78 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_READ_75 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_READ_76 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_READ_77 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_READ_78 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_IDLE_75 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_REF_66 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_REF_67 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_SREI_61 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_SREI_62 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_ACT_WR_72 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_ACT_WR_73 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_ACT_RD_73 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_ACT_RD_74 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_W2R_62 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_WP2AW_61 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_WP2AR_60 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_R2W_62 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_RP2AW_61 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_RP2AR_60 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_ACT2WR_61 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n1907_18 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n1777_8 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n318_8 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n315_8 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n313_8 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n137_8 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n134_8 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n132_8 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n79_8 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n75_8 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n36_8 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n31_7 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n1946_7 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n1944_7 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n1942_7 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n1874_7 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n60_6 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n119_5 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/act_one_bank_6 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/tXSDLL_cnt_7_11 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_REF_68 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_WRITE_79 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_WRITE_81 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_WRITE_82 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_WRITE_83 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_WRITE_84 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_READ_80 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_READ_81 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_IDLE_77 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_REF_69 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_REF_71 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_SREI_63 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_ACT_WR_74 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_ACT_WR_75 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_ACT_WR_76 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_ACT_RD_76 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_W2R_63 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_W2R_64 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_WP2AW_63 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_WP2AW_64 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_R2W_63 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_RP2AW_63 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_RP2AW_64 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_WRITE_85 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_WRITE_87 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_READ_83 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_IDLE_78 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_REF_72 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_WRITE_89 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_IDLE_80 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n136_10 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n1946_9 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n74_10 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n9_9 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/tXSDLL_cnt_7_13 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_WRITE_91 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_REF_74 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n2063_9 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n316_9 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n318_10 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n77_10 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n79_10 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_WRITE_93 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n32_9 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n34_8 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_ACT_RD_78 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_READ_85 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_WRITE_95 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n1779_8 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_WRITE_97 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n2088_5 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n1757_5 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_POWERON_58 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n36_10 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_READ_87 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_RP2AW_66 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_WP2AW_66 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/act_one_bank ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_nstate.GWMCST_REF_76 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n1847_8 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n1848_8 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n316_11 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n315_10 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n319_9 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n291_7 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n218_5 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n74_13 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/ms_cnt_9_14 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n75_11 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n77_13 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n80_10 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n81_10 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n132_11 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/s_cnt_9_15 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n134_11 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n136_13 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n137_11 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n139_10 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n140_10 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n295_6 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n320_13 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/tZQCS_cnt_7_13 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n1749_12 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n1750_11 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n1775_9 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/tRFC_cnt_4_14 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n1803_12 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n1804_11 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n1815_10 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n1816_9 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n1828_10 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n1829_9 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n1830_9 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n1846_10 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/tRAS_cnt_2_15 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n1861_10 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n1862_9 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n1874_12 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n1875_10 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n1876_10 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n1919_9 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/tCKESR_cnt_1_13 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n1920_9 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n1941_10 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/tXSDLL_cnt_7_18 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n1948_9 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n1907_21 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n1908_16 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n1909_18 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n31_9 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/us_satisfied ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/ms_satisfied ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/init_done_r ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/pre_cmd_read ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/pre_cmd_write ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/tZQCS_satisfied ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/s_satisfied ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_pstate.GWMCST_REF ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_pstate.GWMCST_ZQ ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_pstate.GWMCST_IDLE ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_pstate.GWMCST_SREI ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_pstate.GWMCST_ACT_WR ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_pstate.GWMCST_ACT_RD ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_pstate.GWMCST_W2R ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_pstate.GWMCST_WP2AW ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_pstate.GWMCST_WP2AR ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_pstate.GWMCST_R2W ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_pstate.GWMCST_RP2AW ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_pstate.GWMCST_RP2AR ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_pstate.GWMCST_ACT2WR ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_pstate.GWMCST_WP2REF ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_pstate.GWMCST_WP2SRE ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_pstate.GWMCST_ACT2RD ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_pstate.GWMCST_RP2REF ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_pstate.GWMCST_RP2SRE ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_pstate.GWMCST_SRE ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_pstate.GWMCST_SREE ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/gwmc_pstate.GWMCST_POWERON ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/pre_info_valid ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/pre_st_ref ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n951_25 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n951_27 ;
wire \gw3_top/u_gwmc_top/gwmc_bank_ctrl/n951_29 ;
wire [7:0] \gw3_top/u_gwmc_top/gwmc_bank_ctrl/us_cnt ;
wire [2:0] \gw3_top/u_gwmc_top/gwmc_bank_ctrl/pre_bank ;
wire [14:0] \gw3_top/u_gwmc_top/gwmc_bank_ctrl/pre_row ;
wire [9:0] \gw3_top/u_gwmc_top/gwmc_bank_ctrl/pre_col ;
wire [3:1] \gw3_top/u_gwmc_top/gwmc_bank_ctrl/act_shift_reg_0 ;
wire [9:0] \gw3_top/u_gwmc_top/gwmc_bank_ctrl/ms_cnt ;
wire [9:0] \gw3_top/u_gwmc_top/gwmc_bank_ctrl/s_cnt ;
wire [7:0] \gw3_top/u_gwmc_top/gwmc_bank_ctrl/tZQCS_cnt ;
wire [7:0] \gw3_top/u_gwmc_top/gwmc_bank_ctrl/bank_acted ;
wire [4:0] \gw3_top/u_gwmc_top/gwmc_bank_ctrl/tRFC_cnt ;
wire [2:0] \gw3_top/u_gwmc_top/gwmc_bank_ctrl/tRAS_cnt ;
wire [7:0] \gw3_top/u_gwmc_top/gwmc_bank_ctrl/tXSDLL_cnt ;
wire [1:0] \gw3_top/u_gwmc_top/gwmc_bank_ctrl/tRP_cnt ;
wire [1:0] \gw3_top/u_gwmc_top/gwmc_bank_ctrl/tRCD_cnt ;
wire [1:0] \gw3_top/u_gwmc_top/gwmc_bank_ctrl/tRTW_cnt ;
wire [2:0] \gw3_top/u_gwmc_top/gwmc_bank_ctrl/tWTR_cnt ;
wire [1:0] \gw3_top/u_gwmc_top/gwmc_bank_ctrl/tRTP_cnt ;
wire [2:0] \gw3_top/u_gwmc_top/gwmc_bank_ctrl/tWTP_cnt ;
wire [1:0] \gw3_top/u_gwmc_top/gwmc_bank_ctrl/tCKESR_cnt ;
wire [2:0] \gw3_top/u_gwmc_top/gwmc_bank_ctrl/tFAW_cnt ;
wire \gw3_top/u_gwmc_top/gwmc_timing_ctrl/sre_accepted_5 ;
wire \gw3_top/u_gwmc_top/gwmc_timing_ctrl/n68_7 ;
wire \gw3_top/u_gwmc_top/gwmc_timing_ctrl/n46_7 ;
wire \gw3_top/u_gwmc_top/gwmc_timing_ctrl/n44_7 ;
wire \gw3_top/u_gwmc_top/gwmc_timing_ctrl/n43_7 ;
wire \gw3_top/u_gwmc_top/gwmc_timing_ctrl/n17_7 ;
wire \gw3_top/u_gwmc_top/gwmc_timing_ctrl/n16_7 ;
wire \gw3_top/u_gwmc_top/gwmc_timing_ctrl/n14_7 ;
wire \gw3_top/u_gwmc_top/gwmc_timing_ctrl/n45_6 ;
wire \gw3_top/u_gwmc_top/gwmc_timing_ctrl/n42_6 ;
wire \gw3_top/u_gwmc_top/gwmc_timing_ctrl/n18_6 ;
wire \gw3_top/u_gwmc_top/gwmc_timing_ctrl/n15_6 ;
wire \gw3_top/u_gwmc_top/gwmc_timing_ctrl/n34_4 ;
wire \gw3_top/u_gwmc_top/gwmc_timing_ctrl/n34_5 ;
wire \gw3_top/u_gwmc_top/gwmc_timing_ctrl/n73_4 ;
wire \gw3_top/u_gwmc_top/gwmc_timing_ctrl/n44_8 ;
wire \gw3_top/u_gwmc_top/gwmc_timing_ctrl/n43_10 ;
wire \gw3_top/u_gwmc_top/gwmc_timing_ctrl/refresh_request_7 ;
wire \gw3_top/u_gwmc_top/gwmc_timing_ctrl/n73_6 ;
wire \gw3_top/u_gwmc_top/gwmc_timing_ctrl/rank_cnt_0_10 ;
wire \gw3_top/u_gwmc_top/gwmc_timing_ctrl/n47_9 ;
wire \gw3_top/u_gwmc_top/gwmc_timing_ctrl/n34_7 ;
wire \gw3_top/u_gwmc_top/gwmc_timing_ctrl/n94_6 ;
wire \gw3_top/u_gwmc_top/gwmc_timing_ctrl/sre_accept ;
wire \gw3_top/u_gwmc_top/gwmc_timing_ctrl/n19_7 ;
wire [5:0] \gw3_top/u_gwmc_top/gwmc_timing_ctrl/prescaler_cnt ;
wire [5:0] \gw3_top/u_gwmc_top/gwmc_timing_ctrl/refresh_timer ;
wire [0:0] \gw3_top/u_gwmc_top/gwmc_timing_ctrl/rank_cnt ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n890_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n891_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n893_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n894_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n895_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n897_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n898_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n899_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n900_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n902_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n903_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n904_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n906_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n907_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n908_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n909_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n910_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n911_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n912_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n913_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n914_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n915_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n916_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n917_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n918_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n919_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n920_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n921_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n955_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n956_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n958_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n959_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n962_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n963_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n965_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n967_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n969_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n970_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n971_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n972_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n973_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n974_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n975_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n976_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n977_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n978_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n979_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n980_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n981_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n982_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n983_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n984_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n985_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n986_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1020_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1021_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1023_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1024_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1025_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1027_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1028_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1029_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1030_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1032_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1033_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1034_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1036_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1037_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1038_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1039_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1040_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1041_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1042_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1043_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1044_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1045_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1046_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1047_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1048_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1049_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1050_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1051_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1085_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1086_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1088_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1089_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1092_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1093_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1095_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1097_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1099_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1100_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1101_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1102_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1103_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1104_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1105_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1106_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1107_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1108_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1109_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1110_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1111_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1112_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1113_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1114_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1115_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1116_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1150_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1151_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1153_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1154_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1155_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1157_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1158_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1159_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1160_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1162_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1163_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1164_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1166_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1167_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1168_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1169_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1170_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1171_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1172_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1173_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1174_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1175_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1176_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1177_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1178_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1179_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1180_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1181_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1215_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1216_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1218_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1219_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1222_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1223_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1225_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1227_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1229_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1230_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1231_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1232_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1233_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1234_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1235_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1236_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1237_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1238_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1239_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1240_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1241_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1242_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1243_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1244_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1245_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1246_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1280_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1281_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1283_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1284_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1285_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1287_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1288_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1289_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1290_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1292_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1293_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1294_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1296_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1297_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1298_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1299_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1300_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1301_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1302_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1303_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1304_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1305_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1306_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1307_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1308_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1309_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1310_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1311_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1345_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1346_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1348_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1349_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1352_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1353_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1355_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1357_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1359_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1360_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1361_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1362_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1363_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1364_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1365_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1366_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1367_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1368_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1369_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1370_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1371_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1372_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1373_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1374_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1375_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1376_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1476_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1410_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1411_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1412_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1413_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1414_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1415_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1416_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1417_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1418_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1419_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1420_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1421_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1422_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1423_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1424_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1425_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1426_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1427_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1428_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1429_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1430_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1431_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1432_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1433_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1434_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1435_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1436_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1437_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1438_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1439_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1440_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1441_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1347_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1217_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1087_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n957_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1350_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1220_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1090_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n960_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1351_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1221_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1091_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n961_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1354_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1224_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1094_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n964_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1356_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1226_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1096_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n966_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1358_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1228_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1098_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n968_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1282_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1152_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1022_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n892_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1286_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1156_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1026_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n896_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1291_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1161_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1031_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n901_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1295_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1165_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1035_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n905_7 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/eye_calib_start_wen ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/wr_wrbuf ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/wr_buf_full_r ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/n1480_6 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/wr_buf_full ;
wire [8:0] \gw3_top/u_gwmc_top/gw_wr_data0/eye_calib_start_dq ;
wire [287:0] \gw3_top/u_gwmc_top/gw_wr_data0/wr_buf_din ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/wr_fifo/n28_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/wr_fifo/n24_4 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/wr_fifo/wfull_val ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/wr_fifo/awfull_val ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/wr_fifo/wbin_next_0_8 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/wr_fifo/wfull_val_4 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/wr_fifo/wfull_val_5 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/wr_fifo/rbin_next_3_8 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/wr_fifo/wbin_next_3_8 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/wr_fifo/wfull_val_6 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/wr_fifo/n1217_8 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/wr_fifo/rbin_next_0_10 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/wr_fifo/rempty_val ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/wr_fifo/Full ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/wr_fifo/wr_buf_empt ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/wr_fifo/wcnt_sub_0_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/wr_fifo/wcnt_sub_1_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/wr_fifo/wcnt_sub_2_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/wr_fifo/wcnt_sub_3_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/wr_fifo/wcnt_sub_4_0_COUT ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/wr_fifo/n1228_1_SUM ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/wr_fifo/n1228_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/wr_fifo/n1229_1_SUM ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/wr_fifo/n1229_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/wr_fifo/n1230_1_SUM ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/wr_fifo/n1230_3 ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/wr_fifo/n1231_1_SUM ;
wire \gw3_top/u_gwmc_top/gw_wr_data0/wr_fifo/n1231_3 ;
wire [4:1] \gw3_top/u_gwmc_top/gw_wr_data0/wr_fifo/rbin_next ;
wire [4:1] \gw3_top/u_gwmc_top/gw_wr_data0/wr_fifo/wbin_next ;
wire [3:0] \gw3_top/u_gwmc_top/gw_wr_data0/wr_fifo/raddr_f ;
wire [3:0] \gw3_top/u_gwmc_top/gw_wr_data0/wr_fifo/raddr_dly ;
wire [4:0] \gw3_top/u_gwmc_top/gw_wr_data0/wr_fifo/rbin ;
wire [4:0] \gw3_top/u_gwmc_top/gw_wr_data0/wr_fifo/wbin ;
wire [4:0] \gw3_top/u_gwmc_top/gw_wr_data0/wr_fifo/wcnt_sub ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/n297_7 ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/n209_7 ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/n213_7 ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/n214_7 ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/n215_7 ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/n216_7 ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/n218_7 ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/n219_7 ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/n220_7 ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/n221_7 ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/n222_7 ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/n223_7 ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/n224_7 ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/n225_7 ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/n226_7 ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/n227_7 ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/n229_8 ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/n230_7 ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/n217_8 ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/n210_10 ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/n228_9 ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/n278_9 ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/n279_9 ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/n280_9 ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/n286_9 ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/n287_9 ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/n288_9 ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/n289_9 ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/n290_9 ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/n291_9 ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/n292_9 ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/n293_9 ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/n294_9 ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/n295_9 ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/sent_col ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/n411_10 ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/n217_10 ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/n209_10 ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/n212_9 ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/n211_9 ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/n210_12 ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/sent_row ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/cs_en2 ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/cs_en3 ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/col_cmd_we ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/slot_0_read_5 ;
wire \gw3_top/u_gwmc_top/gwmc_rank_ctrl/n298_8 ;
wire [0:0] \gw3_top/u_gwmc_top/gwmc_rank_ctrl/auxgen.mc_aux_out_r ;
wire [0:0] \gw3_top/u_gwmc_top/gwmc_rank_ctrl/auxgen.mc_aux_out_r_1 ;
wire [21:21] \gw3_top/u_gwmc_top/gwmc_rank_ctrl/cmd2 ;
wire \gw3_top/u_ddr_phy_top/n793_3 ;
wire \gw3_top/u_ddr_phy_top/n794_3 ;
wire \gw3_top/u_ddr_phy_top/n795_3 ;
wire \gw3_top/u_ddr_phy_top/n796_3 ;
wire \gw3_top/u_ddr_phy_top/n797_3 ;
wire \gw3_top/u_ddr_phy_top/n798_3 ;
wire \gw3_top/u_ddr_phy_top/n799_3 ;
wire \gw3_top/u_ddr_phy_top/n800_3 ;
wire \gw3_top/u_ddr_phy_top/n2474_3 ;
wire \gw3_top/u_ddr_phy_top/n106_4 ;
wire \gw3_top/u_ddr_phy_top/n108_8 ;
wire \gw3_top/u_ddr_phy_top/n366_9 ;
wire \gw3_top/u_ddr_phy_top/n363_9 ;
wire \gw3_top/u_ddr_phy_top/n362_9 ;
wire \gw3_top/u_ddr_phy_top/n360_9 ;
wire \gw3_top/u_ddr_phy_top/n359_9 ;
wire \gw3_top/u_ddr_phy_top/n358_9 ;
wire \gw3_top/u_ddr_phy_top/n355_9 ;
wire \gw3_top/u_ddr_phy_top/n354_9 ;
wire \gw3_top/u_ddr_phy_top/n352_9 ;
wire \gw3_top/u_ddr_phy_top/n351_9 ;
wire \gw3_top/u_ddr_phy_top/n350_9 ;
wire \gw3_top/u_ddr_phy_top/n347_9 ;
wire \gw3_top/u_ddr_phy_top/n346_9 ;
wire \gw3_top/u_ddr_phy_top/n344_9 ;
wire \gw3_top/u_ddr_phy_top/n343_9 ;
wire \gw3_top/u_ddr_phy_top/n342_9 ;
wire \gw3_top/u_ddr_phy_top/n339_9 ;
wire \gw3_top/u_ddr_phy_top/n338_9 ;
wire \gw3_top/u_ddr_phy_top/n336_9 ;
wire \gw3_top/u_ddr_phy_top/n335_9 ;
wire \gw3_top/u_ddr_phy_top/n334_9 ;
wire \gw3_top/u_ddr_phy_top/n333_9 ;
wire \gw3_top/u_ddr_phy_top/n329_9 ;
wire \gw3_top/u_ddr_phy_top/n328_9 ;
wire \gw3_top/u_ddr_phy_top/n327_9 ;
wire \gw3_top/u_ddr_phy_top/n326_9 ;
wire \gw3_top/u_ddr_phy_top/n325_9 ;
wire \gw3_top/u_ddr_phy_top/n321_9 ;
wire \gw3_top/u_ddr_phy_top/n320_9 ;
wire \gw3_top/u_ddr_phy_top/n319_9 ;
wire \gw3_top/u_ddr_phy_top/n318_9 ;
wire \gw3_top/u_ddr_phy_top/n317_9 ;
wire \gw3_top/u_ddr_phy_top/n313_9 ;
wire \gw3_top/u_ddr_phy_top/n312_9 ;
wire \gw3_top/u_ddr_phy_top/n311_9 ;
wire \gw3_top/u_ddr_phy_top/n310_9 ;
wire \gw3_top/u_ddr_phy_top/n309_9 ;
wire \gw3_top/u_ddr_phy_top/n305_9 ;
wire \gw3_top/u_ddr_phy_top/n304_9 ;
wire \gw3_top/u_ddr_phy_top/n303_9 ;
wire \gw3_top/u_ddr_phy_top/n301_9 ;
wire \gw3_top/u_ddr_phy_top/n300_9 ;
wire \gw3_top/u_ddr_phy_top/n298_9 ;
wire \gw3_top/u_ddr_phy_top/n296_9 ;
wire \gw3_top/u_ddr_phy_top/n295_9 ;
wire \gw3_top/u_ddr_phy_top/n293_9 ;
wire \gw3_top/u_ddr_phy_top/n292_9 ;
wire \gw3_top/u_ddr_phy_top/n290_9 ;
wire \gw3_top/u_ddr_phy_top/n288_9 ;
wire \gw3_top/u_ddr_phy_top/n287_9 ;
wire \gw3_top/u_ddr_phy_top/n285_9 ;
wire \gw3_top/u_ddr_phy_top/n284_9 ;
wire \gw3_top/u_ddr_phy_top/n282_9 ;
wire \gw3_top/u_ddr_phy_top/n280_9 ;
wire \gw3_top/u_ddr_phy_top/n279_9 ;
wire \gw3_top/u_ddr_phy_top/n277_9 ;
wire \gw3_top/u_ddr_phy_top/n276_9 ;
wire \gw3_top/u_ddr_phy_top/n274_9 ;
wire \gw3_top/u_ddr_phy_top/n272_9 ;
wire \gw3_top/u_ddr_phy_top/n271_9 ;
wire \gw3_top/u_ddr_phy_top/n268_9 ;
wire \gw3_top/u_ddr_phy_top/n267_9 ;
wire \gw3_top/u_ddr_phy_top/n265_9 ;
wire \gw3_top/u_ddr_phy_top/n263_9 ;
wire \gw3_top/u_ddr_phy_top/n260_9 ;
wire \gw3_top/u_ddr_phy_top/n259_9 ;
wire \gw3_top/u_ddr_phy_top/n257_9 ;
wire \gw3_top/u_ddr_phy_top/n255_9 ;
wire \gw3_top/u_ddr_phy_top/n252_9 ;
wire \gw3_top/u_ddr_phy_top/n251_9 ;
wire \gw3_top/u_ddr_phy_top/n249_9 ;
wire \gw3_top/u_ddr_phy_top/n247_9 ;
wire \gw3_top/u_ddr_phy_top/n244_9 ;
wire \gw3_top/u_ddr_phy_top/n243_9 ;
wire \gw3_top/u_ddr_phy_top/n241_9 ;
wire \gw3_top/u_ddr_phy_top/n239_9 ;
wire \gw3_top/u_ddr_phy_top/n236_9 ;
wire \gw3_top/u_ddr_phy_top/n235_9 ;
wire \gw3_top/u_ddr_phy_top/n232_9 ;
wire \gw3_top/u_ddr_phy_top/n231_9 ;
wire \gw3_top/u_ddr_phy_top/n228_9 ;
wire \gw3_top/u_ddr_phy_top/n227_9 ;
wire \gw3_top/u_ddr_phy_top/n224_9 ;
wire \gw3_top/u_ddr_phy_top/n223_9 ;
wire \gw3_top/u_ddr_phy_top/n220_9 ;
wire \gw3_top/u_ddr_phy_top/n219_9 ;
wire \gw3_top/u_ddr_phy_top/n216_9 ;
wire \gw3_top/u_ddr_phy_top/n215_9 ;
wire \gw3_top/u_ddr_phy_top/n212_9 ;
wire \gw3_top/u_ddr_phy_top/n211_9 ;
wire \gw3_top/u_ddr_phy_top/n208_9 ;
wire \gw3_top/u_ddr_phy_top/n207_9 ;
wire \gw3_top/u_ddr_phy_top/n206_9 ;
wire \gw3_top/u_ddr_phy_top/n205_9 ;
wire \gw3_top/u_ddr_phy_top/n202_9 ;
wire \gw3_top/u_ddr_phy_top/n201_9 ;
wire \gw3_top/u_ddr_phy_top/n198_9 ;
wire \gw3_top/u_ddr_phy_top/n197_9 ;
wire \gw3_top/u_ddr_phy_top/n194_9 ;
wire \gw3_top/u_ddr_phy_top/n193_9 ;
wire \gw3_top/u_ddr_phy_top/n190_9 ;
wire \gw3_top/u_ddr_phy_top/n189_9 ;
wire \gw3_top/u_ddr_phy_top/n186_9 ;
wire \gw3_top/u_ddr_phy_top/n185_9 ;
wire \gw3_top/u_ddr_phy_top/n182_9 ;
wire \gw3_top/u_ddr_phy_top/n181_9 ;
wire \gw3_top/u_ddr_phy_top/n178_9 ;
wire \gw3_top/u_ddr_phy_top/n177_9 ;
wire \gw3_top/u_ddr_phy_top/n173_9 ;
wire \gw3_top/u_ddr_phy_top/n171_9 ;
wire \gw3_top/u_ddr_phy_top/n169_9 ;
wire \gw3_top/u_ddr_phy_top/n167_9 ;
wire \gw3_top/u_ddr_phy_top/n165_9 ;
wire \gw3_top/u_ddr_phy_top/n163_9 ;
wire \gw3_top/u_ddr_phy_top/n161_9 ;
wire \gw3_top/u_ddr_phy_top/n159_9 ;
wire \gw3_top/u_ddr_phy_top/n157_9 ;
wire \gw3_top/u_ddr_phy_top/n155_9 ;
wire \gw3_top/u_ddr_phy_top/n153_9 ;
wire \gw3_top/u_ddr_phy_top/n151_9 ;
wire \gw3_top/u_ddr_phy_top/n149_9 ;
wire \gw3_top/u_ddr_phy_top/n147_9 ;
wire \gw3_top/u_ddr_phy_top/n145_9 ;
wire \gw3_top/u_ddr_phy_top/n143_9 ;
wire \gw3_top/u_ddr_phy_top/n142_9 ;
wire \gw3_top/u_ddr_phy_top/n140_9 ;
wire \gw3_top/u_ddr_phy_top/n138_9 ;
wire \gw3_top/u_ddr_phy_top/n136_9 ;
wire \gw3_top/u_ddr_phy_top/n134_9 ;
wire \gw3_top/u_ddr_phy_top/n132_9 ;
wire \gw3_top/u_ddr_phy_top/n130_9 ;
wire \gw3_top/u_ddr_phy_top/n128_9 ;
wire \gw3_top/u_ddr_phy_top/n126_9 ;
wire \gw3_top/u_ddr_phy_top/n124_9 ;
wire \gw3_top/u_ddr_phy_top/n122_9 ;
wire \gw3_top/u_ddr_phy_top/n120_9 ;
wire \gw3_top/u_ddr_phy_top/n118_9 ;
wire \gw3_top/u_ddr_phy_top/n116_9 ;
wire \gw3_top/u_ddr_phy_top/n114_9 ;
wire \gw3_top/u_ddr_phy_top/n112_9 ;
wire \gw3_top/u_ddr_phy_top/n15_9 ;
wire \gw3_top/u_ddr_phy_top/n19_9 ;
wire \gw3_top/u_ddr_phy_top/n23_9 ;
wire \gw3_top/u_ddr_phy_top/n27_9 ;
wire \gw3_top/u_ddr_phy_top/n16_9 ;
wire \gw3_top/u_ddr_phy_top/n37_8 ;
wire \gw3_top/u_ddr_phy_top/n39_8 ;
wire \gw3_top/u_ddr_phy_top/n44_8 ;
wire \gw3_top/u_ddr_phy_top/n48_8 ;
wire \gw3_top/u_ddr_phy_top/n367_8 ;
wire \gw3_top/u_ddr_phy_top/n368_8 ;
wire \gw3_top/u_ddr_phy_top/n369_8 ;
wire \gw3_top/u_ddr_phy_top/n370_8 ;
wire \gw3_top/u_ddr_phy_top/n371_8 ;
wire \gw3_top/u_ddr_phy_top/n372_8 ;
wire \gw3_top/u_ddr_phy_top/n373_8 ;
wire \gw3_top/u_ddr_phy_top/n374_8 ;
wire \gw3_top/u_ddr_phy_top/n375_8 ;
wire \gw3_top/u_ddr_phy_top/n376_8 ;
wire \gw3_top/u_ddr_phy_top/n377_8 ;
wire \gw3_top/u_ddr_phy_top/n378_8 ;
wire \gw3_top/u_ddr_phy_top/n379_8 ;
wire \gw3_top/u_ddr_phy_top/n380_8 ;
wire \gw3_top/u_ddr_phy_top/n381_8 ;
wire \gw3_top/u_ddr_phy_top/n382_8 ;
wire \gw3_top/u_ddr_phy_top/n383_8 ;
wire \gw3_top/u_ddr_phy_top/n384_8 ;
wire \gw3_top/u_ddr_phy_top/n385_8 ;
wire \gw3_top/u_ddr_phy_top/n386_8 ;
wire \gw3_top/u_ddr_phy_top/n387_8 ;
wire \gw3_top/u_ddr_phy_top/n388_8 ;
wire \gw3_top/u_ddr_phy_top/n389_8 ;
wire \gw3_top/u_ddr_phy_top/n390_8 ;
wire \gw3_top/u_ddr_phy_top/n391_8 ;
wire \gw3_top/u_ddr_phy_top/n392_8 ;
wire \gw3_top/u_ddr_phy_top/n393_8 ;
wire \gw3_top/u_ddr_phy_top/n394_8 ;
wire \gw3_top/u_ddr_phy_top/n395_8 ;
wire \gw3_top/u_ddr_phy_top/n396_8 ;
wire \gw3_top/u_ddr_phy_top/n397_8 ;
wire \gw3_top/u_ddr_phy_top/n398_8 ;
wire \gw3_top/u_ddr_phy_top/n365_8 ;
wire \gw3_top/u_ddr_phy_top/n364_8 ;
wire \gw3_top/u_ddr_phy_top/n361_8 ;
wire \gw3_top/u_ddr_phy_top/n357_8 ;
wire \gw3_top/u_ddr_phy_top/n356_8 ;
wire \gw3_top/u_ddr_phy_top/n353_8 ;
wire \gw3_top/u_ddr_phy_top/n349_8 ;
wire \gw3_top/u_ddr_phy_top/n348_8 ;
wire \gw3_top/u_ddr_phy_top/n345_8 ;
wire \gw3_top/u_ddr_phy_top/n341_8 ;
wire \gw3_top/u_ddr_phy_top/n340_8 ;
wire \gw3_top/u_ddr_phy_top/n337_8 ;
wire \gw3_top/u_ddr_phy_top/n332_8 ;
wire \gw3_top/u_ddr_phy_top/n331_8 ;
wire \gw3_top/u_ddr_phy_top/n330_8 ;
wire \gw3_top/u_ddr_phy_top/n324_8 ;
wire \gw3_top/u_ddr_phy_top/n323_8 ;
wire \gw3_top/u_ddr_phy_top/n322_8 ;
wire \gw3_top/u_ddr_phy_top/n316_8 ;
wire \gw3_top/u_ddr_phy_top/n315_8 ;
wire \gw3_top/u_ddr_phy_top/n314_8 ;
wire \gw3_top/u_ddr_phy_top/n308_8 ;
wire \gw3_top/u_ddr_phy_top/n307_8 ;
wire \gw3_top/u_ddr_phy_top/n306_8 ;
wire \gw3_top/u_ddr_phy_top/n302_8 ;
wire \gw3_top/u_ddr_phy_top/n299_8 ;
wire \gw3_top/u_ddr_phy_top/n297_8 ;
wire \gw3_top/u_ddr_phy_top/n294_8 ;
wire \gw3_top/u_ddr_phy_top/n291_8 ;
wire \gw3_top/u_ddr_phy_top/n289_8 ;
wire \gw3_top/u_ddr_phy_top/n286_8 ;
wire \gw3_top/u_ddr_phy_top/n283_8 ;
wire \gw3_top/u_ddr_phy_top/n281_8 ;
wire \gw3_top/u_ddr_phy_top/n278_8 ;
wire \gw3_top/u_ddr_phy_top/n275_8 ;
wire \gw3_top/u_ddr_phy_top/n273_8 ;
wire \gw3_top/u_ddr_phy_top/n270_8 ;
wire \gw3_top/u_ddr_phy_top/n269_8 ;
wire \gw3_top/u_ddr_phy_top/n266_8 ;
wire \gw3_top/u_ddr_phy_top/n264_8 ;
wire \gw3_top/u_ddr_phy_top/n262_8 ;
wire \gw3_top/u_ddr_phy_top/n261_8 ;
wire \gw3_top/u_ddr_phy_top/n258_8 ;
wire \gw3_top/u_ddr_phy_top/n256_8 ;
wire \gw3_top/u_ddr_phy_top/n254_8 ;
wire \gw3_top/u_ddr_phy_top/n253_8 ;
wire \gw3_top/u_ddr_phy_top/n250_8 ;
wire \gw3_top/u_ddr_phy_top/n248_8 ;
wire \gw3_top/u_ddr_phy_top/n246_8 ;
wire \gw3_top/u_ddr_phy_top/n245_8 ;
wire \gw3_top/u_ddr_phy_top/n242_8 ;
wire \gw3_top/u_ddr_phy_top/n240_8 ;
wire \gw3_top/u_ddr_phy_top/n238_8 ;
wire \gw3_top/u_ddr_phy_top/n237_8 ;
wire \gw3_top/u_ddr_phy_top/n234_8 ;
wire \gw3_top/u_ddr_phy_top/n233_8 ;
wire \gw3_top/u_ddr_phy_top/n230_8 ;
wire \gw3_top/u_ddr_phy_top/n229_8 ;
wire \gw3_top/u_ddr_phy_top/n226_8 ;
wire \gw3_top/u_ddr_phy_top/n225_8 ;
wire \gw3_top/u_ddr_phy_top/n222_8 ;
wire \gw3_top/u_ddr_phy_top/n221_8 ;
wire \gw3_top/u_ddr_phy_top/n218_8 ;
wire \gw3_top/u_ddr_phy_top/n217_8 ;
wire \gw3_top/u_ddr_phy_top/n214_8 ;
wire \gw3_top/u_ddr_phy_top/n213_8 ;
wire \gw3_top/u_ddr_phy_top/n210_8 ;
wire \gw3_top/u_ddr_phy_top/n209_8 ;
wire \gw3_top/u_ddr_phy_top/n204_8 ;
wire \gw3_top/u_ddr_phy_top/n203_8 ;
wire \gw3_top/u_ddr_phy_top/n200_8 ;
wire \gw3_top/u_ddr_phy_top/n199_8 ;
wire \gw3_top/u_ddr_phy_top/n196_8 ;
wire \gw3_top/u_ddr_phy_top/n195_8 ;
wire \gw3_top/u_ddr_phy_top/n192_8 ;
wire \gw3_top/u_ddr_phy_top/n191_8 ;
wire \gw3_top/u_ddr_phy_top/n188_8 ;
wire \gw3_top/u_ddr_phy_top/n187_8 ;
wire \gw3_top/u_ddr_phy_top/n184_8 ;
wire \gw3_top/u_ddr_phy_top/n183_8 ;
wire \gw3_top/u_ddr_phy_top/n180_8 ;
wire \gw3_top/u_ddr_phy_top/n179_8 ;
wire \gw3_top/u_ddr_phy_top/n176_8 ;
wire \gw3_top/u_ddr_phy_top/n175_8 ;
wire \gw3_top/u_ddr_phy_top/n174_8 ;
wire \gw3_top/u_ddr_phy_top/n172_8 ;
wire \gw3_top/u_ddr_phy_top/n170_8 ;
wire \gw3_top/u_ddr_phy_top/n168_8 ;
wire \gw3_top/u_ddr_phy_top/n166_8 ;
wire \gw3_top/u_ddr_phy_top/n164_8 ;
wire \gw3_top/u_ddr_phy_top/n162_8 ;
wire \gw3_top/u_ddr_phy_top/n160_8 ;
wire \gw3_top/u_ddr_phy_top/n158_8 ;
wire \gw3_top/u_ddr_phy_top/n156_8 ;
wire \gw3_top/u_ddr_phy_top/n154_8 ;
wire \gw3_top/u_ddr_phy_top/n152_8 ;
wire \gw3_top/u_ddr_phy_top/n150_8 ;
wire \gw3_top/u_ddr_phy_top/n148_8 ;
wire \gw3_top/u_ddr_phy_top/n146_8 ;
wire \gw3_top/u_ddr_phy_top/n144_8 ;
wire \gw3_top/u_ddr_phy_top/n141_8 ;
wire \gw3_top/u_ddr_phy_top/n139_8 ;
wire \gw3_top/u_ddr_phy_top/n137_8 ;
wire \gw3_top/u_ddr_phy_top/n135_8 ;
wire \gw3_top/u_ddr_phy_top/n133_8 ;
wire \gw3_top/u_ddr_phy_top/n131_8 ;
wire \gw3_top/u_ddr_phy_top/n129_8 ;
wire \gw3_top/u_ddr_phy_top/n127_8 ;
wire \gw3_top/u_ddr_phy_top/n125_8 ;
wire \gw3_top/u_ddr_phy_top/n123_8 ;
wire \gw3_top/u_ddr_phy_top/n121_8 ;
wire \gw3_top/u_ddr_phy_top/n119_8 ;
wire \gw3_top/u_ddr_phy_top/n117_8 ;
wire \gw3_top/u_ddr_phy_top/n115_8 ;
wire \gw3_top/u_ddr_phy_top/n113_8 ;
wire \gw3_top/u_ddr_phy_top/n111_8 ;
wire \gw3_top/u_ddr_phy_top/n99_8 ;
wire \gw3_top/u_ddr_phy_top/n98_8 ;
wire \gw3_top/u_ddr_phy_top/n97_8 ;
wire \gw3_top/u_ddr_phy_top/n94_8 ;
wire \gw3_top/u_ddr_phy_top/n64_8 ;
wire \gw3_top/u_ddr_phy_top/n63_8 ;
wire \gw3_top/u_ddr_phy_top/n62_8 ;
wire \gw3_top/u_ddr_phy_top/n61_8 ;
wire \gw3_top/u_ddr_phy_top/n60_8 ;
wire \gw3_top/u_ddr_phy_top/n59_8 ;
wire \gw3_top/u_ddr_phy_top/n58_8 ;
wire \gw3_top/u_ddr_phy_top/n57_8 ;
wire \gw3_top/u_ddr_phy_top/n56_8 ;
wire \gw3_top/u_ddr_phy_top/n55_8 ;
wire \gw3_top/u_ddr_phy_top/n54_8 ;
wire \gw3_top/u_ddr_phy_top/n53_8 ;
wire \gw3_top/u_ddr_phy_top/n52_8 ;
wire \gw3_top/u_ddr_phy_top/n51_8 ;
wire \gw3_top/u_ddr_phy_top/n50_8 ;
wire \gw3_top/u_ddr_phy_top/n49_8 ;
wire \gw3_top/u_ddr_phy_top/n106_6 ;
wire \gw3_top/u_ddr_phy_top/n96_5 ;
wire \gw3_top/u_ddr_phy_top/n95_5 ;
wire \gw3_top/u_ddr_phy_top/n47_5 ;
wire \gw3_top/u_ddr_phy_top/n46_5 ;
wire \gw3_top/u_ddr_phy_top/n45_5 ;
wire \gw3_top/u_ddr_phy_top/n43_5 ;
wire \gw3_top/u_ddr_phy_top/n42_5 ;
wire \gw3_top/u_ddr_phy_top/n41_5 ;
wire \gw3_top/u_ddr_phy_top/n40_5 ;
wire \gw3_top/u_ddr_phy_top/n38_5 ;
wire \gw3_top/u_ddr_phy_top/n36_5 ;
wire \gw3_top/u_ddr_phy_top/n30_5 ;
wire \gw3_top/u_ddr_phy_top/n26_5 ;
wire \gw3_top/u_ddr_phy_top/n22_5 ;
wire \gw3_top/u_ddr_phy_top/n18_5 ;
wire \gw3_top/u_ddr_phy_top/n17_5 ;
wire \gw3_top/u_ddr_phy_top/n14_6 ;
wire \gw3_top/u_ddr_phy_top/ddr_init_internal_rr ;
wire \gw3_top/u_ddr_phy_top/eye_calib_start_r ;
wire \gw3_top/u_ddr_phy_top/eye_calib_start_rr ;
wire \gw3_top/u_ddr_phy_top/mux_reset_n ;
wire \gw3_top/u_ddr_phy_top/ddr_init_st_r ;
wire \gw3_top/u_ddr_phy_top/ddr_init_st_rr ;
wire \gw3_top/u_ddr_phy_top/ddr_init_st_rrr ;
wire \gw3_top/u_ddr_phy_top/ddr_init_internal_r ;
wire \gw3_top/u_ddr_phy_top/dll_lock ;
wire \gw3_top/u_ddr_phy_top/n7_6 ;
wire \gw3_top/u_ddr_phy_top/n809_6 ;
wire \gw3_top/u_ddr_phy_top/n2457_6 ;
wire \gw3_top/u_ddr_phy_top/eye_calib_start_r_12 ;
wire \gw3_top/u_ddr_phy_top/eye_calib_valid ;
wire \gw3_top/u_ddr_phy_top/read_line3 ;
wire \gw3_top/u_ddr_phy_top/read_line2 ;
wire \gw3_top/u_ddr_phy_top/read_line1 ;
wire \gw3_top/u_ddr_phy_top/init_rmove_done_r ;
wire \gw3_top/u_ddr_phy_top/sys_reset_Z ;
wire \gw3_top/u_ddr_phy_top/if_fifo_rst_Z ;
wire \gw3_top/u_ddr_phy_top/rmove_left_done_Z ;
wire \gw3_top/u_ddr_phy_top/eye_calib_done_Z ;
wire \gw3_top/u_ddr_phy_top/eye_calib_rmove_Z ;
wire \gw3_top/u_ddr_phy_top/eye_calib_done_r ;
wire \gw3_top/u_ddr_phy_top/rmove_left_flag_Z ;
wire \gw3_top/u_ddr_phy_top/phy_reset_n ;
wire \gw3_top/u_ddr_phy_top/wrlvl_start ;
wire \gw3_top/u_ddr_phy_top/init_rmove_start_Z ;
wire \gw3_top/u_ddr_phy_top/wrlvl_complete_Z ;
wire \gw3_top/u_ddr_phy_top/phy_dqs ;
wire \gw3_top/u_ddr_phy_top/read_calibration_logic_gen[0].read_adj ;
wire \gw3_top/u_ddr_phy_top/read_calibration_logic_gen[1].read_adj ;
wire \gw3_top/u_ddr_phy_top/read_calibration_logic_gen[2].read_adj ;
wire \gw3_top/u_ddr_phy_top/read_calibration_logic_gen[3].read_adj ;
wire \gw3_top/u_ddr_phy_top/stop_d ;
wire \gw3_top/u_ddr_phy_top/pause ;
wire \gw3_top/u_ddr_phy_top/dll_rsti ;
wire \gw3_top/u_ddr_phy_top/ddr_init_st_Z ;
wire \gw3_top/u_ddr_phy_top/uddcntln ;
wire [3:0] \gw3_top/u_ddr_phy_top/mux_cs_n ;
wire [3:2] \gw3_top/u_ddr_phy_top/mux_ras_n ;
wire [3:2] \gw3_top/u_ddr_phy_top/mux_cas_n ;
wire [3:2] \gw3_top/u_ddr_phy_top/mux_we_n ;
wire [3:3] \gw3_top/u_ddr_phy_top/mux_cke ;
wire [59:29] \gw3_top/u_ddr_phy_top/mux_addr ;
wire [11:6] \gw3_top/u_ddr_phy_top/mux_bank ;
wire [1:1] \gw3_top/u_ddr_phy_top/mux_odt ;
wire [255:0] \gw3_top/u_ddr_phy_top/mux_wrdata ;
wire [31:0] \gw3_top/u_ddr_phy_top/mux_wrdata_mask ;
wire [3:0] \gw3_top/u_ddr_phy_top/rmove ;
wire [3:0] \gw3_top/u_ddr_phy_top/rdir ;
wire [3:3] \gw3_top/u_ddr_phy_top/wloadn ;
wire [2:0] \gw3_top/u_ddr_phy_top/stop_reg ;
wire [1:0] \gw3_top/u_ddr_phy_top/ddr_rsti_reg ;
wire [7:0] \gw3_top/u_ddr_phy_top/dll_step_base ;
wire [7:0] \gw3_top/u_ddr_phy_top/dll_step ;
wire [3:0] \gw3_top/u_ddr_phy_top/phy_rdbk_data_valid ;
wire [3:0] \gw3_top/u_ddr_phy_top/in_dq0_Z ;
wire [0:0] \gw3_top/u_ddr_phy_top/RBURST ;
wire [0:0] \gw3_top/u_ddr_phy_top/rvalid_Z ;
wire [1:1] \gw3_top/u_ddr_phy_top/RBURST_0 ;
wire [1:1] \gw3_top/u_ddr_phy_top/rvalid_Z_0 ;
wire [2:2] \gw3_top/u_ddr_phy_top/RBURST_1 ;
wire [2:2] \gw3_top/u_ddr_phy_top/rvalid_Z_1 ;
wire [3:3] \gw3_top/u_ddr_phy_top/RBURST_2 ;
wire [3:3] \gw3_top/u_ddr_phy_top/rvalid_Z_2 ;
wire [3:0] \gw3_top/u_ddr_phy_top/init_rmove ;
wire [1:1] \gw3_top/u_ddr_phy_top/init_rdir ;
wire [31:0] \gw3_top/u_ddr_phy_top/realtime_dllcode_Z ;
wire [3:0] \gw3_top/u_ddr_phy_top/rdir_0 ;
wire [3:0] \gw3_top/u_ddr_phy_top/eye_rmove ;
wire [0:0] \gw3_top/u_ddr_phy_top/eye_calib_error_valid_Z ;
wire [3:0] \gw3_top/u_ddr_phy_top/eye_calib_error_Z ;
wire [1:1] \gw3_top/u_ddr_phy_top/phy_odt_d1 ;
wire [1:1] \gw3_top/u_ddr_phy_top/phy_odt_d2 ;
wire [3:3] \gw3_top/u_ddr_phy_top/phy_cas_n ;
wire [3:3] \gw3_top/u_ddr_phy_top/phy_ras_n ;
wire [3:3] \gw3_top/u_ddr_phy_top/phy_cs_n ;
wire [3:0] \gw3_top/u_ddr_phy_top/phy_we_n ;
wire [57:48] \gw3_top/u_ddr_phy_top/phy_addr ;
wire [10:9] \gw3_top/u_ddr_phy_top/phy_bank ;
wire [0:0] \gw3_top/u_ddr_phy_top/phy_cke ;
wire [31:0] \gw3_top/u_ddr_phy_top/wstep_Z ;
wire [11:0] \gw3_top/u_ddr_phy_top/rclk_sel ;
wire [15:0] \gw3_top/u_ddr_phy_top/read ;
wire [3:0] \gw3_top/u_ddr_phy_top/read_calib_rmove_Z ;
wire [1:1] \gw3_top/u_ddr_phy_top/phy_odt_pre ;
wire [3:0] \gw3_top/u_ddr_phy_top/hold_Z ;
wire [3:3] \gw3_top/u_ddr_phy_top/cs_memsync ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/n67_4 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/n74_4 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/n81_5 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/n88_5 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/n95_5 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/n102_5 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/n468_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/n478_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/n488_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/n498_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/n1837_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/n50_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/n45_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/n30_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/n20_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/n60_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/n67_5 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/n468_4 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/n468_5 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/n478_4 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/n478_5 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/n488_4 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/n488_5 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/n498_4 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/n498_5 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/dqsts0_d ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/dqts_d ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/dqts0_d ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/mux_dqs ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/dqsts1_d ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/dq_iobuf_gen[0].dq_iodelay_1_DF ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/dq_iobuf_gen[1].dq_iodelay_1_DF ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/dq_iobuf_gen[2].dq_iodelay_1_DF ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/dq_iobuf_gen[3].dq_iodelay_1_DF ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/dq_iobuf_gen[4].dq_iodelay_1_DF ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/dq_iobuf_gen[5].dq_iodelay_1_DF ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/dq_iobuf_gen[6].dq_iodelay_1_DF ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/dq_iobuf_gen[7].dq_iodelay_1_DF ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/dq_iobuf_gen[8].dq_iodelay_1_DF ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/dq_iobuf_gen[9].dq_iodelay_1_DF ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/dq_iobuf_gen[10].dq_iodelay_1_DF ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/dq_iobuf_gen[11].dq_iodelay_1_DF ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/dq_iobuf_gen[12].dq_iodelay_1_DF ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/dq_iobuf_gen[13].dq_iodelay_1_DF ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/dq_iobuf_gen[14].dq_iodelay_1_DF ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/dq_iobuf_gen[15].dq_iodelay_1_DF ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/dq_iobuf_gen[16].dq_iodelay_1_DF ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/dq_iobuf_gen[17].dq_iodelay_1_DF ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/dq_iobuf_gen[18].dq_iodelay_1_DF ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/dq_iobuf_gen[19].dq_iodelay_1_DF ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/dq_iobuf_gen[20].dq_iodelay_1_DF ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/dq_iobuf_gen[21].dq_iodelay_1_DF ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/dq_iobuf_gen[22].dq_iodelay_1_DF ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/dq_iobuf_gen[23].dq_iodelay_1_DF ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/dq_iobuf_gen[24].dq_iodelay_1_DF ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/dq_iobuf_gen[25].dq_iodelay_1_DF ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/dq_iobuf_gen[26].dq_iodelay_1_DF ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/dq_iobuf_gen[27].dq_iodelay_1_DF ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/dq_iobuf_gen[28].dq_iodelay_1_DF ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/dq_iobuf_gen[29].dq_iodelay_1_DF ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/dq_iobuf_gen[30].dq_iodelay_1_DF ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/dq_iobuf_gen[31].dq_iodelay_1_DF ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/invalid_dqs_r ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/dqs_r ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/n250_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/n251_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/n257_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/n258_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/n395_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/dqs_reg ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/dqsts1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/invalid_wdata_en_Z ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/ddr_clk_out ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/if_wrreset_Z ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/in_dqs ;
wire [31:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/in_dq ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/in_dq0_reg ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/if_fifo_rd_flg ;
wire [31:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/in_dq_p ;
wire [0:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/out_dqs ;
wire [0:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/out_dqsts ;
wire [7:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/out_dq ;
wire [7:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/out_dqts ;
wire [0:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/out_dm ;
wire [0:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/out_dmts_Z ;
wire [1:1] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/out_dqs_0 ;
wire [1:1] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/out_dqsts_0 ;
wire [15:8] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/out_dq_0 ;
wire [15:8] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/out_dqts_0 ;
wire [1:1] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/out_dm_0 ;
wire [1:1] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/out_dmts_Z_0 ;
wire [2:2] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/out_dqs_1 ;
wire [2:2] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/out_dqsts_1 ;
wire [23:16] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/out_dq_1 ;
wire [23:16] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/out_dqts_1 ;
wire [2:2] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/out_dm_1 ;
wire [2:2] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/out_dmts_Z_1 ;
wire [3:3] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/out_dqs_2 ;
wire [3:3] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/out_dqsts_2 ;
wire [31:24] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/out_dq_2 ;
wire [31:24] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/out_dqts_2 ;
wire [3:3] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/out_dm_2 ;
wire [3:3] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/out_dmts_Z_2 ;
wire [23:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/cmd_line ;
wire [2:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/if_raddr ;
wire [2:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/if_waddr ;
wire [0:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/if_empty ;
wire [5:3] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/if_raddr_0 ;
wire [5:3] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/if_waddr_0 ;
wire [1:1] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/if_empty_0 ;
wire [8:6] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/if_raddr_1 ;
wire [8:6] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/if_waddr_1 ;
wire [2:2] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/if_empty_1 ;
wire [11:9] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/if_raddr_2 ;
wire [11:9] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/if_waddr_2 ;
wire [3:3] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/if_empty_2 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n587_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n588_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n589_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n590_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n591_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n592_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n593_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n594_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n595_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n596_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n597_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n598_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n599_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n600_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n601_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n602_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n603_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n604_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n605_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n606_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n607_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n608_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n609_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n610_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n611_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n612_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n613_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n614_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n615_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n616_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n617_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n618_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n619_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n620_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n621_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n622_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n623_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n624_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n625_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n626_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n627_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n628_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n629_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n630_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n631_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n632_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n633_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n634_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n635_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n636_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n637_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n638_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n639_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n640_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n641_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n642_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n643_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n644_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n645_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n646_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n647_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n648_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n649_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n650_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n651_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n652_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n653_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n654_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n655_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n656_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n657_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/n658_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/invalid_dqs ;
wire [71:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/of_WrData_r ;
wire [71:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/of_WrData_rr ;
wire [71:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/of_WrData_rrr ;
wire [71:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/oserdes_dq ;
wire [63:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/iserdes_dq_Z ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/u_ddr_phy_data_io/dqsts0_r ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/u_ddr_phy_data_io/dqsts1_r ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/u_ddr_phy_data_io/dqts_r ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/u_ddr_phy_data_io/dqts0_r ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/u_ddr_phy_data_io/rmove_r ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/u_ddr_phy_data_io/rdir_r ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/u_ddr_phy_data_io/ides_calib_d ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/u_ddr_phy_data_io/dqsr90 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/u_ddr_phy_data_io/dqsw0 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/u_ddr_phy_data_io/dqsw270 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/u_ddr_phy_data_io/rvalid_wire ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/u_ddr_phy_data_io/rflag_wire ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/u_ddr_phy_data_io/wflag ;
wire [71:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/u_ddr_phy_data_io/oserdes_dq_r ;
wire [71:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/u_ddr_phy_data_io/oserdes_dq_rr ;
wire [63:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/u_ddr_phy_data_io/iserdes_dq_wire ;
wire [2:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/u_ddr_phy_data_io/rpoint ;
wire [2:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[0].u_ddr_phy_data_lane/u_ddr_phy_data_io/wpoint ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n587_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n588_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n589_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n590_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n591_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n592_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n593_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n594_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n595_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n596_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n597_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n598_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n599_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n600_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n601_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n602_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n603_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n604_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n605_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n606_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n607_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n608_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n609_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n610_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n611_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n612_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n613_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n614_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n615_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n616_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n617_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n618_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n619_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n620_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n621_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n622_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n623_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n624_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n625_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n626_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n627_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n628_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n629_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n630_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n631_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n632_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n633_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n634_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n635_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n636_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n637_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n638_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n639_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n640_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n641_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n642_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n643_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n644_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n645_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n646_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n647_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n648_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n649_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n650_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n651_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n652_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n653_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n654_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n655_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n656_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n657_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/n658_8 ;
wire [71:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/of_WrData_r ;
wire [71:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/of_WrData_rr ;
wire [71:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/of_WrData_rrr ;
wire [71:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/oserdes_dq ;
wire [63:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/iserdes_dq_Z ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/u_ddr_phy_data_io/rmove_r ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/u_ddr_phy_data_io/rdir_r ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/u_ddr_phy_data_io/ides_calib_d ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/u_ddr_phy_data_io/dqsr90 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/u_ddr_phy_data_io/dqsw0 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/u_ddr_phy_data_io/dqsw270 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/u_ddr_phy_data_io/rvalid_wire ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/u_ddr_phy_data_io/rflag_wire ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/u_ddr_phy_data_io/wflag ;
wire [71:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/u_ddr_phy_data_io/oserdes_dq_r ;
wire [71:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/u_ddr_phy_data_io/oserdes_dq_rr ;
wire [63:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/u_ddr_phy_data_io/iserdes_dq_wire ;
wire [2:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/u_ddr_phy_data_io/rpoint ;
wire [2:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[1].u_ddr_phy_data_lane/u_ddr_phy_data_io/wpoint ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n587_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n588_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n589_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n590_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n591_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n592_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n593_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n594_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n595_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n596_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n597_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n598_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n599_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n600_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n601_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n602_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n603_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n604_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n605_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n606_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n607_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n608_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n609_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n610_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n611_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n612_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n613_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n614_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n615_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n616_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n617_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n618_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n619_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n620_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n621_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n622_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n623_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n624_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n625_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n626_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n627_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n628_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n629_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n630_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n631_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n632_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n633_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n634_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n635_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n636_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n637_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n638_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n639_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n640_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n641_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n642_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n643_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n644_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n645_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n646_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n647_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n648_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n649_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n650_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n651_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n652_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n653_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n654_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n655_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n656_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n657_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/n658_8 ;
wire [71:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/of_WrData_r ;
wire [71:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/of_WrData_rr ;
wire [71:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/of_WrData_rrr ;
wire [71:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/oserdes_dq ;
wire [63:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/iserdes_dq_Z ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/u_ddr_phy_data_io/rmove_r ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/u_ddr_phy_data_io/rdir_r ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/u_ddr_phy_data_io/ides_calib_d ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/u_ddr_phy_data_io/dqsr90 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/u_ddr_phy_data_io/dqsw0 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/u_ddr_phy_data_io/dqsw270 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/u_ddr_phy_data_io/rvalid_wire ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/u_ddr_phy_data_io/rflag_wire ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/u_ddr_phy_data_io/wflag ;
wire [71:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/u_ddr_phy_data_io/oserdes_dq_r ;
wire [71:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/u_ddr_phy_data_io/oserdes_dq_rr ;
wire [63:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/u_ddr_phy_data_io/iserdes_dq_wire ;
wire [2:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/u_ddr_phy_data_io/rpoint ;
wire [2:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[2].u_ddr_phy_data_lane/u_ddr_phy_data_io/wpoint ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n587_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n588_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n589_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n590_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n591_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n592_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n593_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n594_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n595_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n596_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n597_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n598_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n599_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n600_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n601_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n602_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n603_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n604_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n605_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n606_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n607_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n608_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n609_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n610_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n611_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n612_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n613_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n614_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n615_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n616_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n617_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n618_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n619_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n620_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n621_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n622_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n623_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n624_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n625_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n626_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n627_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n628_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n629_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n630_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n631_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n632_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n633_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n634_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n635_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n636_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n637_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n638_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n639_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n640_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n641_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n642_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n643_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n644_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n645_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n646_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n647_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n648_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n649_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n650_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n651_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n652_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n653_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n654_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n655_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n656_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n657_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/n658_8 ;
wire [71:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/of_WrData_r ;
wire [71:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/of_WrData_rr ;
wire [71:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/of_WrData_rrr ;
wire [71:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/oserdes_dq ;
wire [63:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/iserdes_dq_Z ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/u_ddr_phy_data_io/rmove_r ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/u_ddr_phy_data_io/rdir_r ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/u_ddr_phy_data_io/ides_calib_d ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/u_ddr_phy_data_io/dqsr90 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/u_ddr_phy_data_io/dqsw0 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/u_ddr_phy_data_io/dqsw270 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/u_ddr_phy_data_io/rvalid_wire ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/u_ddr_phy_data_io/rflag_wire ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/u_ddr_phy_data_io/wflag ;
wire [71:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/u_ddr_phy_data_io/oserdes_dq_r ;
wire [71:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/u_ddr_phy_data_io/oserdes_dq_rr ;
wire [63:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/u_ddr_phy_data_io/iserdes_dq_wire ;
wire [2:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/u_ddr_phy_data_io/rpoint ;
wire [2:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/data_lane_gen[3].u_ddr_phy_data_lane/u_ddr_phy_data_io/wpoint ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/u_ddr_phy_cmd_lane/n245_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/u_ddr_phy_cmd_lane/n288_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/u_ddr_phy_cmd_lane/read_line0 ;
wire [3:2] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/u_ddr_phy_cmd_lane/cmd_wr ;
wire [3:2] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/u_ddr_phy_cmd_lane/cmd_rd ;
wire [3:2] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/u_ddr_phy_cmd_lane/cmd_rd_q_reg ;
wire [3:2] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/u_ddr_phy_cmd_lane/cmd_wr_q_reg ;
wire [95:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/u_ddr_phy_cmd_lane/oserdes_d_reg ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/u_ddr_phy_cmd_lane/u_ddr_phy_cmd_io/cmd_oserdes_gen[0].u_cmd_gen_1_Q1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/u_ddr_phy_cmd_lane/u_ddr_phy_cmd_io/cmd_oserdes_gen[1].u_cmd_gen_1_Q1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/u_ddr_phy_cmd_lane/u_ddr_phy_cmd_io/cmd_oserdes_gen[2].u_cmd_gen_1_Q1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/u_ddr_phy_cmd_lane/u_ddr_phy_cmd_io/cmd_oserdes_gen[3].u_cmd_gen_1_Q1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/u_ddr_phy_cmd_lane/u_ddr_phy_cmd_io/cmd_oserdes_gen[4].u_cmd_gen_1_Q1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/u_ddr_phy_cmd_lane/u_ddr_phy_cmd_io/cmd_oserdes_gen[5].u_cmd_gen_1_Q1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/u_ddr_phy_cmd_lane/u_ddr_phy_cmd_io/cmd_oserdes_gen[6].u_cmd_gen_1_Q1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/u_ddr_phy_cmd_lane/u_ddr_phy_cmd_io/cmd_oserdes_gen[7].u_cmd_gen_1_Q1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/u_ddr_phy_cmd_lane/u_ddr_phy_cmd_io/cmd_oserdes_gen[8].u_cmd_gen_1_Q1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/u_ddr_phy_cmd_lane/u_ddr_phy_cmd_io/cmd_oserdes_gen[9].u_cmd_gen_1_Q1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/u_ddr_phy_cmd_lane/u_ddr_phy_cmd_io/cmd_oserdes_gen[10].u_cmd_gen_1_Q1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/u_ddr_phy_cmd_lane/u_ddr_phy_cmd_io/cmd_oserdes_gen[11].u_cmd_gen_1_Q1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/u_ddr_phy_cmd_lane/u_ddr_phy_cmd_io/cmd_oserdes_gen[12].u_cmd_gen_1_Q1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/u_ddr_phy_cmd_lane/u_ddr_phy_cmd_io/cmd_oserdes_gen[13].u_cmd_gen_1_Q1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/u_ddr_phy_cmd_lane/u_ddr_phy_cmd_io/cmd_oserdes_gen[14].u_cmd_gen_1_Q1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/u_ddr_phy_cmd_lane/u_ddr_phy_cmd_io/cmd_oserdes_gen[15].u_cmd_gen_1_Q1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/u_ddr_phy_cmd_lane/u_ddr_phy_cmd_io/cmd_oserdes_gen[16].u_cmd_gen_1_Q1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/u_ddr_phy_cmd_lane/u_ddr_phy_cmd_io/cmd_oserdes_gen[17].u_cmd_gen_1_Q1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/u_ddr_phy_cmd_lane/u_ddr_phy_cmd_io/cmd_oserdes_gen[18].u_cmd_gen_1_Q1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/u_ddr_phy_cmd_lane/u_ddr_phy_cmd_io/cmd_oserdes_gen[19].u_cmd_gen_1_Q1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/u_ddr_phy_cmd_lane/u_ddr_phy_cmd_io/cmd_oserdes_gen[20].u_cmd_gen_1_Q1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/u_ddr_phy_cmd_lane/u_ddr_phy_cmd_io/cmd_oserdes_gen[21].u_cmd_gen_1_Q1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/u_ddr_phy_cmd_lane/u_ddr_phy_cmd_io/cmd_oserdes_gen[22].u_cmd_gen_1_Q1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/u_ddr_phy_cmd_lane/u_ddr_phy_cmd_io/cmd_oserdes_gen[23].u_cmd_gen_1_Q1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/u_ddr_phy_cmd_lane/u_ddr_phy_cmd_io/u_ck_gen_1_Q1 ;
wire [95:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/u_ddr_phy_cmd_lane/u_ddr_phy_cmd_io/oserdes_d_r ;
wire [95:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/u_ddr_phy_cmd_lane/u_ddr_phy_cmd_io/oserdes_d_rr ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[0].fifo_ctrl/if_wbinnext_0_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[0].fifo_ctrl/if_wbinnext_1_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[0].fifo_ctrl/if_rgraynext_1_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[0].fifo_ctrl/if_rbinnext_0_11 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[0].fifo_ctrl/if_rempty_val ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[0].fifo_ctrl/n31_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[0].fifo_ctrl/n31_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[0].fifo_ctrl/n32_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[0].fifo_ctrl/n32_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[0].fifo_ctrl/n33_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[0].fifo_ctrl/n33_3 ;
wire [2:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[0].fifo_ctrl/if_rgraynext ;
wire [2:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[0].fifo_ctrl/if_wgraynext ;
wire [3:1] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[0].fifo_ctrl/if_rbinnext ;
wire [3:1] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[0].fifo_ctrl/if_wbinnext ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[0].fifo_ctrl/if_rq1_wptr ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[0].fifo_ctrl/if_rq2_wptr ;
wire [3:3] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[0].fifo_ctrl/if_rbin ;
wire [2:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[0].fifo_ctrl/if_wptr ;
wire [3:3] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[0].fifo_ctrl/if_wbin ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[1].fifo_ctrl/if_wbinnext_0_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[1].fifo_ctrl/if_wbinnext_1_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[1].fifo_ctrl/if_rgraynext_1_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[1].fifo_ctrl/if_rbinnext_0_11 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[1].fifo_ctrl/if_rempty_val ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[1].fifo_ctrl/n31_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[1].fifo_ctrl/n31_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[1].fifo_ctrl/n32_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[1].fifo_ctrl/n32_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[1].fifo_ctrl/n33_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[1].fifo_ctrl/n33_3 ;
wire [2:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[1].fifo_ctrl/if_rgraynext ;
wire [2:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[1].fifo_ctrl/if_wgraynext ;
wire [3:1] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[1].fifo_ctrl/if_rbinnext ;
wire [3:1] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[1].fifo_ctrl/if_wbinnext ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[1].fifo_ctrl/if_rq1_wptr ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[1].fifo_ctrl/if_rq2_wptr ;
wire [3:3] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[1].fifo_ctrl/if_rbin ;
wire [2:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[1].fifo_ctrl/if_wptr ;
wire [3:3] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[1].fifo_ctrl/if_wbin ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[2].fifo_ctrl/if_wbinnext_0_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[2].fifo_ctrl/if_wbinnext_1_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[2].fifo_ctrl/if_rgraynext_1_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[2].fifo_ctrl/if_rbinnext_0_11 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[2].fifo_ctrl/if_rempty_val ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[2].fifo_ctrl/n31_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[2].fifo_ctrl/n31_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[2].fifo_ctrl/n32_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[2].fifo_ctrl/n32_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[2].fifo_ctrl/n33_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[2].fifo_ctrl/n33_3 ;
wire [2:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[2].fifo_ctrl/if_rgraynext ;
wire [2:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[2].fifo_ctrl/if_wgraynext ;
wire [3:1] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[2].fifo_ctrl/if_rbinnext ;
wire [3:1] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[2].fifo_ctrl/if_wbinnext ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[2].fifo_ctrl/if_rq1_wptr ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[2].fifo_ctrl/if_rq2_wptr ;
wire [3:3] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[2].fifo_ctrl/if_rbin ;
wire [2:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[2].fifo_ctrl/if_wptr ;
wire [3:3] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[2].fifo_ctrl/if_wbin ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[3].fifo_ctrl/if_wbinnext_0_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[3].fifo_ctrl/if_wbinnext_1_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[3].fifo_ctrl/if_rgraynext_1_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[3].fifo_ctrl/if_rbinnext_0_11 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[3].fifo_ctrl/if_rempty_val ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[3].fifo_ctrl/n31_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[3].fifo_ctrl/n31_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[3].fifo_ctrl/n32_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[3].fifo_ctrl/n32_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[3].fifo_ctrl/n33_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[3].fifo_ctrl/n33_3 ;
wire [2:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[3].fifo_ctrl/if_rgraynext ;
wire [2:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[3].fifo_ctrl/if_wgraynext ;
wire [3:1] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[3].fifo_ctrl/if_rbinnext ;
wire [3:1] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[3].fifo_ctrl/if_wbinnext ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[3].fifo_ctrl/if_rq1_wptr ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[3].fifo_ctrl/if_rq2_wptr ;
wire [3:3] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[3].fifo_ctrl/if_rbin ;
wire [2:0] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[3].fifo_ctrl/if_wptr ;
wire [3:3] \gw3_top/u_ddr_phy_top/u_ddr_phy_wds/fifo_ctrl_gen[3].fifo_ctrl/if_wbin ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n113_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n114_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n176_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n295_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n357_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n476_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n538_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n657_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n719_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n68_4 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n176_4 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n114_1_4 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n295_1_4 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n476_1_4 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n657_1_4 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/realtime_dllcode_31_7 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/realtime_dllcode_23_7 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/realtime_dllcode_15_7 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/realtime_dllcode_7_7 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n693_6 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n692_6 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n691_6 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n690_6 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n689_6 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n688_6 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n687_6 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n686_6 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n512_6 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n511_6 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n510_6 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n509_6 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n508_6 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n507_6 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n506_6 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n505_6 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n331_6 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n330_6 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n329_6 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n328_6 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n327_6 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n326_6 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n325_6 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n324_6 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n150_6 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n149_6 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n148_6 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n147_6 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n146_6 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n145_6 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n144_6 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n143_6 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n77_8 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n68_6 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n258_8 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n249_5 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n439_8 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n430_5 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n620_8 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n611_5 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n801_8 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n792_5 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n106_5 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n288_5 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n469_5 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n650_5 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n831_5 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/init_rmove_start_rr ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/init_rmove_done_rr ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/rmove_start ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/init_rmove_done_Z ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/init_rmove_start_r ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n142_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n142_1_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n141_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n141_1_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n140_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n140_1_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n139_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n139_1_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n138_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n138_1_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n137_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n137_1_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n136_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n136_1_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n135_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n135_1_0_COUT ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n323_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n323_1_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n322_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n322_1_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n321_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n321_1_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n320_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n320_1_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n319_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n319_1_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n318_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n318_1_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n317_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n317_1_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n316_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n316_1_0_COUT ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n504_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n504_1_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n503_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n503_1_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n502_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n502_1_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n501_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n501_1_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n500_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n500_1_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n499_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n499_1_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n498_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n498_1_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n497_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n497_1_0_COUT ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n685_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n685_1_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n684_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n684_1_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n683_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n683_1_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n682_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n682_1_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n681_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n681_1_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n680_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n680_1_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n679_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n679_1_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n678_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n678_1_0_COUT ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n76_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n76_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n75_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n75_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n74_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n74_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n73_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n73_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n72_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n72_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n71_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n71_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n70_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n70_0_COUT ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n257_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n257_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n256_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n256_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n255_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n255_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n254_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n254_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n253_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n253_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n252_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n252_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n251_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n251_0_COUT ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n438_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n438_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n437_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n437_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n436_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n436_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n435_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n435_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n434_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n434_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n433_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n433_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n432_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n432_0_COUT ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n619_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n619_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n618_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n618_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n617_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n617_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n616_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n616_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n615_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n615_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n614_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n614_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n613_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n613_0_COUT ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n800_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n800_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n799_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n799_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n798_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n798_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n797_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n797_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n796_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n796_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n795_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n795_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n794_1 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n794_0_COUT ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n44_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n44_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n43_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n43_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n42_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n42_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n41_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n41_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n40_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n40_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n39_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n39_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n38_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n38_0_COUT ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n57_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n57_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n58_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n58_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n59_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n59_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n60_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n60_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n61_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n61_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n62_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n62_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n63_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n63_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n64_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n65_2 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n57_2_SUM ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n57_5 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n58_2_SUM ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n58_5 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n59_2_SUM ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n59_5 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n60_2_SUM ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n60_5 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n61_2_SUM ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n61_5 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n62_2_SUM ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n62_5 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n63_2_SUM ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n63_5 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n278_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n278_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n279_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n279_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n280_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n280_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n281_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n281_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n282_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n282_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n283_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n283_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n284_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n284_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n459_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n459_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n460_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n460_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n461_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n461_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n462_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n462_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n463_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n463_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n464_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n464_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n465_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n465_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n640_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n640_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n641_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n641_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n642_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n642_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n643_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n643_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n644_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n644_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n645_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n645_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n646_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n646_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n821_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n821_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n822_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n822_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n823_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n823_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n824_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n824_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n825_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n825_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n826_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n826_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n827_1_SUM ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n827_3 ;
wire \gw3_top/u_ddr_phy_top/u_init_rmove_mod/n45_7 ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_init_rmove_mod/read_calib_rmove_r ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_init_rmove_mod/read_calib_rmove_rr ;
wire [7:0] \gw3_top/u_ddr_phy_top/u_init_rmove_mod/dllstep_r ;
wire [7:0] \gw3_top/u_ddr_phy_top/u_init_rmove_mod/STATIC_RMOVE_TIMES ;
wire [7:0] \gw3_top/u_ddr_phy_top/u_init_rmove_mod/init_rmove_cnt ;
wire [7:0] \gw3_top/u_ddr_phy_top/u_init_rmove_mod/rdir_gen[0].rigth_stop ;
wire [7:0] \gw3_top/u_ddr_phy_top/u_init_rmove_mod/rdir_gen[0].add_rmove_cnt ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_init_rmove_mod/sys_reset_ch ;
wire [7:0] \gw3_top/u_ddr_phy_top/u_init_rmove_mod/rdir_gen[1].add_rmove_cnt ;
wire [7:0] \gw3_top/u_ddr_phy_top/u_init_rmove_mod/rdir_gen[2].add_rmove_cnt ;
wire [7:0] \gw3_top/u_ddr_phy_top/u_init_rmove_mod/rdir_gen[3].add_rmove_cnt ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n117_3 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n139_3 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n156_3 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n157_3 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n158_3 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n159_3 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n160_3 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n161_3 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n162_3 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n163_3 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n243_3 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n409_3 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n410_3 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n411_3 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n412_3 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n413_3 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n414_3 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n415_3 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n416_3 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n496_3 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n662_3 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n663_3 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n664_3 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n665_3 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n666_3 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n667_3 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n668_3 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n669_3 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n749_3 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n915_3 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n916_3 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n917_3 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n918_3 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n919_3 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n920_3 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n921_3 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n922_3 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n1002_3 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/realtime_dllcode_rr_7_8 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/realtime_dllcode_rr_15_8 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/realtime_dllcode_rr_23_8 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/realtime_dllcode_rr_31_8 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n265_36 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n518_36 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n771_36 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n1024_36 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n943_38 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n690_38 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n437_38 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n184_38 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n1048_7 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n1046_7 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n1044_7 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n795_7 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n793_7 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n792_7 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n791_7 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n542_7 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n540_7 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n539_7 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n538_7 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n289_7 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n287_7 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n286_7 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n285_7 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n953_6 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n700_6 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n447_6 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n194_6 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n_s.EYE_CALIB_STOP ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n124_4 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n139_4 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n156_4 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n157_4 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n158_4 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n159_4 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n161_4 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n409_4 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n410_4 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n411_4 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n412_4 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n414_4 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n662_4 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n663_4 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n664_4 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n665_4 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n667_4 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n915_4 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n916_4 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n917_4 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n918_4 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n920_4 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n265_37 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n265_38 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n518_37 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n518_38 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n771_37 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n771_38 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n1024_37 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n1024_38 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n943_39 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n690_39 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n437_39 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n184_39 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n1051_8 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n1049_8 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n1045_8 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n798_8 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n796_8 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n792_8 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n545_8 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n543_8 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n539_8 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n292_8 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n290_8 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n286_8 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/c_s.RIGHT_MOVE_9 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n160_6 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n285_10 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n413_6 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n538_10 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n666_6 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n791_10 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n919_6 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n1047_10 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n1049_10 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n288_10 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n290_10 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n541_10 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n543_10 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n794_10 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n796_10 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/eye_calib_gen[3].cor_cnt_7_8 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/eye_calib_gen[2].cor_cnt_7_8 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/eye_calib_gen[1].cor_cnt_7_8 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/eye_calib_gen[0].cor_cnt_7_9 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n1045_10 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n1047_12 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n1050_9 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n1051_10 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n288_12 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n291_9 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n292_10 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n541_12 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n544_9 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n545_10 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n794_12 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n797_9 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n798_10 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n209_12 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n210_8 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n462_12 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n463_8 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n715_12 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n716_8 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n968_12 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n969_8 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n_s.LEFT_EDGE_MOVE_19 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n124_7 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/n124_9 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/c_s.EYE_CALIB_STOP ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/rmove_left_flag_r ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/c_s.IDLE ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/c_s.LEFT_EDGE_MOVE ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/c_s.RIGHT_MOVE ;
wire [3:3] \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/eye_calib_error_valid_r ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/eye_calib_error_r ;
wire [3:3] \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/eye_calib_error_valid_rr ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/eye_calib_error_rr ;
wire [3:3] \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/eye_calib_error_valid_rrr ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/eye_calib_error_rrr ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/rmove_r ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/rmove_rr ;
wire [31:0] \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/realtime_dllcode_r ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/rflag_r ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/screen_valid ;
wire [7:0] \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/eye_calib_gen[0].cor_cnt ;
wire [7:0] \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/eye_calib_gen[1].cor_cnt ;
wire [7:0] \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/eye_calib_gen[2].cor_cnt ;
wire [7:0] \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/eye_calib_gen[3].cor_cnt ;
wire [31:0] \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/realtime_dllcode_rr ;
wire [1:0] \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/eye_calib_gen[0].rmove_cnt ;
wire [1:0] \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/eye_calib_gen[1].rmove_cnt ;
wire [1:0] \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/eye_calib_gen[2].rmove_cnt ;
wire [1:0] \gw3_top/u_ddr_phy_top/u_eye_calib_rmove_mod/eye_calib_gen[3].rmove_cnt ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n2855_3 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/row1_2_7 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n5521_3 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n5532_3 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n5696_5 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n5697_4 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n5571_5 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n5614_5 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/col1_3_8 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n_s.WR_BURST ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n_s.WR_CONTI_17 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n_s.RD_BURST_17 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n5717_6 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n5499_6 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n5497_6 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n5496_6 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n5495_6 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n5800_7 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n5798_7 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n5648_8 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n5647_8 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n5645_9 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n4923_18 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n4920_17 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n5846_6 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n4956_17 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/c_s.WAIT_RMOVE_8 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_0_8 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_0_8 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_0_8 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_0_8 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_1_8 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_1_8 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_1_8 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_1_8 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_2_8 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_3_8 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n5521_4 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n_s.WR_BURST_11 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n5498_7 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n5801_8 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n5646_9 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n5846_7 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n5846_8 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_0_9 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_0_10 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_0_11 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_0_12 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_0_9 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_0_10 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_0_9 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_0_10 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_0_9 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_0_10 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_1_9 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_1_10 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_1_9 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_1_10 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_1_9 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_1_10 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_1_9 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_1_10 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_2_9 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_2_9 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_2_9 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_2_10 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_2_9 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_3_9 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_3_9 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_3_10 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_3_9 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_3_9 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n5698_7 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n5648_10 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_0_13 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_0_14 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_0_15 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_0_16 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_0_17 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_0_18 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_0_11 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_0_12 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_0_13 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_0_14 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_0_15 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_0_16 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_0_11 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_0_12 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_0_13 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_0_14 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_0_15 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_0_16 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_0_12 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_0_13 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_0_14 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_0_15 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_0_16 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_0_17 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_1_11 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_1_12 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_1_13 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_1_14 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_1_15 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_1_16 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_1_17 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_1_11 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_1_12 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_1_13 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_1_14 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_1_15 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_1_16 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_1_11 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_1_12 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_1_13 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_1_14 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_1_11 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_1_12 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_1_13 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_1_14 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_2_10 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_2_11 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_2_12 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_2_10 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_2_11 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_2_11 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_2_12 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_2_13 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_2_14 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_2_10 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_2_11 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_3_10 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_3_11 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_3_12 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_3_13 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_3_12 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_3_13 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_3_14 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_3_15 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_3_10 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_3_11 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_3_12 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_3_13 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_3_10 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_3_11 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_3_12 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_3_13 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_0_19 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_0_20 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_0_21 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_0_22 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_0_23 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_0_24 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_0_25 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_0_17 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_0_18 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_0_19 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_0_20 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_0_21 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_0_22 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_0_17 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_0_18 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_0_19 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_0_20 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_0_21 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_0_22 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_0_23 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_0_18 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_0_19 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_0_20 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_0_21 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_0_22 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_0_23 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_0_24 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_1_18 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_1_19 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_1_20 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_1_17 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_1_18 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_1_19 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_1_20 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_1_15 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_1_16 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_1_17 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_1_18 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_1_19 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_1_15 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_1_16 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_1_17 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_1_18 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_1_19 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_2_13 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_2_14 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_2_15 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_2_16 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_2_17 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_2_18 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_2_19 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_2_20 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_2_21 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_2_12 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_2_13 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_2_14 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_2_15 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_2_16 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_2_17 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_2_15 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_2_16 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_2_17 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_2_18 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_2_19 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_2_20 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_2_21 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_2_22 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_2_12 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_2_13 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_2_14 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_2_15 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_2_16 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_3_14 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_3_15 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_3_16 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_3_17 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_3_18 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_3_19 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_3_17 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_3_18 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_3_19 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_3_20 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_3_21 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_3_22 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_3_23 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_3_14 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_3_15 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_3_16 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_3_17 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_3_18 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_3_19 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_3_14 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_3_15 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_3_16 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_3_17 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_3_18 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_3_19 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_0_26 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_0_27 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_0_23 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_0_24 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_0_25 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_0_26 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_0_24 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_0_25 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_0_25 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_1_21 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_1_22 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_1_21 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_1_22 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_1_20 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_1_20 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_2_22 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_2_23 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_2_24 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_2_25 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_2_18 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_2_19 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_2_20 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_2_21 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_2_22 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_2_23 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_2_24 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_2_23 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_2_24 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_2_17 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_2_18 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_2_19 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_2_20 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_2_21 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_2_22 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_2_23 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_3_20 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_3_21 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_3_22 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_3_23 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_3_24 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_3_24 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_3_25 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_3_20 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_3_21 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_3_22 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_3_23 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_3_24 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_3_20 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_3_21 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_3_22 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_3_23 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_3_24 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_3_27 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n4964_19 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n4962_18 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n5547_5 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n5646_11 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n5698_9 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n4929_16 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n5496_9 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n5498_9 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n5799_10 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n5801_10 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n5696_10 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n5648_12 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/c_s.RD_CONTI_9 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n4954_20 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_3_29 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_0_27 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4_3_26 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3_3_26 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_3_26 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2_2_26 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1_2_27 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n5494_9 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/timeout_6_15 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n5500_9 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n5802_10 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/cnt_r[0]_1_14 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n5803_10 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n5799_13 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n_s.RMOVE_LEFT_19 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n7237_15 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n_s.WAIT_RMOVE_18 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n_s.RD_CONTI_19 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/c_s.WR_CONTI_10 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_rmove_r ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_rdata_valid_r ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/eye_rdata_valid_rr ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/rmove_left_done_r ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/clr_error ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/c_s.WR_BURST ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/timeout_flg ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/timeout_flg_r ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/timeout_flg_pulse ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/c_s.WAIT_RMOVE ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/c_s.WR_CONTI ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/c_s.RD_BURST ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/c_s.RD_CONTI ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/c_s.IDLE ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/c_s.RMOVE_LEFT ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n5718_9 ;
wire \gw3_top/u_ddr_phy_top/u_eye_calib/n7237_18 ;
wire [255:0] \gw3_top/u_ddr_phy_top/u_eye_calib/eye_rdata_r ;
wire [1:0] \gw3_top/u_ddr_phy_top/u_eye_calib/cnt ;
wire [6:0] \gw3_top/u_ddr_phy_top/u_eye_calib/timeout ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_eye_calib/col1 ;
wire [2:0] \gw3_top/u_ddr_phy_top/u_eye_calib/row1 ;
wire [5:2] \gw3_top/u_ddr_phy_top/u_eye_calib/cnt_stop ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error1 ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error2 ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error3 ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_eye_calib/eye_calib_error4 ;
wire [1:0] \gw3_top/u_ddr_phy_top/u_eye_calib/cnt_r[0] ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n349_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n424_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n613_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n730_4 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/cke_en ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1431_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1782_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1832_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1882_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1932_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2371_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2387_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_calibration_logic_gen[0].rburst_t ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2523_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2862_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2684_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2740_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2749_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2900_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_calibration_logic_gen[1].rburst_t ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2932_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3271_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3093_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3149_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3158_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3309_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_calibration_logic_gen[2].rburst_t ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3341_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3680_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3502_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3558_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3567_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3718_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_calibration_logic_gen[3].rburst_t ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3750_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n4089_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3911_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3967_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3976_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n4127_3 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2622_28 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2623_23 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2624_22 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2625_23 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3031_28 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3032_23 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3033_22 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3034_23 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3440_28 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3441_23 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3442_22 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3443_23 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3849_28 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3850_23 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3851_22 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3852_23 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/repeat_done_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/timer_cnt0_7_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/rburst_cnt_9_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/readback_check_0_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/rburst_cnt_19_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/readback_check_1_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/rburst_cnt_29_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/readback_check_2_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/rburst_cnt_39_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/readback_check_3_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.LOAD_MR ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.WRLVL_LOAD_MR1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.WRLVL_LOAD_MR2 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.WRITE_LEVELING ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.WRLVL_MODE_CLOSE1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.WRLVL_MODE_CLOSE2 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.BURST_MODE_RECOVER ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.ZQCL ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.IDLE ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.RESET_WAIT ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.XPR_WAIT ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.LOAD_MR_WAIT ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.ZQCL_WAIT ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.WRLVL_LOAD_MR2_WAIT ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.WRLVL_LOAD_MR1_WAIT ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.WRLVL_MODE_CLOSE1_WAIT ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.READ_CALIBRATION ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.EYE_SCAN ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.INIT_DONE ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/wrlvl_next_state.WRLVL_SEND_DQS ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/wrlvl_next_state.WRLVL_DONE ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_next_state.READ_CAL_WRITE_CMD ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_next_state.READ_CAL_READ_CMD ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_next_state.READ_CAL_ACTIVE_CMD ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_next_state.READ_CAL_PRECHARGE ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_next_state.READ_CAL_WAIT ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_next_state.READ_CAL_HOLD ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_next_state.READ_CAL_READ_CMD_WAIT ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_next_state.READ_CAL_WRITE_CMD_WAIT ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_next_state.READ_CAL_ACTIVE_CMD_WAIT ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_next_state.READ_CAL_RSEL_ADJ_WAIT ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_next_state.READ_CAL_PRECHARGE_WAIT ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_next_state.READ_CAL_RBURST_CHECK ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_next_state.READ_CAL_RBURST_CHECK_WAIT ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_next_state.READ_CAL_RBURST_CHECK_WAIT1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_next_state.READ_CAL_RSEL_ADJ ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_next_state.READ_CAL_DONE ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/wrlvl_next_state.WRLVL_ODT_EN_16 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/wrlvl_next_state.WRLVL_ODT_DIS_17 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/wrlvl_next_state.WRLVL_SEND_DQS_WAIT_17 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/wrlvl_next_state.WRLVL_ADJ_WAIT_17 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/wrlvl_next_state.WRLVL_IDLE_16 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/wrlvl_next_state.WRLVL_READ_DQ_16 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/wrlvl_next_state.WRLVL_RECHECK_DQ_17 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/wrlvl_next_state.WRLVL_ADJ_DQS_17 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3939_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3938_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3936_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3935_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3934_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3933_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3932_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3931_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3930_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3880_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3878_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3877_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3875_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3874_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3774_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3530_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3529_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3527_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3526_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3525_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3524_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3523_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3522_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3521_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3471_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3469_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3468_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3466_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3465_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3365_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3121_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3120_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3118_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3117_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3116_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3115_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3114_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3113_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3112_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3062_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3060_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3059_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3057_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3056_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2956_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2712_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2711_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2709_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2708_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2707_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2706_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2705_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2704_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2703_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2653_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2651_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2650_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2648_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2647_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2547_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2326_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2324_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2323_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2322_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1755_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1514_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1513_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1511_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1510_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1508_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1507_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n4100_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n4099_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n4098_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n4097_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3837_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3835_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3834_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3691_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3690_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3689_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3688_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3428_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3426_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3425_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3282_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3281_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3280_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3279_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3019_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3017_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3016_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2873_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2872_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2871_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2870_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2610_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2608_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2607_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1456_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1455_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1453_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1452_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1451_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1450_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1449_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1448_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1447_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n460_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n458_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2836_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3245_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3654_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n4063_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1536_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2571_4 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2980_4 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3389_4 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3798_4 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n613_4 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n617_4 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n617_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n730_5 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1431_4 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1431_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1431_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2387_4 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2387_5 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2523_4 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2862_4 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2598_4 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2684_4 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2684_5 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2740_4 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2740_5 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2749_4 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2900_4 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2932_4 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3271_4 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3007_4 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3093_4 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3093_5 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3149_4 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3149_5 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3158_4 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3309_4 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3341_4 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3680_4 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3416_4 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3502_4 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3502_5 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3558_4 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3558_5 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3567_4 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3718_4 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3750_4 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n4089_4 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3825_4 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3911_4 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3911_5 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3967_4 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3967_5 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3976_4 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n4127_4 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n4177_4 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2622_29 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2622_30 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2623_24 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2623_25 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2624_23 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2624_24 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2625_24 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2625_25 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3031_29 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3031_30 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3032_24 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3032_25 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3033_23 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3033_24 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3034_25 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3440_29 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3440_30 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3441_24 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3441_25 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3442_23 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3442_24 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3443_25 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3849_29 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3849_30 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3850_24 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3850_25 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3851_23 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3851_24 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3852_24 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3852_25 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_calibration_logic_gen[0].cal_cnt_3_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/rburst_cnt_9_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_calibration_logic_gen[1].cal_cnt_3_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_calibration_logic_gen[2].cal_cnt_3_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_calibration_logic_gen[3].cal_cnt_3_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.LOAD_MR_24 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.LOAD_MR_25 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.WRLVL_LOAD_MR2_23 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.WRITE_LEVELING_23 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.ZQCL_24 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.ZQCL_25 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.IDLE_23 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.CKE_EN_23 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/wrlvl_next_state.WRLVL_SEND_DQS_18 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/wrlvl_next_state.WRLVL_SEND_DQS_19 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_next_state.READ_CAL_WRITE_CMD_23 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_next_state.READ_CAL_WRITE_CMD_24 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_next_state.READ_CAL_READ_CMD_22 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_next_state.READ_CAL_ACTIVE_CMD_23 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_next_state.READ_CAL_PRECHARGE_24 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_next_state.READ_CAL_RBURST_CHECK_23 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_next_state.READ_CAL_RSEL_ADJ_23 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_next_state.READ_CAL_DONE_24 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/wrlvl_next_state.WRLVL_ODT_DIS_19 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/wrlvl_next_state.WRLVL_ADJ_DQS_18 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3937_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3930_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3881_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3874_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3777_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3775_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3528_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3521_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3472_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3465_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3368_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3366_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3119_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3112_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3063_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3056_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2959_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2957_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2710_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2703_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2654_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2647_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2550_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2548_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2327_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2323_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1754_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1512_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1509_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1509_10 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1454_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1452_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1448_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n459_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n620_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2836_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3245_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3654_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n4063_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1431_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1431_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2684_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2740_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2900_5 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3093_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3149_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3309_5 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3502_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3558_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3718_5 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3911_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3967_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n4127_5 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n4177_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n4177_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2623_26 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3032_26 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3441_26 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3850_26 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/timer_cnt0_7_11 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.LOAD_MR_27 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.LOAD_MR_28 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.LOAD_MR_29 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.LOAD_MR_30 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.WRLVL_LOAD_MR2_24 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.WRLVL_LOAD_MR2_25 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.WRLVL_LOAD_MR2_26 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.WRITE_LEVELING_24 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.WRITE_LEVELING_25 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.WRITE_LEVELING_26 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.ZQCL_26 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.CKE_EN_24 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/wrlvl_next_state.WRLVL_SEND_DQS_20 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/wrlvl_next_state.WRLVL_SEND_DQS_21 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/wrlvl_next_state.WRLVL_SEND_DQS_22 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/wrlvl_next_state.WRLVL_DONE_19 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_next_state.READ_CAL_WRITE_CMD_25 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_next_state.READ_CAL_WRITE_CMD_26 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_next_state.READ_CAL_WRITE_CMD_27 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_next_state.READ_CAL_WRITE_CMD_28 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_next_state.READ_CAL_READ_CMD_23 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_next_state.READ_CAL_READ_CMD_24 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_next_state.READ_CAL_ACTIVE_CMD_24 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_next_state.READ_CAL_RBURST_CHECK_24 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_next_state.READ_CAL_RBURST_CHECK_25 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_next_state.READ_CAL_RSEL_ADJ_24 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/wrlvl_next_state.WRLVL_ODT_WAIT_19 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2836_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2836_10 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2836_11 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2836_12 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3245_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3245_10 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3245_11 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3245_12 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3654_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3654_10 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3654_11 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3654_12 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n4063_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n4063_10 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n4063_11 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n4063_12 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.LOAD_MR_31 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.LOAD_MR_32 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.LOAD_MR_33 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.RESET_WAIT_25 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.RESET_WAIT_26 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/wrlvl_next_state.WRLVL_SEND_DQS_23 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_next_state.READ_CAL_WRITE_CMD_29 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_next_state.READ_CAL_WRITE_CMD_30 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_next_state.READ_CAL_WRITE_CMD_31 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_next_state.READ_CAL_WRITE_CMD_32 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_next_state.READ_CAL_READ_CMD_25 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2836_13 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2836_14 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2836_15 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2836_16 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2836_17 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2836_18 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2836_19 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2836_20 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2836_21 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2836_22 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2836_23 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2836_24 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2836_25 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2836_26 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2836_27 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2836_28 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3245_13 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3245_14 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3245_15 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3245_16 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3245_17 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3245_18 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3245_19 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3245_20 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3245_21 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3245_22 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3245_23 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3245_24 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3245_25 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3245_26 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3245_27 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3245_28 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3654_13 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3654_14 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3654_15 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3654_16 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3654_17 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3654_18 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3654_19 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3654_20 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3654_21 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3654_22 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3654_23 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3654_24 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3654_25 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3654_26 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3654_27 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3654_28 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n4063_13 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n4063_14 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n4063_15 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n4063_16 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n4063_17 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n4063_18 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n4063_19 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n4063_20 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n4063_21 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n4063_22 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n4063_23 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n4063_24 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n4063_25 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n4063_26 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n4063_27 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n4063_28 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.LOAD_MR_35 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.RESET_WAIT_28 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n731_5 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/wrlvl_next_state.WRLVL_ODT_DIS_21 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2322_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2548_10 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2957_10 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3366_10 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/phy_odt_pre_1_10 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3775_10 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n4177_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n600_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/timer_cnt0_7_13 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/wrlvl_next_state.WRLVL_DONE_23 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/wrlvl_next_state.WRLVL_ODT_DIS_WAIT_19 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/wrlvl_next_state.WRLVL_ODT_WAIT_21 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_next_state.READ_CAL_ACTIVE_CMD_27 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1431_13 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1454_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1510_11 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1512_11 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2325_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2327_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2652_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2654_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2649_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2708_10 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2710_10 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2705_10 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3061_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3063_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3058_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3117_10 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3119_10 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3114_10 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3470_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3472_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3467_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3526_10 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3528_10 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3523_10 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3879_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3881_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3876_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3935_10 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3937_10 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3932_10 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n620_10 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n461_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n459_11 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n601_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n618_5 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n617_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1782_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2549_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2958_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3034_27 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3367_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3443_27 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3776_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1450_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n613_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/timer_cnt0_7_15 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1509_12 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_next_state.CKE_EN ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1514_11 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/rvalid_cnt_39_11 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/rvalid_cnt_29_11 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/rvalid_cnt_19_11 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/rvalid_cnt_9_11 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_next_state.READ_CAL_IDLE ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1799_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1790_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1849_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1840_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1899_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1890_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1949_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1940_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2572_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2569_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2573_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2609_10 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2598_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2981_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2978_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2982_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3018_10 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3007_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3390_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3387_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3391_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3427_10 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3416_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3799_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3796_7 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3800_8 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3836_10 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3825_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1754_10 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/wrlvl_sendDQS_Counter_3_14 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1756_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1757_10 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1772_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1822_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1872_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1922_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2300_10 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2325_12 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cmd_cnt_7_12 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2328_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2329_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2550_14 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_calibration_logic_gen[0].cal_cnt_3_11 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2649_12 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2652_12 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2655_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2656_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2758_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2759_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2759_11 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2959_14 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_calibration_logic_gen[1].cal_cnt_3_11 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3058_12 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3061_12 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3064_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3065_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3167_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3168_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3168_11 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3368_14 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_calibration_logic_gen[2].cal_cnt_3_11 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3467_12 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3470_12 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3473_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3474_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3576_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3577_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3577_11 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3777_14 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_calibration_logic_gen[3].cal_cnt_3_11 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3876_12 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3879_12 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3882_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3883_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3985_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3986_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n3986_11 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n460_10 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n611_9 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/rvalid_cnt_19_18 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/rvalid_cnt_29_18 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/rvalid_cnt_39_18 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/rvalid_cnt_9_18 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cmd0 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cmd ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_state.LOAD_MR ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_state.WRLVL_LOAD_MR1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_state.WRLVL_LOAD_MR2 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_state.WRITE_LEVELING ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_state.WRLVL_MODE_CLOSE1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_state.WRLVL_MODE_CLOSE2 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_state.BURST_MODE_RECOVER ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_state.ZQCL ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_state.IDLE ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_state.RESET_WAIT ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_state.CKE_EN ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_state.XPR_WAIT ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_state.LOAD_MR_WAIT ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_state.ZQCL_WAIT ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_state.WRLVL_LOAD_MR2_WAIT ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_state.WRLVL_LOAD_MR1_WAIT ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_state.WRLVL_MODE_CLOSE1_WAIT ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_state.READ_CALIBRATION ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_state.EYE_SCAN ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/init_state.INIT_DONE ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/timer_go ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/repeat_done ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/wrlvl_state.WRLVL_ODT_EN ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/wrlvl_state.WRLVL_ODT_DIS ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/wrlvl_state.WRLVL_SEND_DQS_WAIT ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/wrlvl_state.WRLVL_ODT_WAIT ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/wrlvl_state.WRLVL_ODT_DIS_WAIT ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/wrlvl_state.WRLVL_ADJ_WAIT ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/wrlvl_state.WRLVL_IDLE ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/wrlvl_state.WRLVL_SEND_DQS ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/wrlvl_state.WRLVL_READ_DQ ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/wrlvl_state.WRLVL_RECHECK_DQ ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/wrlvl_state.WRLVL_ADJ_DQS ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/wrlvl_state.WRLVL_DONE ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_state.READ_CAL_WRITE_CMD ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_state.READ_CAL_READ_CMD ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_state.READ_CAL_ACTIVE_CMD ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_state.READ_CAL_PRECHARGE ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_state.READ_CAL_WAIT ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_state.READ_CAL_HOLD ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_state.READ_CAL_READ_CMD_WAIT ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_state.READ_CAL_WRITE_CMD_WAIT ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_state.READ_CAL_ACTIVE_CMD_WAIT ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_state.READ_CAL_RSEL_ADJ_WAIT ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_state.READ_CAL_PRECHARGE_WAIT ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_state.READ_CAL_IDLE ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_state.READ_CAL_RBURST_CHECK ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_state.READ_CAL_RBURST_CHECK_WAIT ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_state.READ_CAL_RBURST_CHECK_WAIT1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_state.READ_CAL_RSEL_ADJ ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_state.READ_CAL_DONE ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/rvalid_cnt_clr ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cmd_cnt_clr ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/hold_gen[0].hold_i ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/hold_gen[1].hold_i ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/hold_gen[2].hold_i ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/hold_gen[3].hold_i ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_calibration_logic_gen[0].rburst_pos ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_calibration_logic_gen[0].rburst_neg ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_calibration_logic_gen[0].rburst_neg_r ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_calibration_logic_gen[0].rburst_t_r ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_calibration_logic_gen[0].read_cal_done ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_calibration_logic_gen[1].rburst_pos ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_calibration_logic_gen[1].rburst_neg ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_calibration_logic_gen[1].rburst_neg_r ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_calibration_logic_gen[1].rburst_t_r ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_calibration_logic_gen[1].read_cal_done ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_calibration_logic_gen[2].rburst_pos ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_calibration_logic_gen[2].rburst_neg ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_calibration_logic_gen[2].rburst_neg_r ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_calibration_logic_gen[2].rburst_t_r ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_calibration_logic_gen[2].read_cal_done ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_calibration_logic_gen[3].rburst_pos ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_calibration_logic_gen[3].rburst_neg ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_calibration_logic_gen[3].rburst_neg_r ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_calibration_logic_gen[3].rburst_t_r ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_calibration_logic_gen[3].read_cal_done ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cal_complete ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/read_cmd_wait_ov ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/filter_first_burst ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1798_1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1798_2 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1797_1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1797_2 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1796_1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1796_2 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1795_1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1795_2 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1794_1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1794_2 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1793_1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1793_2 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1792_1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1792_0_COUT ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1848_1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1848_2 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1847_1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1847_2 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1846_1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1846_2 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1845_1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1845_2 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1844_1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1844_2 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1843_1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1843_2 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1842_1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1842_0_COUT ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1898_1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1898_2 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1897_1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1897_2 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1896_1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1896_2 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1895_1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1895_2 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1894_1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1894_2 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1893_1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1893_2 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1892_1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1892_0_COUT ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1948_1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1948_2 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1947_1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1947_2 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1946_1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1946_2 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1945_1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1945_2 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1944_1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1944_2 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1943_1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1943_2 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1942_1 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1942_0_COUT ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n470_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/phy_reset_n_c_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n2497_6 ;
wire \gw3_top/u_ddr_phy_top/u_ddr_init/n1537_6 ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_ddr_init/phy_rdbk_data_valid_r ;
wire [255:0] \gw3_top/u_ddr_phy_top/u_ddr_init/phy_rdbk_data_r ;
wire [12:0] \gw3_top/u_ddr_phy_top/u_ddr_init/read_cmd1 ;
wire [9:0] \gw3_top/u_ddr_phy_top/u_ddr_init/timer_cnt ;
wire [1:0] \gw3_top/u_ddr_phy_top/u_ddr_init/repeat_cnt ;
wire [2:0] \gw3_top/u_ddr_phy_top/u_ddr_init/ddr_init_complete_d ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_ddr_init/ddr_init_complete_inter ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_ddr_init/edge_pos ;
wire [31:0] \gw3_top/u_ddr_phy_top/u_ddr_init/wstep_reg ;
wire [31:0] \gw3_top/u_ddr_phy_top/u_ddr_init/wstep_reg_d ;
wire [3:3] \gw3_top/u_ddr_phy_top/u_ddr_init/read_line ;
wire [0:0] \gw3_top/u_ddr_phy_top/u_ddr_init/hold_gen[0].hold_reg ;
wire [6:0] \gw3_top/u_ddr_phy_top/u_ddr_init/hold_gen[0].hold_reg_d ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_ddr_init/rburst_reg ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_ddr_init/read_calibration_logic_gen[0].read_i ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_ddr_init/rvalid_cnt_check ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_ddr_init/rburst_cnt_check ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_ddr_init/read_rclksel_conf ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_ddr_init/read_calibration_logic_gen[0].ides_calib_cnt ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_ddr_init/read_calibration_logic_gen[1].read_i ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_ddr_init/read_calibration_logic_gen[1].ides_calib_cnt ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_ddr_init/read_calibration_logic_gen[2].read_i ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_ddr_init/read_calibration_logic_gen[2].ides_calib_cnt ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_ddr_init/read_calibration_logic_gen[3].read_i ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_ddr_init/read_calibration_logic_gen[3].ides_calib_cnt ;
wire [7:0] \gw3_top/u_ddr_phy_top/u_ddr_init/timer_cnt0 ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_ddr_init/wrlvl_sendDQS_Counter ;
wire [7:0] \gw3_top/u_ddr_phy_top/u_ddr_init/read_cmd_cnt ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_ddr_init/read_calibration_logic_gen[0].cal_cnt ;
wire [39:0] \gw3_top/u_ddr_phy_top/u_ddr_init/rvalid_cnt ;
wire [39:0] \gw3_top/u_ddr_phy_top/u_ddr_init/rburst_cnt ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_ddr_init/readback_check ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_ddr_init/read_calibration_logic_gen[1].cal_cnt ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_ddr_init/read_calibration_logic_gen[2].cal_cnt ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_ddr_init/read_calibration_logic_gen[3].cal_cnt ;
wire [3:0] \gw3_top/u_ddr_phy_top/u_ddr_init/pre_dq ;
wire [7:0] \gw3_top/u_ddr_phy_top/u_ddr_init/rdback_check_cnt ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/n19_3 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/n92_4 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/flag_d_0_14 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/flag_d_0_16 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_5_16 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_4_16 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_3_16 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_2_16 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_1_16 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_0_16 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/flag_d_1_17 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/n298_8 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/n54_6 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/n52_6 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/n51_6 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/n49_6 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/n47_6 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/n46_6 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/n92_5 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/n92_6 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/n92_8 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/flag_d_1_18 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/flag_d_0_18 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_5_18 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_5_19 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_4_18 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_3_18 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_2_18 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_0_17 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_0_18 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_0_19 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/flag_d_1_19 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/n298_9 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/n296_8 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/n55_7 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/n53_7 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/n51_7 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/n48_7 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/n46_7 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/n45_7 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/flag_d_0_20 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_5_20 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_2_19 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/n298_11 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/n296_10 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/n297_10 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/n44_9 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/n50_9 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/n55_9 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/flag_d_0_22 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_5_24 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_3_20 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/n298_13 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/flag_d_0_24 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/n57_11 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_15_16 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/n92_10 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_15_15 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_4_20 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_2_21 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/n56_8 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/n53_9 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/n50_11 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/n48_9 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/n45_9 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/n44_11 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/n43_8 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/lock_d2 ;
wire \gw3_top/u_ddr_phy_top/ddr_sync/ready ;
wire [1:0] \gw3_top/u_ddr_phy_top/ddr_sync/recalib_s ;
wire [1:0] \gw3_top/u_ddr_phy_top/ddr_sync/lock_syn ;
wire [5:5] \gw3_top/u_ddr_phy_top/ddr_sync/cs_memsync_0 ;
wire [2:0] \gw3_top/u_ddr_phy_top/ddr_sync/count ;
wire [14:0] \gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt ;
wire [1:0] \gw3_top/u_ddr_phy_top/ddr_sync/flag ;
assign \gw3_top/u_ddr_phy_top/sys_reset_Z = recalib_feedback;
assign \gw3_top/ddr_init_internal = training_complete_feedback;
DFFCE \gw3_top/u_ddr_phy_top/ddr_init_st_r_s0  (
	.D(\gw3_top/u_ddr_phy_top/ddr_init_st_Z ),
	.CLK(clk_out),
	.CE(VCC),
	.CLEAR(ddr_rst),
	.Q(\gw3_top/u_ddr_phy_top/ddr_init_st_r )
);
defparam \gw3_top/u_ddr_phy_top/ddr_init_st_r_s0 .INIT=1'b0;
DFFCE \gw3_top/u_ddr_phy_top/ddr_init_st_rr_s0  (
	.D(\gw3_top/u_ddr_phy_top/ddr_init_st_r ),
	.CLK(clk_out),
	.CE(VCC),
	.CLEAR(ddr_rst),
	.Q(\gw3_top/u_ddr_phy_top/ddr_init_st_rr )
);
defparam \gw3_top/u_ddr_phy_top/ddr_init_st_rr_s0 .INIT=1'b0;
DFFCE \gw3_top/u_ddr_phy_top/ddr_init_st_rrr_s0  (
	.D(\gw3_top/u_ddr_phy_top/ddr_init_st_rr ),
	.CLK(clk_out),
	.CE(VCC),
	.CLEAR(ddr_rst),
	.Q(\gw3_top/u_ddr_phy_top/ddr_init_st_rrr )
);
defparam \gw3_top/u_ddr_phy_top/ddr_init_st_rrr_s0 .INIT=1'b0;
DFFSE \gw3_top/u_ddr_phy_top/ddr_rsti_reg_0_s0  (
	.D(\gw3_top/u_ddr_phy_top/dll_rsti ),
	.CLK(clk),
	.CE(VCC),
	.SET(\gw3_top/u_ddr_phy_top/cs_memsync [3]),
	.Q(\gw3_top/u_ddr_phy_top/ddr_rsti_reg [0])
);
defparam \gw3_top/u_ddr_phy_top/ddr_rsti_reg_0_s0 .INIT=1'b1;
DFFCE \gw3_top/u_ddr_phy_top/ddr_rsti_reg_1_s0  (
	.D(\gw3_top/u_ddr_phy_top/ddr_rsti_reg [0]),
	.CLK(clk),
	.CE(VCC),
	.CLEAR(GND),
	.Q(\gw3_top/u_ddr_phy_top/ddr_rsti_reg [1])
);
defparam \gw3_top/u_ddr_phy_top/ddr_rsti_reg_1_s0 .INIT=1'b0;
DFFCE \gw3_top/u_ddr_phy_top/ddr_rsti_reg_2_s0  (
	.D(\gw3_top/u_ddr_phy_top/ddr_rsti_reg [1]),
	.CLK(clk),
	.CE(VCC),
	.CLEAR(GND),
	.Q(ddr_rst)
);
defparam \gw3_top/u_ddr_phy_top/ddr_rsti_reg_2_s0 .INIT=1'b0;
DFFCE \gw3_top/u_ddr_phy_top/ddr_sync/count_0_s0  (
	.D(\gw3_top/u_ddr_phy_top/ddr_sync/n298_8 ),
	.CLK(clk),
	.CE(VCC),
	.CLEAR(\gw3_top/u_ddr_phy_top/n7_6 ),
	.Q(\gw3_top/u_ddr_phy_top/ddr_sync/count [0])
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/count_0_s0 .INIT=1'b0;
DFFCE \gw3_top/u_ddr_phy_top/ddr_sync/count_1_s0  (
	.D(\gw3_top/u_ddr_phy_top/ddr_sync/n297_10 ),
	.CLK(clk),
	.CE(VCC),
	.CLEAR(\gw3_top/u_ddr_phy_top/n7_6 ),
	.Q(\gw3_top/u_ddr_phy_top/ddr_sync/count [1])
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/count_1_s0 .INIT=1'b0;
DFFCE \gw3_top/u_ddr_phy_top/ddr_sync/count_2_s0  (
	.D(\gw3_top/u_ddr_phy_top/ddr_sync/n296_10 ),
	.CLK(clk),
	.CE(VCC),
	.CLEAR(\gw3_top/u_ddr_phy_top/n7_6 ),
	.Q(\gw3_top/u_ddr_phy_top/ddr_sync/count [2])
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/count_2_s0 .INIT=1'b0;
DFFCE \gw3_top/u_ddr_phy_top/ddr_sync/cs_memsync_0_s0  (
	.D(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_0_16 ),
	.CLK(clk),
	.CE(VCC),
	.CLEAR(\gw3_top/u_ddr_phy_top/n7_6 ),
	.Q(\gw3_top/u_ddr_phy_top/ddr_sync/ready )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/cs_memsync_0_s0 .INIT=1'b0;
DFFPE \gw3_top/u_ddr_phy_top/ddr_sync/cs_memsync_1_s0  (
	.D(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_1_16 ),
	.CLK(clk),
	.CE(VCC),
	.PRESET(\gw3_top/u_ddr_phy_top/n7_6 ),
	.Q(\gw3_top/u_ddr_phy_top/uddcntln )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/cs_memsync_1_s0 .INIT=1'b1;
DFFCE \gw3_top/u_ddr_phy_top/ddr_sync/cs_memsync_2_s0  (
	.D(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_2_16 ),
	.CLK(clk),
	.CE(VCC),
	.CLEAR(\gw3_top/u_ddr_phy_top/n7_6 ),
	.Q(\gw3_top/u_ddr_phy_top/pause )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/cs_memsync_2_s0 .INIT=1'b0;
DFFCE \gw3_top/u_ddr_phy_top/ddr_sync/cs_memsync_3_s0  (
	.D(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_3_16 ),
	.CLK(clk),
	.CE(VCC),
	.CLEAR(\gw3_top/u_ddr_phy_top/n7_6 ),
	.Q(\gw3_top/u_ddr_phy_top/cs_memsync [3])
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/cs_memsync_3_s0 .INIT=1'b0;
DFFCE \gw3_top/u_ddr_phy_top/ddr_sync/cs_memsync_4_s0  (
	.D(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_4_16 ),
	.CLK(clk),
	.CE(VCC),
	.CLEAR(\gw3_top/u_ddr_phy_top/n7_6 ),
	.Q(\gw3_top/u_ddr_phy_top/stop_d )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/cs_memsync_4_s0 .INIT=1'b0;
DFFCE \gw3_top/u_ddr_phy_top/ddr_sync/cs_memsync_5_s0  (
	.D(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_5_16 ),
	.CLK(clk),
	.CE(VCC),
	.CLEAR(\gw3_top/u_ddr_phy_top/n7_6 ),
	.Q(\gw3_top/u_ddr_phy_top/ddr_sync/cs_memsync_0 [5])
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/cs_memsync_5_s0 .INIT=1'b0;
DFFCE \gw3_top/u_ddr_phy_top/ddr_sync/ddr_init_st_s0  (
	.D(VCC),
	.CLK(clk),
	.CE(\gw3_top/u_ddr_phy_top/cs_memsync [3]),
	.CLEAR(\gw3_top/u_ddr_phy_top/n7_6 ),
	.Q(\gw3_top/u_ddr_phy_top/ddr_init_st_Z )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/ddr_init_st_s0 .INIT=1'b0;
DFFPE \gw3_top/u_ddr_phy_top/ddr_sync/dll_rst_s0  (
	.D(GND),
	.CLK(clk),
	.CE(VCC),
	.PRESET(\gw3_top/u_ddr_phy_top/n7_6 ),
	.Q(\gw3_top/u_ddr_phy_top/dll_rsti )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/dll_rst_s0 .INIT=1'b1;
DFFCE \gw3_top/u_ddr_phy_top/ddr_sync/flag_0_s4  (
	.D(\gw3_top/u_ddr_phy_top/ddr_sync/flag_d_0_16 ),
	.CLK(clk),
	.CE(\gw3_top/u_ddr_phy_top/ddr_sync/flag_d_0_14 ),
	.CLEAR(\gw3_top/u_ddr_phy_top/n7_6 ),
	.Q(\gw3_top/u_ddr_phy_top/ddr_sync/flag [0])
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/flag_0_s4 .INIT=1'b0;
DFFCE \gw3_top/u_ddr_phy_top/ddr_sync/flag_1_s2  (
	.D(\gw3_top/u_ddr_phy_top/ddr_sync/flag_d_1_17 ),
	.CLK(clk),
	.CE(\gw3_top/u_ddr_phy_top/ddr_sync/flag_d_0_14 ),
	.CLEAR(\gw3_top/u_ddr_phy_top/n7_6 ),
	.Q(\gw3_top/u_ddr_phy_top/ddr_sync/flag [1])
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/flag_1_s2 .INIT=1'b0;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/flag_d_0_s11  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/flag_d_0_24 ),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/flag_d_0_18 ),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/flag_d_0_22 ),
	.I3(\gw3_top/u_ddr_phy_top/uddcntln ),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/flag_d_0_16 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/flag_d_0_s11 .INIT=16'hFCFA;
LUT3 \gw3_top/u_ddr_phy_top/ddr_sync/flag_d_0_s13  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_3_20 ),
	.I1(\gw3_top/u_ddr_phy_top/pause ),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/flag_d_0_20 ),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/flag_d_0_18 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/flag_d_0_s13 .INIT=8'h70;
LUT3 \gw3_top/u_ddr_phy_top/ddr_sync/flag_d_0_s15  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/ready ),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/flag [0]),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_0_18 ),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/flag_d_0_20 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/flag_d_0_s15 .INIT=8'h40;
LUT3 \gw3_top/u_ddr_phy_top/ddr_sync/flag_d_0_s16  (
	.I0(\gw3_top/u_ddr_phy_top/cs_memsync [3]),
	.I1(\gw3_top/u_ddr_phy_top/stop_d ),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_4_18 ),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/flag_d_0_22 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/flag_d_0_s16 .INIT=8'h80;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/flag_d_0_s17  (
	.I0(\gw3_top/u_ddr_phy_top/pause ),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/cs_memsync_0 [5]),
	.I2(\gw3_top/u_ddr_phy_top/stop_d ),
	.I3(\gw3_top/u_ddr_phy_top/cs_memsync [3]),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/flag_d_0_24 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/flag_d_0_s17 .INIT=16'h0002;
LUT3 \gw3_top/u_ddr_phy_top/ddr_sync/flag_d_1_s10  (
	.I0(\gw3_top/u_ddr_phy_top/cs_memsync [3]),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/flag_d_1_18 ),
	.I2(\gw3_top/u_ddr_phy_top/uddcntln ),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/flag_d_0_14 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/flag_d_1_s10 .INIT=8'hEF;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/flag_d_1_s11  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/ready ),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/flag_d_1_19 ),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_0_18 ),
	.I3(\gw3_top/u_ddr_phy_top/uddcntln ),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/flag_d_1_17 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/flag_d_1_s11 .INIT=16'h4000;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/flag_d_1_s12  (
	.I0(\gw3_top/u_ddr_phy_top/stop_d ),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/cs_memsync_0 [5]),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/ready ),
	.I3(\gw3_top/u_ddr_phy_top/pause ),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/flag_d_1_18 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/flag_d_1_s12 .INIT=16'hEFF3;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/flag_d_1_s13  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_2_21 ),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_5_24 ),
	.I2(\gw3_top/u_ddr_phy_top/pause ),
	.I3(\gw3_top/u_ddr_phy_top/ddr_sync/flag [1]),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/flag_d_1_19 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/flag_d_1_s13 .INIT=16'hF3A0;
DFFCE \gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_0_s3  (
	.D(\gw3_top/u_ddr_phy_top/ddr_sync/n57_11 ),
	.CLK(clk),
	.CE(VCC),
	.CLEAR(\gw3_top/u_ddr_phy_top/n7_6 ),
	.Q(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [0])
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_0_s3 .INIT=1'b0;
DFFCE \gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_10_s1  (
	.D(\gw3_top/u_ddr_phy_top/ddr_sync/n47_6 ),
	.CLK(clk),
	.CE(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_15_16 ),
	.CLEAR(\gw3_top/u_ddr_phy_top/n7_6 ),
	.Q(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [10])
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_10_s1 .INIT=1'b0;
DFFCE \gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_11_s1  (
	.D(\gw3_top/u_ddr_phy_top/ddr_sync/n46_6 ),
	.CLK(clk),
	.CE(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_15_16 ),
	.CLEAR(\gw3_top/u_ddr_phy_top/n7_6 ),
	.Q(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [11])
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_11_s1 .INIT=1'b0;
DFFCE \gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_12_s1  (
	.D(\gw3_top/u_ddr_phy_top/ddr_sync/n45_9 ),
	.CLK(clk),
	.CE(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_15_16 ),
	.CLEAR(\gw3_top/u_ddr_phy_top/n7_6 ),
	.Q(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [12])
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_12_s1 .INIT=1'b0;
DFFCE \gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_13_s1  (
	.D(\gw3_top/u_ddr_phy_top/ddr_sync/n44_11 ),
	.CLK(clk),
	.CE(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_15_16 ),
	.CLEAR(\gw3_top/u_ddr_phy_top/n7_6 ),
	.Q(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [13])
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_13_s1 .INIT=1'b0;
DFFCE \gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_14_s1  (
	.D(\gw3_top/u_ddr_phy_top/ddr_sync/n43_8 ),
	.CLK(clk),
	.CE(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_15_16 ),
	.CLEAR(\gw3_top/u_ddr_phy_top/n7_6 ),
	.Q(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [14])
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_14_s1 .INIT=1'b0;
LUT2 \gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_15_s6  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [14]),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/lock_syn [1]),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_15_16 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_15_s6 .INIT=4'h7;
LUT2 \gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_15_s7  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [14]),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/lock_syn [1]),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_15_15 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_15_s7 .INIT=4'h4;
DFFCE \gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_1_s1  (
	.D(\gw3_top/u_ddr_phy_top/ddr_sync/n56_8 ),
	.CLK(clk),
	.CE(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_15_16 ),
	.CLEAR(\gw3_top/u_ddr_phy_top/n7_6 ),
	.Q(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [1])
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_1_s1 .INIT=1'b0;
DFFCE \gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_2_s1  (
	.D(\gw3_top/u_ddr_phy_top/ddr_sync/n55_9 ),
	.CLK(clk),
	.CE(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_15_16 ),
	.CLEAR(\gw3_top/u_ddr_phy_top/n7_6 ),
	.Q(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [2])
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_2_s1 .INIT=1'b0;
DFFCE \gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_3_s1  (
	.D(\gw3_top/u_ddr_phy_top/ddr_sync/n54_6 ),
	.CLK(clk),
	.CE(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_15_16 ),
	.CLEAR(\gw3_top/u_ddr_phy_top/n7_6 ),
	.Q(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [3])
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_3_s1 .INIT=1'b0;
DFFCE \gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_4_s1  (
	.D(\gw3_top/u_ddr_phy_top/ddr_sync/n53_9 ),
	.CLK(clk),
	.CE(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_15_16 ),
	.CLEAR(\gw3_top/u_ddr_phy_top/n7_6 ),
	.Q(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [4])
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_4_s1 .INIT=1'b0;
DFFCE \gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_5_s1  (
	.D(\gw3_top/u_ddr_phy_top/ddr_sync/n52_6 ),
	.CLK(clk),
	.CE(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_15_16 ),
	.CLEAR(\gw3_top/u_ddr_phy_top/n7_6 ),
	.Q(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [5])
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_5_s1 .INIT=1'b0;
DFFCE \gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_6_s1  (
	.D(\gw3_top/u_ddr_phy_top/ddr_sync/n51_6 ),
	.CLK(clk),
	.CE(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_15_16 ),
	.CLEAR(\gw3_top/u_ddr_phy_top/n7_6 ),
	.Q(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [6])
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_6_s1 .INIT=1'b0;
DFFCE \gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_7_s1  (
	.D(\gw3_top/u_ddr_phy_top/ddr_sync/n50_11 ),
	.CLK(clk),
	.CE(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_15_16 ),
	.CLEAR(\gw3_top/u_ddr_phy_top/n7_6 ),
	.Q(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [7])
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_7_s1 .INIT=1'b0;
DFFCE \gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_8_s1  (
	.D(\gw3_top/u_ddr_phy_top/ddr_sync/n49_6 ),
	.CLK(clk),
	.CE(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_15_16 ),
	.CLEAR(\gw3_top/u_ddr_phy_top/n7_6 ),
	.Q(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [8])
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_8_s1 .INIT=1'b0;
DFFCE \gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_9_s1  (
	.D(\gw3_top/u_ddr_phy_top/ddr_sync/n48_9 ),
	.CLK(clk),
	.CE(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_15_16 ),
	.CLEAR(\gw3_top/u_ddr_phy_top/n7_6 ),
	.Q(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [9])
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_9_s1 .INIT=1'b0;
DFFCE \gw3_top/u_ddr_phy_top/ddr_sync/lock_d2_s0  (
	.D(VCC),
	.CLK(clk),
	.CE(\gw3_top/u_ddr_phy_top/ddr_sync/n92_4 ),
	.CLEAR(\gw3_top/u_ddr_phy_top/n7_6 ),
	.Q(\gw3_top/u_ddr_phy_top/ddr_sync/lock_d2 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/lock_d2_s0 .INIT=1'b0;
DFFCE \gw3_top/u_ddr_phy_top/ddr_sync/lock_syn_0_s0  (
	.D(\gw3_top/u_ddr_phy_top/ddr_sync/n19_3 ),
	.CLK(clk),
	.CE(VCC),
	.CLEAR(\gw3_top/u_ddr_phy_top/n7_6 ),
	.Q(\gw3_top/u_ddr_phy_top/ddr_sync/lock_syn [0])
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/lock_syn_0_s0 .INIT=1'b0;
DFFCE \gw3_top/u_ddr_phy_top/ddr_sync/lock_syn_1_s0  (
	.D(\gw3_top/u_ddr_phy_top/ddr_sync/lock_syn [0]),
	.CLK(clk),
	.CE(VCC),
	.CLEAR(\gw3_top/u_ddr_phy_top/n7_6 ),
	.Q(\gw3_top/u_ddr_phy_top/ddr_sync/lock_syn [1])
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/lock_syn_1_s0 .INIT=1'b0;
LUT2 \gw3_top/u_ddr_phy_top/ddr_sync/n19_s0  (
	.I0(\gw3_top/u_ddr_phy_top/dll_lock ),
	.I1(pll_lock),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/n19_3 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/n19_s0 .INIT=4'h8;
LUT2 \gw3_top/u_ddr_phy_top/ddr_sync/n296_s3  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/count [0]),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/count [1]),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/n296_8 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/n296_s3 .INIT=4'h8;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/n296_s4  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/count [2]),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/n296_8 ),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_2_19 ),
	.I3(\gw3_top/u_ddr_phy_top/ddr_sync/n298_9 ),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/n296_10 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/n296_s4 .INIT=16'h0600;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/n297_s4  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/count [0]),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/count [1]),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_2_19 ),
	.I3(\gw3_top/u_ddr_phy_top/ddr_sync/n298_9 ),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/n297_10 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/n297_s4 .INIT=16'h0600;
LUT2 \gw3_top/u_ddr_phy_top/ddr_sync/n298_s3  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/count [0]),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/n298_9 ),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/n298_8 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/n298_s3 .INIT=4'h4;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/n298_s4  (
	.I0(\gw3_top/u_ddr_phy_top/pause ),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/cs_memsync_0 [5]),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_3_20 ),
	.I3(\gw3_top/u_ddr_phy_top/ddr_sync/n298_13 ),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/n298_9 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/n298_s4 .INIT=16'h001F;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/n298_s6  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/ready ),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/lock_d2 ),
	.I2(\gw3_top/u_ddr_phy_top/pause ),
	.I3(\gw3_top/u_ddr_phy_top/uddcntln ),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/n298_11 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/n298_s6 .INIT=16'h0B00;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/n298_s7  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/cs_memsync_0 [5]),
	.I1(\gw3_top/u_ddr_phy_top/stop_d ),
	.I2(\gw3_top/u_ddr_phy_top/cs_memsync [3]),
	.I3(\gw3_top/u_ddr_phy_top/ddr_sync/n298_11 ),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/n298_13 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/n298_s7 .INIT=16'h0100;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/n43_s2  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [13]),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [14]),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/lock_syn [1]),
	.I3(\gw3_top/u_ddr_phy_top/ddr_sync/n44_9 ),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/n43_8 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/n43_s2 .INIT=16'h2000;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/n44_s3  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [12]),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [11]),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/n50_9 ),
	.I3(\gw3_top/u_ddr_phy_top/ddr_sync/n46_7 ),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/n44_9 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/n44_s3 .INIT=16'h8000;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/n44_s4  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [13]),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/n44_9 ),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [14]),
	.I3(\gw3_top/u_ddr_phy_top/ddr_sync/lock_syn [1]),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/n44_11 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/n44_s4 .INIT=16'h0600;
LUT3 \gw3_top/u_ddr_phy_top/ddr_sync/n45_s2  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [11]),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/n50_9 ),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/n46_7 ),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/n45_7 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/n45_s2 .INIT=8'h80;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/n45_s3  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [12]),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/n45_7 ),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [14]),
	.I3(\gw3_top/u_ddr_phy_top/ddr_sync/lock_syn [1]),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/n45_9 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/n45_s3 .INIT=16'h0600;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/n46_s1  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/n50_9 ),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/n46_7 ),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [11]),
	.I3(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_15_15 ),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/n46_6 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/n46_s1 .INIT=16'h7800;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/n46_s2  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [7]),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [8]),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [9]),
	.I3(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [10]),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/n46_7 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/n46_s2 .INIT=16'h8000;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/n47_s1  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [9]),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/n48_7 ),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [10]),
	.I3(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_15_15 ),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/n47_6 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/n47_s1 .INIT=16'h7800;
LUT3 \gw3_top/u_ddr_phy_top/ddr_sync/n48_s2  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [7]),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [8]),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/n50_9 ),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/n48_7 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/n48_s2 .INIT=8'h80;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/n48_s3  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [9]),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/n48_7 ),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [14]),
	.I3(\gw3_top/u_ddr_phy_top/ddr_sync/lock_syn [1]),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/n48_9 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/n48_s3 .INIT=16'h0600;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/n49_s1  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [7]),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/n50_9 ),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [8]),
	.I3(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_15_15 ),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/n49_6 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/n49_s1 .INIT=16'h7800;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/n50_s3  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [6]),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/n53_7 ),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [4]),
	.I3(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [5]),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/n50_9 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/n50_s3 .INIT=16'h8000;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/n50_s4  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [7]),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/n50_9 ),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [14]),
	.I3(\gw3_top/u_ddr_phy_top/ddr_sync/lock_syn [1]),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/n50_11 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/n50_s4 .INIT=16'h0600;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/n51_s1  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/n53_7 ),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/n51_7 ),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [6]),
	.I3(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_15_15 ),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/n51_6 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/n51_s1 .INIT=16'h7800;
LUT2 \gw3_top/u_ddr_phy_top/ddr_sync/n51_s2  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [4]),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [5]),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/n51_7 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/n51_s2 .INIT=4'h8;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/n52_s1  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [4]),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/n53_7 ),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [5]),
	.I3(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_15_15 ),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/n52_6 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/n52_s1 .INIT=16'h7800;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/n53_s2  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [0]),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [1]),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [2]),
	.I3(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [3]),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/n53_7 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/n53_s2 .INIT=16'h8000;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/n53_s3  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [4]),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/n53_7 ),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [14]),
	.I3(\gw3_top/u_ddr_phy_top/ddr_sync/lock_syn [1]),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/n53_9 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/n53_s3 .INIT=16'h0600;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/n54_s1  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [2]),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/n55_7 ),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [3]),
	.I3(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_15_15 ),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/n54_6 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/n54_s1 .INIT=16'h7800;
LUT2 \gw3_top/u_ddr_phy_top/ddr_sync/n55_s2  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [0]),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [1]),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/n55_7 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/n55_s2 .INIT=4'h8;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/n55_s3  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [2]),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [0]),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [1]),
	.I3(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt_15_15 ),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/n55_9 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/n55_s3 .INIT=16'h6A00;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/n56_s2  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [0]),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [1]),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [14]),
	.I3(\gw3_top/u_ddr_phy_top/ddr_sync/lock_syn [1]),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/n56_8 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/n56_s2 .INIT=16'h0600;
LUT3 \gw3_top/u_ddr_phy_top/ddr_sync/n57_s4  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [0]),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [14]),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/lock_syn [1]),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/n57_11 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/n57_s4 .INIT=8'h90;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/n92_s1  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/n92_5 ),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/n92_6 ),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/n92_10 ),
	.I3(\gw3_top/u_ddr_phy_top/ddr_sync/n92_8 ),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/n92_4 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/n92_s1 .INIT=16'h8000;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/n92_s2  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [0]),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [1]),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [2]),
	.I3(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [3]),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/n92_5 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/n92_s2 .INIT=16'h0001;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/n92_s3  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [8]),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [9]),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [10]),
	.I3(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [11]),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/n92_6 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/n92_s3 .INIT=16'h0001;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/n92_s5  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [4]),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [5]),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [6]),
	.I3(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [7]),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/n92_8 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/n92_s5 .INIT=16'h0001;
LUT3 \gw3_top/u_ddr_phy_top/ddr_sync/n92_s6  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [12]),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [13]),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/lock_cnt [14]),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/n92_10 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/n92_s6 .INIT=8'h10;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_0_s12  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_0_17 ),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_0_18 ),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/ready ),
	.I3(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_0_19 ),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_0_16 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_0_s12 .INIT=16'hFF40;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_0_s13  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/recalib_s [1]),
	.I1(\gw3_top/u_ddr_phy_top/uddcntln ),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/lock_d2 ),
	.I3(\gw3_top/u_ddr_phy_top/pause ),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_0_17 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_0_s13 .INIT=16'h00BF;
LUT3 \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_0_s14  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/cs_memsync_0 [5]),
	.I1(\gw3_top/u_ddr_phy_top/stop_d ),
	.I2(\gw3_top/u_ddr_phy_top/cs_memsync [3]),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_0_18 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_0_s14 .INIT=8'h01;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_0_s15  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/count [2]),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/flag [0]),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/n296_8 ),
	.I3(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_5_18 ),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_0_19 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_0_s15 .INIT=16'h8000;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_1_s12  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/flag [0]),
	.I1(\gw3_top/u_ddr_phy_top/uddcntln ),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_3_20 ),
	.I3(\gw3_top/u_ddr_phy_top/ddr_sync/flag_d_0_24 ),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_1_16 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_1_s12 .INIT=16'hBCFF;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_2_s12  (
	.I0(\gw3_top/u_ddr_phy_top/uddcntln ),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_2_21 ),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/flag_d_0_24 ),
	.I3(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_2_18 ),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_2_16 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_2_s12 .INIT=16'hFF70;
LUT3 \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_2_s14  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/lock_d2 ),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_5_18 ),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_2_19 ),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_2_18 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_2_s14 .INIT=8'h80;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_2_s15  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/count [1]),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/flag [1]),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/count [0]),
	.I3(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_5_20 ),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_2_19 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_2_s15 .INIT=16'h1000;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_2_s16  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/flag [0]),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/count [2]),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/count [0]),
	.I3(\gw3_top/u_ddr_phy_top/ddr_sync/count [1]),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_2_21 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_2_s16 .INIT=16'h2000;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_3_s12  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/flag [0]),
	.I1(\gw3_top/u_ddr_phy_top/cs_memsync [3]),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_3_20 ),
	.I3(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_3_18 ),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_3_16 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_3_s12 .INIT=16'h1C00;
LUT2 \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_3_s14  (
	.I0(\gw3_top/u_ddr_phy_top/stop_d ),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_4_18 ),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_3_18 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_3_s14 .INIT=4'h8;
LUT3 \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_3_s15  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/count [2]),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/count [0]),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/count [1]),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_3_20 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_3_s15 .INIT=8'h40;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_4_s12  (
	.I0(\gw3_top/u_ddr_phy_top/stop_d ),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/flag [0]),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_4_20 ),
	.I3(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_4_18 ),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_4_16 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_4_s12 .INIT=16'h3A00;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_4_s14  (
	.I0(\gw3_top/u_ddr_phy_top/pause ),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/ready ),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/cs_memsync_0 [5]),
	.I3(\gw3_top/u_ddr_phy_top/uddcntln ),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_4_18 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_4_s14 .INIT=16'h1000;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_4_s15  (
	.I0(\gw3_top/u_ddr_phy_top/cs_memsync [3]),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/count [2]),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/count [0]),
	.I3(\gw3_top/u_ddr_phy_top/ddr_sync/count [1]),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_4_20 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_4_s15 .INIT=16'h1000;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_5_s12  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_5_24 ),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_5_18 ),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/flag [1]),
	.I3(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_5_19 ),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_5_16 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_5_s12 .INIT=16'hFF80;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_5_s14  (
	.I0(\gw3_top/u_ddr_phy_top/pause ),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/ready ),
	.I2(\gw3_top/u_ddr_phy_top/uddcntln ),
	.I3(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_0_18 ),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_5_18 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_5_s14 .INIT=16'h1000;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_5_s15  (
	.I0(\gw3_top/u_ddr_phy_top/cs_memsync [3]),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_2_21 ),
	.I2(\gw3_top/u_ddr_phy_top/stop_d ),
	.I3(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_4_18 ),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_5_19 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_5_s15 .INIT=16'hF100;
LUT2 \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_5_s16  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/flag [0]),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/count [2]),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_5_20 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_5_s16 .INIT=4'h4;
LUT4 \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_5_s18  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_sync/count [0]),
	.I1(\gw3_top/u_ddr_phy_top/ddr_sync/count [1]),
	.I2(\gw3_top/u_ddr_phy_top/ddr_sync/flag [0]),
	.I3(\gw3_top/u_ddr_phy_top/ddr_sync/count [2]),
	.F(\gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_5_24 )
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/ns_memsync_5_s18 .INIT=16'h0800;
DFFCE \gw3_top/u_ddr_phy_top/ddr_sync/recalib_s_0_s0  (
	.D(\gw3_top/u_ddr_phy_top/sys_reset_Z ),
	.CLK(clk),
	.CE(VCC),
	.CLEAR(\gw3_top/u_ddr_phy_top/n7_6 ),
	.Q(\gw3_top/u_ddr_phy_top/ddr_sync/recalib_s [0])
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/recalib_s_0_s0 .INIT=1'b0;
DFFCE \gw3_top/u_ddr_phy_top/ddr_sync/recalib_s_1_s0  (
	.D(\gw3_top/u_ddr_phy_top/ddr_sync/recalib_s [0]),
	.CLK(clk),
	.CE(VCC),
	.CLEAR(\gw3_top/u_ddr_phy_top/n7_6 ),
	.Q(\gw3_top/u_ddr_phy_top/ddr_sync/recalib_s [1])
);
defparam \gw3_top/u_ddr_phy_top/ddr_sync/recalib_s_1_s0 .INIT=1'b0;
DFFCE \gw3_top/u_ddr_phy_top/dll_step_base_0_s0  (
	.D(\gw3_top/u_ddr_phy_top/dll_step [0]),
	.CLK(clk_out),
	.CE(\gw3_top/u_ddr_phy_top/n2474_3 ),
	.CLEAR(ddr_rst),
	.Q(\gw3_top/u_ddr_phy_top/dll_step_base [0])
);
defparam \gw3_top/u_ddr_phy_top/dll_step_base_0_s0 .INIT=1'b0;
DFFCE \gw3_top/u_ddr_phy_top/dll_step_base_1_s0  (
	.D(\gw3_top/u_ddr_phy_top/dll_step [1]),
	.CLK(clk_out),
	.CE(\gw3_top/u_ddr_phy_top/n2474_3 ),
	.CLEAR(ddr_rst),
	.Q(\gw3_top/u_ddr_phy_top/dll_step_base [1])
);
defparam \gw3_top/u_ddr_phy_top/dll_step_base_1_s0 .INIT=1'b0;
DFFCE \gw3_top/u_ddr_phy_top/dll_step_base_2_s0  (
	.D(\gw3_top/u_ddr_phy_top/dll_step [2]),
	.CLK(clk_out),
	.CE(\gw3_top/u_ddr_phy_top/n2474_3 ),
	.CLEAR(ddr_rst),
	.Q(\gw3_top/u_ddr_phy_top/dll_step_base [2])
);
defparam \gw3_top/u_ddr_phy_top/dll_step_base_2_s0 .INIT=1'b0;
DFFCE \gw3_top/u_ddr_phy_top/dll_step_base_3_s0  (
	.D(\gw3_top/u_ddr_phy_top/dll_step [3]),
	.CLK(clk_out),
	.CE(\gw3_top/u_ddr_phy_top/n2474_3 ),
	.CLEAR(ddr_rst),
	.Q(\gw3_top/u_ddr_phy_top/dll_step_base [3])
);
defparam \gw3_top/u_ddr_phy_top/dll_step_base_3_s0 .INIT=1'b0;
DFFCE \gw3_top/u_ddr_phy_top/dll_step_base_4_s0  (
	.D(\gw3_top/u_ddr_phy_top/dll_step [4]),
	.CLK(clk_out),
	.CE(\gw3_top/u_ddr_phy_top/n2474_3 ),
	.CLEAR(ddr_rst),
	.Q(\gw3_top/u_ddr_phy_top/dll_step_base [4])
);
defparam \gw3_top/u_ddr_phy_top/dll_step_base_4_s0 .INIT=1'b0;
DFFCE \gw3_top/u_ddr_phy_top/dll_step_base_5_s0  (
	.D(\gw3_top/u_ddr_phy_top/dll_step [5]),
	.CLK(clk_out),
	.CE(\gw3_top/u_ddr_phy_top/n2474_3 ),
	.CLEAR(ddr_rst),
	.Q(\gw3_top/u_ddr_phy_top/dll_step_base [5])
);
defparam \gw3_top/u_ddr_phy_top/dll_step_base_5_s0 .INIT=1'b0;
DFFCE \gw3_top/u_ddr_phy_top/dll_step_base_6_s0  (
	.D(\gw3_top/u_ddr_phy_top/dll_step [6]),
	.CLK(clk_out),
	.CE(\gw3_top/u_ddr_phy_top/n2474_3 ),
	.CLEAR(ddr_rst),
	.Q(\gw3_top/u_ddr_phy_top/dll_step_base [6])
);
defparam \gw3_top/u_ddr_phy_top/dll_step_base_6_s0 .INIT=1'b0;
DFFCE \gw3_top/u_ddr_phy_top/dll_step_base_7_s0  (
	.D(\gw3_top/u_ddr_phy_top/dll_step [7]),
	.CLK(clk_out),
	.CE(\gw3_top/u_ddr_phy_top/n2474_3 ),
	.CLEAR(ddr_rst),
	.Q(\gw3_top/u_ddr_phy_top/dll_step_base [7])
);
defparam \gw3_top/u_ddr_phy_top/dll_step_base_7_s0 .INIT=1'b0;
CLKDIV \gw3_top/u_ddr_phy_top/fclkdiv  (
	.HCLKIN(memory_clk),
	.RESETN(\gw3_top/u_ddr_phy_top/n809_6 ),
	.CALIB(GND),
	.CLKOUT(clk_out)
);
defparam \gw3_top/u_ddr_phy_top/fclkdiv .DIV_MODE="4";
LUT1 \gw3_top/u_ddr_phy_top/n2457_s2  (
	.I0(pll_lock),
	.F(\gw3_top/u_ddr_phy_top/n2457_6 )
);
defparam \gw3_top/u_ddr_phy_top/n2457_s2 .INIT=2'h1;
LUT3 \gw3_top/u_ddr_phy_top/n2474_s0  (
	.I0(\gw3_top/u_ddr_phy_top/ddr_init_st_rrr ),
	.I1(\gw3_top/u_ddr_phy_top/ddr_init_st_rr ),
	.I2(\gw3_top/u_ddr_phy_top/dll_lock ),
	.F(\gw3_top/u_ddr_phy_top/n2474_3 )
);
defparam \gw3_top/u_ddr_phy_top/n2474_s0 .INIT=8'h40;
INV \gw3_top/u_ddr_phy_top/n7_s2  (
	.I(rst_n),
	.O(\gw3_top/u_ddr_phy_top/n7_6 )
);
LUT1 \gw3_top/u_ddr_phy_top/n809_s2  (
	.I0(ddr_rst),
	.F(\gw3_top/u_ddr_phy_top/n809_6 )
);
defparam \gw3_top/u_ddr_phy_top/n809_s2 .INIT=2'h1;
INV \gw3_top/u_ddr_phy_top/pll_stop_d_s0  (
	.I(\gw3_top/u_ddr_phy_top/stop_reg [2]),
	.O(pll_stop)
);
DFFCE \gw3_top/u_ddr_phy_top/stop_reg_0_s0  (
	.D(\gw3_top/u_ddr_phy_top/stop_d ),
	.CLK(clk),
	.CE(VCC),
	.CLEAR(\gw3_top/u_ddr_phy_top/n7_6 ),
	.Q(\gw3_top/u_ddr_phy_top/stop_reg [0])
);
defparam \gw3_top/u_ddr_phy_top/stop_reg_0_s0 .INIT=1'b0;
DFFCE \gw3_top/u_ddr_phy_top/stop_reg_1_s0  (
	.D(\gw3_top/u_ddr_phy_top/stop_reg [0]),
	.CLK(clk),
	.CE(VCC),
	.CLEAR(\gw3_top/u_ddr_phy_top/n7_6 ),
	.Q(\gw3_top/u_ddr_phy_top/stop_reg [1])
);
defparam \gw3_top/u_ddr_phy_top/stop_reg_1_s0 .INIT=1'b0;
DFFCE \gw3_top/u_ddr_phy_top/stop_reg_2_s0  (
	.D(\gw3_top/u_ddr_phy_top/stop_reg [1]),
	.CLK(clk),
	.CE(VCC),
	.CLEAR(\gw3_top/u_ddr_phy_top/n7_6 ),
	.Q(\gw3_top/u_ddr_phy_top/stop_reg [2])
);
defparam \gw3_top/u_ddr_phy_top/stop_reg_2_s0 .INIT=1'b0;
DDRDLL \gw3_top/u_ddr_phy_top/u_dll  (
	.CLKIN(memory_clk),
	.STOP(\gw3_top/u_ddr_phy_top/n2457_6 ),
	.RESET(\gw3_top/u_ddr_phy_top/dll_rsti ),
	.UPDNCNTL(\gw3_top/u_ddr_phy_top/uddcntln ),
	.LOCK(\gw3_top/u_ddr_phy_top/dll_lock ),
	.STEP({\gw3_top/u_ddr_phy_top/dll_step [7:0]})
);
defparam \gw3_top/u_ddr_phy_top/u_dll .DIV_SEL=1'b0;
defparam \gw3_top/u_ddr_phy_top/u_dll .CODESCAL="111";
defparam \gw3_top/u_ddr_phy_top/u_dll .SCAL_EN="FALSE";
defparam \gw3_top/u_ddr_phy_top/u_dll .DLL_FORCE="FALSE";
GSR GSR(.GSRI(VCC));
endmodule
