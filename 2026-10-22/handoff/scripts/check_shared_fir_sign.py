"""Check the actual mapped FIR coefficient lookup in each of four voices."""
from pathlib import Path
import argparse
import hashlib
import json
import re

ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'diagnostics/poly4_shared_20261015'


def check_source(overrides=None):
    name='src/poly4_shared/shared_C_core.v'
    source=ROOT/(overrides or {}).get(name,name)
    code=re.sub(r'//[^\n]*|/\*[\s\S]*?\*/','',source.read_text(encoding='utf-8'))
    if re.search(r'\bfir\s*\[[^\]]+\]\s*\[',code):
        raise RuntimeError('Known Gowin FIR sign synthesis regression: read the whole coefficient before selecting its sign bit. See fir_signed_read_probe/README.md.')


def check_netlist(netlist):
    text=netlist.read_text()
    memory=ROOT/'src/excitation_v3/fir_odd_32x24.mem'
    expected=[int(x,16) for x in memory.read_text().split()]
    records=[]
    for module in ('shared_C_core','shared_C_core_0','shared_C_core_1','shared_C_core_2'):
        match=re.search(r'\bmodule '+module+r'\s*\([\s\S]*?endmodule',text)
        if not match:raise RuntimeError('Missing mapped voice: '+module)
        source=match.group();init={};drivers={}
        for name,width,digits in re.findall(r'defparam\s+(\S+)\.INIT=(\d+)\x27h([0-9a-fA-F]+);',source):
            init[name]=int(digits,16)
        for cell in re.finditer(r'^  (LUT\d|MUX2_LUT\d|INV|GND|VCC)\s+(\S+)\s*\(([\s\S]*?)\);',source,re.M):
            kind,name,ports=cell.groups()
            ports=dict(re.findall(r'\.(\w+)\(([^()]*)\)',ports))
            output=ports.get('F',ports.get('O',ports.get('G',ports.get('V'))))
            drivers[output]=(kind,name,ports)
        actual=[];leaves=set()
        for tag in range(32):
            cache={}
            def bit(signal):
                if signal in cache:return cache[signal]
                address=re.fullmatch(r'fir_read_tag(?:_\d+)?\[(\d+)\]',signal)
                if address:
                    leaves.add(signal)
                    return (tag>>int(address[1]))&1
                if signal not in drivers:raise RuntimeError('Unsupported coefficient cone leaf '+module+': '+signal)
                kind,name,ports=drivers[signal]
                if kind=='GND':value=0
                elif kind=='VCC':value=1
                elif kind=='INV':value=1-bit(ports['I'])
                elif kind.startswith('MUX2'):value=bit(ports['I1']) if bit(ports['S0']) else bit(ports['I0'])
                else:
                    index=sum(bit(ports['I'+str(i)])<<i for i in range(int(kind[3:])))
                    value=(init[name]>>index)&1
                cache[signal]=value
                return value
            actual.append(sum(bit(f'fir_coefficient_word[{i}]')<<i for i in range(24)))
        records.append(dict(module=module,tag_leaves=sorted(leaves),rows=32,passed=actual==expected,
                            mismatches=[dict(index=i,got=hex(a),expected=hex(b)) for i,(a,b) in enumerate(zip(actual,expected)) if a!=b]))
    return dict(netlist_sha256=hashlib.sha256(netlist.read_bytes()).hexdigest(),
                memory_sha256=hashlib.sha256(memory.read_bytes()).hexdigest(),
                passed=all(row['passed'] for row in records),total_rows=128,records=records,
                method='Evaluate mapped LUT/INV/MUX cones for all FIR addresses in all four cores; the only variable leaves are five FIR address bits.')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--netlist', type=Path, required=True, help='Mapped .vg from a normal RTL build')
    parser.add_argument('--output', type=Path)
    args=parser.parse_args()
    result=check_netlist(args.netlist.resolve())
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(result,indent=2)+'\n')
    print(f"Mapped coefficient addresses: {result['total_rows']}; passed={result['passed']}")
    if not result['passed']:raise SystemExit(1)


if __name__=='__main__':main()
