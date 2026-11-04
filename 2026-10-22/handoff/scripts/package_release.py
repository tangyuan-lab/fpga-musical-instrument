"""Export source or the known v74 local release bundle; no network publication."""
from pathlib import Path
import argparse
import hashlib
import json
import subprocess
import zipfile

from project_common import ROOT, sha
from check_project import check


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('kind', choices=['source', 'v74'])
    args = parser.parse_args()
    check(strict_source=True, firmware=args.kind == 'v74')
    out = ROOT / 'releases'
    out.mkdir(exist_ok=True)
    if args.kind == 'source':
        result = subprocess.run(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'],
                                cwd=ROOT, capture_output=True, check=True)
        files = sorted(set(x.decode('utf-8') for x in result.stdout.split(b'\0') if x))
        assert files and 'README.md' in files
        assert not any(Path(p).suffix.lower() in {'.exe', '.dll', '.fs', '.vvp', '.pr', '.wav', '.flac'} for p in files)
        assert not any((ROOT / p).stat().st_size > 50 * 1024**2 for p in files)
        paths = [(ROOT / p, p) for p in files]
        target = out / 'tang_mega_60k_contest_source_20261019.zip'
    else:
        folder = out / 'v74_board_bundle'
        paths = [(p, p.relative_to(folder).as_posix()) for p in folder.rglob('*') if p.is_file()]
        assert paths and sha(folder / 'v74.fs') == '8e2318a08def7c6200c658e196b8b295555513fd32d5a44823d02075831be249'
        target = out / 'v74_board_bundle_20261019.zip'
    for path, name in paths:
        assert path.is_file() and not path.is_symlink()
        assert not Path(name).is_absolute() and '..' not in Path(name).parts
    with zipfile.ZipFile(target, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for path, name in paths:
            archive.write(path, name)
    with zipfile.ZipFile(target) as archive:
        assert archive.testzip() is None
        for path, name in paths:
            assert hashlib.sha256(archive.read(name)).hexdigest() == sha(path)
    record = dict(package=target.relative_to(ROOT).as_posix(), files=len(paths), bytes=target.stat().st_size,
                  sha256=sha(target), upload_performed=False)
    manifest_path = out / 'package_manifest.json'
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    manifest[args.kind] = record
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8', newline='\n')
    print(json.dumps(record, indent=2))


if __name__ == '__main__':
    main()
