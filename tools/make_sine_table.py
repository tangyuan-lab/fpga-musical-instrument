#!/usr/bin/env python3
"""生成 4096 点、幅值正负 4096 的 16 位正弦表，给 dds_sine_voice.v 用 $readmemh 读取。

输出格式（每项两行，与 ModelSim / Gowin 的 $readmemh 兼容）：

    @0
    0000
    @1
    0006
    ...
    @fff
    fffa

用法：

    python make_sine_table.py sine_4096x16.ver

表的内容由公式 round(4096 * sin(2*pi*n/4096)) 唯一决定（负数按二补码写）。
"""

import math
import sys

POINTS = 4096
AMPLITUDE = 4096


def build():
    for n in range(POINTS):
        value = round(AMPLITUDE * math.sin(2.0 * math.pi * n / POINTS))
        if value < 0:
            value += 1 << 16
        yield n, value


def main(argv):
    path = argv[1] if len(argv) > 1 else "sine_4096x16.ver"
    with open(path, "w", encoding="ascii", newline="\n") as f:
        for n, value in build():
            f.write("@%x\n%04x\n" % (n, value))
    print("wrote %s: %d points, amplitude +/-%d" % (path, POINTS, AMPLITUDE))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
