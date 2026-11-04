"""Run existing input/output and arithmetic regressions with Icarus Verilog.

Vendor primitive models are extracted from the locally installed Gowin library
into ignored build output; they are never copied into the source repository.
"""
from pathlib import Path
import argparse
import datetime
import json
import os
import re
import shutil
import subprocess

from project_common import ROOT, active_files, gowin_ide, sha, tool, local_tools
from check_project import check


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--iverilog-dir')
    parser.add_argument('--gowin-home')
    parser.add_argument('--suite', choices=['basic', 'smoke', 'engine'], default='basic')
    args = parser.parse_args()
    check()
    directory = args.iverilog_dir or os.environ.get('IVERILOG_BIN') or local_tools().get('iverilog_bin')
    if not directory:
        local = ROOT / '.tools/iverilog/app/bin'
        directory = local if local.exists() else Path(shutil.which('iverilog') or 'iverilog').parent
    iverilog = tool(directory, 'iverilog.exe', 'iverilog')
    vvp = tool(directory, 'vvp.exe', 'vvp')
    out = ROOT / 'build' / datetime.datetime.now().strftime('tests_%Y%m%d_%H%M%S_%f')
    out.mkdir(parents=True)
    cases = [
        ('key16', 'tb_key16_note_map', ['integration/keyboard_16/key16_note_map.v', 'integration/keyboard_16/tb_key16_note_map.sv'], []),
        ('integer_rules', 'tb_integer_rules', ['integration/poly4_shared/tb_integer_rules.sv'], []),
        ('i2s', 'tb_i2s_tx_16', ['integration/i2s/i2s_tx_16.v', 'sim/tb_i2s_tx_16.sv'], []),
    ]
    if args.suite != 'basic':
        ide = gowin_ide(args.gowin_home)
        library = ide / 'simlib/gw5a/prim_sim.v'
        text = library.read_text(encoding='utf-8')
        vendor = out / 'vendor_primitives.v'
        definitions = []
        for primitive in ('MULT27X36', 'MULTALU27X18', 'GSR'):
            match = re.search(r'^module\s+' + primitive + r'\b[\s\S]*?^endmodule', text, re.M)
            assert match, 'Vendor primitive missing: ' + primitive
            definitions.append(match[0])
        vendor.write_text('\n'.join(definitions) + '\n', encoding='utf-8', newline='\n')
        (out / 'vendor_origin.json').write_text(json.dumps(dict(original_path=library.as_posix(),
                original_sha256=sha(library), extraction='Unmodified named modules; local test use only'), indent=2) + '\n')
        cases.append(('fir_mac', 'tb_fir_mac', [str(vendor), 'src/poly4_shared/shared_fir_mac.v', 'integration/poly4_shared/tb_fir_mac.sv'], []))
        for cycles in (2, 3):
            for mode in (0, 1):
                cases.append((f'resources_c{cycles}_m{mode}', 'tb_resource_stress',
                    [str(vendor), 'integration/poly4_shared/SP_model.v', 'src/poly4_shared/shared_voice_ram.v',
                     'src/poly4_shared/shared_voice_mul.v', 'integration/poly4_shared/tb_resource_stress.sv'],
                    [f'RESPONSE_CYCLES={cycles}', f'PIANO_SECOND_LANE={mode}']))
    if args.suite == 'engine':
        print('Diagnostic engine suite: existing startup assertion is not yet qualified; see docs/VALIDATION.md.', flush=True)
        files = [str(vendor), 'integration/poly4_shared/SP_model.v'] + [p for p in active_files() if p.endswith('.v')]
        files += ['src/excitation_v3/piano_C_pipelined_voice.v', 'src/shared/tom_shared_voice.v',
                  'src/single_voice/tom_C_audition_core.v', 'src/excitation_v3/C_packet_math.v',
                  'src/excitation_v3/tom_C_voice.v', 'src/rimshot_audition/instrument_rimshot_slot.v',
                  'src/rimshot_audition/shared_parameter_ports.v', 'integration/poly4_shared/reference_parameters.sv',
                  'integration/poly4_shared/reference_engine.sv', 'integration/poly4_shared/tb_engine.sv']
        cases.append(('engine_short', 'tb_engine', files, ['CASE=0', 'FRAMES=64']))
    results = []
    for name, top, files, params in cases:
        binary = out / (name + '.vvp')
        command = [str(iverilog), '-g2012', '-I', str(ROOT), '-s', top, '-o', str(binary)]
        command += ['-P' + top + '.' + p for p in params] + files
        with (out / (name + '.compile.log')).open('wb') as log:
            result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=180)
        assert result.returncode == 0, 'Compile failed: ' + str(out / (name + '.compile.log'))
        with (out / (name + '.log')).open('wb') as log:
            result = subprocess.run([str(vvp), str(binary)], cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=300)
        output = (out / (name + '.log')).read_text(errors='replace')
        passed = result.returncode == 0 and 'PASS' in output and 'FATAL' not in output and 'ERROR:' not in output
        results.append(dict(name=name, passed=passed, params=params, log_sha256=sha(out / (name + '.log'))))
        (out / 'results.json').write_text(json.dumps(dict(suite=args.suite, passed=all(x['passed'] for x in results), results=results), indent=2) + '\n')
        print(('PASS ' if passed else 'FAIL ') + name, flush=True)
        assert passed, output[-4000:]
    print('All ' + str(len(results)) + ' regressions passed. No board access.', flush=True)


if __name__ == '__main__':
    main()
