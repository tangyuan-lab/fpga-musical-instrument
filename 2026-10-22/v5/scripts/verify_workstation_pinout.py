"""核对Gowin实际PnR引脚报告与用户确认的双片MCP3208接线。"""
from pathlib import Path
import argparse,hashlib,html,json,re

ROOT=Path(__file__).resolve().parents[1]

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--target',choices=('instrument_workstation','instrument_workstation_v2'),default='instrument_workstation')
    target=parser.parse_args().target
    config=json.loads((ROOT/'config/instrument_registry.json').read_text(encoding='utf-8'))
    report=ROOT/f'build/gowin/{target}/impl/pnr/{target}.pin.html'
    rows={}
    for row in re.findall(r'<tr[^>]*>(.*?)</tr>',report.read_text(encoding='utf-8'),re.S|re.I):
        cells=[html.unescape(re.sub(r'<[^>]*>','',cell)).strip()
               for cell in re.findall(r'<td[^>]*>(.*?)</td>',row,re.S|re.I)]
        if cells:rows[cells[0]]=cells
    actual={}
    expected={}
    for chip,group in enumerate(config['pressure_inputs']['spi_pins']):
        for role,pin in group.items():
            expected[f'mcp{chip}_{role}']=(pin,'in' if role=='miso' else 'out')
    if target=='instrument_workstation_v2':
        expected.update(hp_bck=('T21','out'),hp_ws=('U21','out'),hp_din=('P16','out'),
            screen_tx_o=('C18','out'),screen_rx_i=('C19','in'),uart_tx_o=('U15','out'),uart_rx_i=('V14','in'))
    for name,(pin,direction) in expected.items():
        cells=rows.get(name)
        if not cells or len(cells)<8:raise ValueError(f'引脚报告缺少{name}')
        # Gowin端口报告依次为名称、差分、管脚/Bank、用户约束、方向、IOB、复用功能、IO标准。
        ball=cells[2].split('/')[0]
        if (ball,cells[4],cells[7])!=(pin,direction,'LVCMOS33'):
            raise ValueError(f'{name}编译映射不符：{ball}/{cells[4]}/{cells[7]}，预期{pin}/{direction}/LVCMOS33')
        actual[name]={'pin':ball,'direction':cells[4],'io_type':cells[7]}
    output=ROOT/f'build/{target}_spi_pinout_verification.json'
    output.write_text(json.dumps({'passed':True,'report':str(report),'report_sha256':hashlib.sha256(report.read_bytes()).hexdigest(),'pins':actual},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'PASS {target} actual pin report: {len(actual)} pins / input-output directions / LVCMOS33')

if __name__=='__main__':main()
