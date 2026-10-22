"""生成 TJC 三位十六进制解析事件，避免 covx 对连续奇数位 HEX 的截断。"""


def decode_hex12(source, destination, scratch="hexDigit"):
    # FPGA 压力固定为 000..FFF 的三个大写 ASCII 字符，无空格。
    # 官方 covx HEX 输入按字节读取，FFF 在当前模拟器得到 FF=255；
    # 逐位取字符并累加 16 进制值，才能保留 12 位量程 0..4095。
    # sys2 记录有效位数，调用者仅在 sys2==3 时更新显示与峰值。
    lines = ["sys1=0", "sys2=0"]
    for position in range(3):
        lines += [f"substr {source},{scratch}.txt,{position},1", "sys0=-1"]
        for value, digit in enumerate("0123456789ABCDEF"):
            lines += [f'if({scratch}.txt=="{digit}")', "{", f"sys0={value}", "}"]
        lines += ["sys1=sys1*16", "if(sys0>=0)", "{", "sys1=sys1+sys0", "sys2++", "}"]
    lines += [f"{destination}=sys1"]
    return lines
