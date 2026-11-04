# 已确认的板上版本

2026-10-19 最近一次实际 SRAM 下载并读回的版本为 **v74，USER 0x00005AA4**。
用户随后确认有声、声音干净、没有颤抖；反馈后再次读回同一 USER。

对应文件：`checkpoints/piano_drums_poly4_shared_v68_full_runtime50_control_v74_20261019.fs`。
SHA256：`8e2318a08def7c6200c658e196b8b295555513fd32d5a44823d02075831be249`。

最近一次核验确认板卡通过 SRAM 加载 v74。断电或重新配置会清除 SRAM 中的程序；本记录未写入 Flash。当前 RTL 使用新的版本标识构建，与 v74 分开管理。
