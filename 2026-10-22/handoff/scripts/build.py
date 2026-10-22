"""Build a fresh RTL snapshot; never overwrite known firmware or program a board."""
import argparse
import datetime
import json
from pathlib import Path
import shutil
import subprocess

from project_common import ROOT, active_files, gowin_ide, tool, tcl_path, sha
from check_project import check


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--gowin-home')
    parser.add_argument('--phase', choices=['syn', 'pnr'], default='syn')
    parser.add_argument('--target', choices=['runtime50', 'margin62m5'], default='runtime50')
    args = parser.parse_args()
    check()
    ide = gowin_ide(args.gowin_home)
    name = datetime.datetime.now().strftime('rtl_%Y%m%d_%H%M%S_%f')
    out = ROOT / 'build' / name
    snapshot = out / 'rtl'
    snapshot.mkdir(parents=True)
    # ROMs use project-relative paths. Snapshot their original hierarchy into
    # the generated project's actual working directory before synthesis.
    shutil.copytree(ROOT / 'src', snapshot / 'src')
    files = active_files()
    for path in files:
        if not path.startswith('src/'):
            target = snapshot / path; target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / path, target)
    sdc_name = 'integration/poly4_shared/timing.sdc' if args.target == 'runtime50' else 'integration/poly4_shared/timing_margin_62m5.sdc'
    target = snapshot / sdc_name; target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ROOT / sdc_name, target)
    files = [sdc_name if name.endswith('.sdc') else name for name in files]
    manifest = dict(kind='normal_RTL_build_not_the_board_validated_v74_image', phase=args.phase, target=args.target,
                    user_code='0x00005AB0', source_sha256={p: sha(ROOT / p) for p in active_files()},
                    params_sha256={p.relative_to(ROOT).as_posix(): sha(p) for p in (ROOT / 'src').rglob('*.mem')},
                    gowin_version_path=ide.as_posix(), incremental_pnr=False, board_programmed=False)
    (out / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    script = [f'create_project -name rtl -dir {tcl_path(out)} -pn GW5AT-LV60PG484AC1/I0 -device_version B',
              f'cd {tcl_path(snapshot)}']
    script += ['add_file ' + tcl_path(snapshot / p) for p in files]
    freq = '50.0' if args.target == 'runtime50' else '62.5'
    script += ['set_option -top_module piano_drums_poly4_shared_top',
               'set_option -verilog_std sysv2017', 'set_option -output_base_name instrument',
               'set_option -user_code 00005AB0', 'set_option -opt_goal area',
               f'set_option -global_freq {freq}', 'set_option -map_option 1',
               'set_option -place_option 2', 'set_option -route_option 2',
               'set_option -timing_driven 1', 'set_option -replicate_resources 1',
               'set_option -inc_place 0', 'set_option -inc_pnr 0',
               f'saveto -all_options {tcl_path(out / "effective_options.tcl")}',
               f'if {{[catch {{run {args.phase}}} result]}} {{puts stderr $result;exit 1}}', 'exit 0']
    (out / 'run.tcl').write_text('\n'.join(script) + '\n')
    print('Building ' + out.relative_to(ROOT).as_posix(), flush=True)
    try:
        with (out / 'console.log').open('wb') as log:
            result = subprocess.run([str(tool(ide / 'bin', 'gw_sh.exe', 'gw_sh')), str(out / 'run.tcl')],
                                    cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=3600)
        assert result.returncode == 0, 'Gowin failed; inspect ' + str(out / 'console.log')
        from check_shared_fir_sign import check_netlist
        netlist = snapshot / 'impl/gwsynthesis/instrument.vg'
        sign_result = check_netlist(netlist)
        (out / 'fir_sign_check.json').write_text(json.dumps(sign_result, indent=2) + '\n')
        assert sign_result['passed'], 'Mapped FIR coefficient check failed'
        manifest.update(tool_exit_code=0, mapped_FIR_rows=128, mapped_FIR_passed=True, completed=True)
    except Exception as error:
        manifest.update(completed=False, error=str(error))
        raise
    finally:
        (out / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    (ROOT / 'build/latest.json').write_text(json.dumps(dict(directory=out.relative_to(ROOT).as_posix(), **manifest), indent=2) + '\n')
    print('PASS: source build completed; 128 mapped FIR rows match. Board unchanged.', flush=True)
    if args.phase == 'pnr':
        print('Review all timing/route reports before treating this new image as qualified.', flush=True)


if __name__ == '__main__':
    main()
