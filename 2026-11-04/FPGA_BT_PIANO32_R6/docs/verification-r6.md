# R6 仿真与综合记录

记录对应原始构建 `0x0b02fc49`。原始记录中的 140 项生产输入 SHA-256 与 [构建身份清单](../build_identity.json) 一致。发布版的两行 RTL 注释修订另载于 [发布来源](../PACKAGING_ORIGIN.json)。

## ModelSim 功能回归

汇总记录包含 32 个通过的测试台。下表的检查数来自各测试台的完成记录，控制台 SHA-256 来自逐项核对的原始日志。

| 测试台 | 效果 RAM | 有效检查数 | 原控制台 SHA-256 |
| --- | --- | ---: | --- |
| `tb_bt_piano32_feedback` | 功能效果 RAM | 19 | `6a8f99648686e258407324a1821bccfeaef4cad1df4926aa7109874bb33a3482` |
| `tb_r7_bluetooth_uart` | 功能效果 RAM | 134 | `a6bdddd19592113c0534239e035031b81d9e0299a40c2d51f9d5a289a1543f86` |
| `tb_r7_bluetooth_ownership` | 功能效果 RAM | 59 | `8e75ee7da43fd05c007ee19152148b3c37348f5e0477d130a808f9fdc2bd5663` |
| `tb_backend_pipeline` | 厂商模型 | 12058 | `be4635491475a4dc494c43273b63c02c654e0f13cc255ca2ea24842d2ef60b43` |
| `tb_bt_piano32_screen` | 功能效果 RAM | 4709 | `79050ce6fbd4229fd0282422159ef964cd448014281f4148510e2d01f9efe891` |
| `tb_fx_ram` | 厂商模型 | 2048 | `f1d5d36e2a914088243a2b3ebba7c19a26472976992aca87ce960b7732460714` |
| `tb_fx_response` | 厂商模型 | 134403 | `7f99fd8d15b178b23380bffecd3bc2f373f4bc674608050c3586dbebb1b5ed75` |
| `tb_chorus_depth` | 厂商模型 | 65536 | `6fa12f73b7f88efbc47c3bc144f82d691db668a0a091885b21fa70a32da48108` |
| `tb_fx_parameters` | 厂商模型 | 3604 | `bfe536d5c2581baf8c39afac05fa7e552dcc6173e6e5f4a42adaabcfaa1aa290` |
| `tb_gain_fx_bypass` | 厂商模型 | 13000 | `9f3d6b9727d47a1ad900986cd0ad10ad15aaf9ab9552ac0b75fec42f2666f12b` |
| `tb_audio_runtime_metrics` | 厂商模型 | 12 | `0440d4b56d9139b185cb745a5ba773c54c1b41f223ef5b485dd9dffa46a55155` |
| `tb_live_note_pitch` | 厂商模型 | 16 | `0b958309e5b4ed3a8d79a07c7502acce4b7665bc317be409818534b5696d497e` |
| `tb_pressure_lesson` | 厂商模型 | 97 | `a22cd2b3979bd6f87adb4085bf4a546124f62bbcc6730511a5d51dfa412af247` |
| `tb_lesson_import` | 厂商模型 | 12 | `7e479f4c8957ec08f1684e577ce6dba799e06f01199fac3853c8aa7447ad749d` |
| `tb_player_lesson` | 厂商模型 | 6 | `134476e3818e98c5d66216711a1815d8ea8042f2a31ae60d7f2a3fea14e3fe7e` |
| `tb_observer` | 厂商模型 | 5 | `f8ae42b6409ed1b64ab7488e6f32d4f83206f61b5469bb846c3e380aa1c1c1fa` |
| `tb_lissajous_pairs` | 厂商模型 | 320 | `1dba76867c129404aa9d090053dab9d8663ad167c419f7a13a32d672605d8a4d` |
| `tb_damping_bypass` | 厂商模型 | 12 | `3533b138174b87e24f61500af5fea8edf8006baa2117037ba97e6f2b580b218d` |
| `tb_nodrum_audio` | 厂商模型 | 12 | `50439289268dff552a5e07a712bef3d9abfec97820a60f10a0b3299b99111af3` |
| `tb_r7_features_uart` | 功能效果 RAM | 41 | `7516aa95211088e65870e0074fa03e877c8f59d3c2d4816f032743c1f43e52bb` |
| `tb_workstation` | 功能效果 RAM | 22 | `92f4476a78a88ef97b77373d0cc912af2dc8a4b4a1d78e6449505349e1d15609` |
| `tb_gain_control_uart` | 功能效果 RAM | 35 | `77d442312c91260f40cb5a3d8ac1221da0a2d02d6d4d0d38db2ec8d740fe4066` |
| `tb_bend_pipeline` | 厂商模型 | 40 | `4ed1f41c335c57482b0128dbec17f029ecd5e21093ad30bcda17d9994cec81a5` |
| `tb_scheduler_timing` | 厂商模型 | 11769 | `0a1d1eb801f5b9957d8ff3cc047868becbfe334f85a0b48cd1b2ee0ba7ed372a` |
| `tb_player_controls` | 厂商模型 | 20 | `6fb51f978168745c1f27e6b5644e8983992421e78a4ba638c4a123f25289cc2b` |
| `tb_player16` | 厂商模型 | 12 | `b62a0ac6b75aa78584d662fc65316208f323eee7b64dd65f1b94e4b3eb1fad88` |
| `tb_status_snapshot` | 厂商模型 | 6 | `e8f0553e0298a633d33416aa2c73d56bc7ccced75912d0d6f5d5d761647e4646` |
| `tb_hw_monitor_reset` | 厂商模型 | 50 | `a948c4de723fcd425108ecd4290c0f9377760b5758b3d2421db979dac22edee5` |
| `tb_workstation_screen` | 功能效果 RAM | 20 | `de0c4f09302acbec556e36b9020b3fec971c0ca717a787c59b8974e7254a34a7` |
| `tb_r7_revision_piano` | 功能效果 RAM | 63 | `cf7834c821b82bc5ed37b3fd92536de0b8a4e8cb5a8affeae1ece93e26a74860` |
| `tb_r7_revision_guitar` | 功能效果 RAM | 63 | `dc5086acdd92217b4eb3c444758a169933985d3f1d5c1ac84f69307eb31d890e` |
| `tb_r7_revision_bass` | 功能效果 RAM | 63 | `cb3bbc083fbf11a140c31bbd4fb22e252d9669fb22c6e0368ae9235061197000` |

回归汇总记录 SHA-256 为 `f4a91003d5aa38c960887786f74163bdf39eb8b4bfed122fe176689126efb271`。故障注入记录包括 19 次故障检出、19 次恢复和 6 次正常对照，44 次结果均符合预期。故障注入汇总记录 SHA-256 为 `fd23e9e552abe29711fdacad9034835a6bd0c8c1f4acacb262970d2c6559170e`。

## 32 声部负载仿真

[`tb_bt_piano32_screen`](../sim/tb_bt_piano32_screen.sv) 保持 50 MHz 控制时钟和 48 kHz 采样配置，缩短起音间隔和保持等待。测试在 USB 和串口屏启动的两轮递进中分别核对 32 次完成反馈，并在保持阶段按音频帧检查 32 个声部槽同时活跃、各槽 PCM 为确定值。全程记录 192 帧，其中 182 帧混音样本非零。该项结果描述顶层 RTL 的声部状态和混音采样。

## Gowin 综合

Gowin FPGA Designer V1.9.12.03 的综合进程以退出码 0 完成，日志含 `GowinSynthesis finish`，生成综合网表和资源报告。

| 记录 | SHA-256 |
| --- | --- |
| 原综合日志 `syn.log` | `86ee910aa5ae07bd10959865aeeb8660ea5b8e97e98661863e5781b3cba824dd` |
| 原综合网表 `workstation_nodrum_ddr.vg` | `44f256ee5e2a74fa413faaa1d3695a24925a431fc6f469487ef95574a536eb10` |
| [Gowin 原始综合资源报告](workstation_nodrum_ddr_syn_rsc.xml) | `a330d7d671b30a725fae797531d203fa5b58e351b49e1da6b95dcf968f11ad7b` |
