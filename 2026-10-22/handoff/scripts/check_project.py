"""Check portable project dependencies, immutable ROM data and optional firmware."""
from pathlib import Path
import argparse
import json
import re

from project_common import ROOT, active_files, sha


def check(strict_source=False, firmware=False):
    manifest = json.loads((ROOT / 'docs/source_manifest.json').read_text(encoding='utf-8'))
    required = active_files()
    for name in required:
        path = ROOT / name
        assert path.is_file(), 'Missing project input: ' + name
        if path.suffix == '.v':
            code = re.sub(r'//[^\n]*|/\*[\s\S]*?\*/', '', path.read_text(encoding='utf-8'))
            assert not re.search(r'\$readmem[hb]\s*\(\s*"(?:[A-Za-z]:[/\\]|/)', code), 'Absolute ROM path: ' + name
            for memory in re.findall(r'"([^"\n]+\.mem)"', code):
                assert (ROOT / memory).is_file(), 'Missing ROM: ' + memory
            for include in re.findall(r'`include\s+"([^"]+)"', code):
                assert (ROOT / include).is_file() or (path.parent / include).is_file(), 'Missing include: ' + include
    for name, digest in manifest['parameters_sha256'].items():
        assert sha(ROOT / name) == digest, 'Frozen parameter changed: ' + name
    source_changes = [name for name, digest in manifest['source_sha256'].items() if sha(ROOT / name) != digest]
    if strict_source:
        assert not source_changes, 'Source snapshot changed: ' + repr(source_changes)
    core = (ROOT / 'src/poly4_shared/shared_C_core.v').read_text(encoding='utf-8')
    core = re.sub(r'//[^\n]*|/\*[\s\S]*?\*/', '', core)
    assert not re.search(r'\bfir\s*\[[^\]]+\]\s*\[', core), 'Nested FIR bit selection reintroduced'
    assert 'fir_coefficient_word' in core
    firmware_checked = []
    if firmware:
        for row in json.loads((ROOT / 'checkpoints/manifest.json').read_text())['files']:
            assert sha(ROOT / row['path']) == row['sha256'], 'Firmware hash mismatch: ' + row['path']
            firmware_checked.append(row['path'])
    return dict(passed=True, project_inputs=len(required), parameters_checked=len(manifest['parameters_sha256']),
                changed_source_files=source_changes, strict_source=strict_source,
                firmware_checked=firmware_checked, board_accessed=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--strict-source', action='store_true')
    parser.add_argument('--check-firmware', action='store_true')
    parser.add_argument('--report', type=Path)
    args = parser.parse_args()
    result = check(args.strict_source, args.check_firmware)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))
