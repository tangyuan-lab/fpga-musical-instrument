"""仅发布通过全部门禁的V2候选位流；不连接板卡、不烧录。"""
from pathlib import Path
from datetime import datetime,timezone
import argparse,html,json,re,shutil,sys
from build_workstation_v2_incremental import ROOT,NAME,sha,changed_inputs,timing_result,pin_result


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('report',type=Path)
    args=parser.parse_args()
    report_path=args.report.resolve()
    if not report_path.is_relative_to((ROOT/'build/gowin').resolve()):
        raise ValueError('候选报告必须位于本工程build/gowin内')
    report=json.loads(report_path.read_text(encoding='utf-8'))
    if report.get('passed') is not True or report.get('status')!='PASS' or report.get('returncode')!=0:
        raise ValueError('候选尚未完整通过，禁止发布')
    folder=report_path.parent
    if Path(report['output']).resolve()!=folder:
        raise ValueError('候选输出路径与报告不一致')
    frozen_path=Path(report['frozen_inputs']).resolve()
    if frozen_path!=folder/'frozen_inputs.json':
        raise ValueError('冻结输入清单位置不符')
    frozen=json.loads(frozen_path.read_text(encoding='utf-8'))
    changes=changed_inputs(frozen)
    if changes:raise ValueError(f'候选运行后输入发生变化：{changes}')
    expected={'bitstream':'.fs','timing':'_tr_content.html','pinout':'.pin.html','implementation':'.rpt.txt'}
    artifacts={}
    for kind,suffix in expected.items():
        path=folder/'impl/pnr'/(NAME+suffix)
        item=report['artifacts'][kind]
        if Path(item['path']).resolve()!=path or sha(path)!=item['sha256']:
            raise ValueError(f'候选产物位置或摘要不符：{kind}')
        artifacts[kind]=path
    timing_text=artifacts['timing'].read_text(encoding='utf-8')
    timing=timing_result(timing_text)
    if timing!={'setup':0,'hold':0} or timing!=report['timing']:
        raise ValueError('实际时序不是Setup/Hold 0/0')
    readable=re.sub(r'\s+',' ',html.unescape(re.sub('<[^>]*>',' ',timing_text)))
    if 'sys_clk Base 20.000 50.000' not in readable:
        raise ValueError('实际时序报告缺少50MHz/20ns系统时钟')
    pins=pin_result(artifacts['pinout'].read_text(encoding='utf-8'))
    if pins!=report['pins']:raise ValueError('实际引脚与验收记录不符')
    implementation=artifacts['implementation'].read_text(encoding='utf-8')
    if 'GW5AT-LV60PG484AC1/I0' not in implementation or re.search(r'\bERROR\s*\(|\b[1-9]\d*\s+unrouted\b',implementation,re.I):
        raise ValueError('器件或实际布通报告不符')
    ready=ROOT/'build/ready-to-program';ready.mkdir(exist_ok=True)
    target=ready/(NAME+'_sram.fs');digest=sha(artifacts['bitstream'])
    # 原发布版本可恢复；只有完成所有校验后才接触烧录目录。
    if target.is_file() and sha(target)!=digest:
        backup=ready/'previous';backup.mkdir(exist_ok=True)
        old_digest=sha(target);shutil.copyfile(target,backup/(NAME+'_'+old_digest[:16]+'.fs'))
        for suffix in ('.sha256','.sources.json','.build.json'):
            previous=Path(str(target)+suffix)
            if previous.is_file():shutil.copyfile(previous,backup/(NAME+'_'+old_digest[:16]+suffix))
    temporary=Path(str(target)+'.tmp');shutil.copyfile(artifacts['bitstream'],temporary)
    if sha(temporary)!=digest:raise ValueError('发布复制后的位流摘要不符')
    temporary.replace(target)
    Path(str(target)+'.sha256').write_text(digest+'\n',encoding='ascii')
    binding=dict(frozen)
    for path in (Path(__file__).resolve(),report_path,frozen_path,*artifacts.values()):binding[str(path)]=sha(path)
    Path(str(target)+'.sources.json').write_text(json.dumps(binding,ensure_ascii=False,indent=2),encoding='utf-8')
    publication=dict(passed=True,published_utc=datetime.now(timezone.utc).isoformat(),bitstream=str(target),sha256=digest,
        candidate_report=str(report_path),candidate_report_sha256=sha(report_path),timing=timing,pins=pins,
        system_clock_hz=50000000,voices=32,audio_format='Philips I2S; 48828.125Hz; 32-bit slots; 16-bit audio',
        board_programmed=False,hardware_acceptance='待外部标准I2S DAC与整机实测')
    Path(str(target)+'.build.json').write_text(json.dumps(publication,ensure_ascii=False,indent=2),encoding='utf-8')
    print(f'PASS published {target}\nSHA256={digest}\nSetup/Hold=0/0; pins={len(pins)}; board not programmed')
    return 0

if __name__=='__main__':
    if hasattr(sys.stdout,'reconfigure'):sys.stdout.reconfigure(encoding='utf-8')
    try:raise SystemExit(main())
    except (OSError,ValueError,KeyError) as error:
        print(f'BLOCKED: {error}',file=sys.stderr);raise SystemExit(1)
