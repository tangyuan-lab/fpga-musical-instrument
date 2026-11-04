# 备用 I2S 输出

`i2s_tx_16.v` 是独立标准 I2S 发送器，未加入默认工程。板上 v74 使用 `src/pt8211_tx.v`。
数字接口回归包含在 `scripts/run_tests.py --suite basic`，不代表已接入另一个 DAC 做实板验收。
