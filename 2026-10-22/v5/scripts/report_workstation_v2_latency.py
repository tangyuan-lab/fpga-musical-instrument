"""汇总完整V2数字链路实测仿真；只接受6例全部完成且源文件未晚于编译产物的日志。"""
from pathlib import Path
from datetime import datetime,timezone
import hashlib,json,os,re,subprocess
ROOT=Path(__file__).resolve().parents[1]
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def canonical_program(path):
    # Icarus标签包含编译进程内存地址；仅双射重命名这些符号，保留所有指令、常量、引用关系及字符串。
    symbols={}
    def rename(match):
        symbol=match.group(0)
        if symbol not in symbols:symbols[symbol]=match.group(1)+'ID'+str(len(symbols))
        return symbols[symbol]
    parts=re.split(r'("(?:\\.|[^"\\])*")',path.read_text(encoding='utf-8'))
    for index in range(0,len(parts),2):parts[index]=re.sub(r'\b([A-Za-z]+_?)[0-9a-f]{16}(?=\b|_)',rename,parts[index])
    return ''.join(parts)

def main():
    log=ROOT/'build/tests/tb_workstation_v2_latency.log';compiled=ROOT/'build/tests/tb_workstation_v2_latency.vvp'
    text=log.read_text(encoding='utf-8');cases=[dict(case=int(a),key=int(b),ms=float(c))
        for a,b,c in re.findall(r'V2_LATENCY case=(\d+) key=(\d+) ms=([\d.]+)',text)]
    if 'PASS tb_workstation_v2_latency' not in text or [r['case'] for r in cases]!=list(range(6)):
        raise RuntimeError('完整顶层延迟测试尚未通过6个用例')
    tcl=(ROOT/'gowin/build_instrument_workstation_v2.tcl').read_text(encoding='utf-8')
    sources=[ROOT/'rtl'/s.replace(' ','/') for s in re.findall(r'add_file -type verilog \[file join \$root rtl (.*?)\]',tcl)]
    sources=[p for p in sources if p.name not in ('video_pll.sv','DVI_TX_Top.v')]
    sources.extend(ROOT/p for p in ('tests/models/video_elaboration_stubs.sv','tests/models/sdpb_model.sv','tests/mcp3208_dynamic_model.sv','tests/tb_workstation_v2_latency.sv'))
    binding='Current source mtimes no later than compiled simulation; hashes recorded below'
    if any(p.stat().st_mtime_ns>compiled.stat().st_mtime_ns for p in sources):
        # prepare可能重写内容相同的生成文件；重新编译后符号重命名之外完全一致才复用结果。
        verified=compiled.with_name(compiled.stem+'_source_check.vvp');tools=Path(__import__('os').environ.get('FPGA_SIM_BIN','C:/msys64/ucrt64/bin'))
        env=os.environ.copy();env['PATH']=str(tools)+os.pathsep+env['PATH']
        subprocess.run([str(tools/'iverilog.exe'),'-g2012','-s','tb_workstation_v2_latency','-o',str(verified),
            *[p.relative_to(ROOT).as_posix() for p in sources]],cwd=ROOT,env=env,check=True,timeout=120)
        if canonical_program(verified)!=canonical_program(compiled):raise RuntimeError('当前源文件重新编译后与已测试模型不同，请重新运行完整测试')
        binding='Fresh compilation matches tested VVP after bijective renaming of Icarus address-based symbol labels; constants, instructions, edges and literals unchanged'
    def summary(rows):
        values=[r['ms'] for r in rows]
        return dict(min_ms=min(values),max_ms=max(values),range_ms=max(values)-min(values))
    report=dict(status='passed',created_utc=datetime.now(timezone.utc).isoformat(),
        evidence='Full V2 RTL digital path; not hardware latency measurement',
        clock_hz=50_000_000,spi_hz=1_000_000,uart_baud=115200,sample_rate_hz=50_000_000/1024,
        calibration_frames=4,cases=cases,physical=summary(cases[:4]),uart=summary(cases[4:]),
        exclusions=['FSR analog response and RC filter','screen touch scanning','DAC/amplifier','32-voice/effects/UI concurrent worst-case latency'],
        source_binding=binding,
        compiled_vvp_sha256=digest(compiled),log_sha256=digest(log),
        sources={p.relative_to(ROOT).as_posix():digest(p) for p in sources})
    if any(c['ms']>10 for c in cases):raise RuntimeError('存在超过10ms的数字起音')
    (ROOT/'build/tests/workstation_v2_latency.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    print(f"PASS V2 digital latency: physical max={report['physical']['max_ms']:.6f}ms, UART max={report['uart']['max_ms']:.6f}ms")
if __name__=='__main__':main()
