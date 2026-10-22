"""Shared portable paths and tool discovery; no machine-specific install paths."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / 'piano_drums_poly4_shared.gprj'


def local_tools():
    path = ROOT / '.local/tools.json'
    return json.loads(path.read_text(encoding='utf-8')) if path.exists() else {}


def sha(path):
    with Path(path).open('rb') as handle:
        return hashlib.file_digest(handle, 'sha256').hexdigest() if hasattr(hashlib, 'file_digest') else hashlib.sha256(handle.read()).hexdigest()


def active_files():
    return [row.attrib['path'].replace('\\', '/') for row in ET.parse(PROJECT).findall('.//File')
            if row.attrib.get('enable', '1') == '1']


def gowin_ide(value=None):
    value = value or os.environ.get('GOWIN_HOME') or local_tools().get('gowin_home')
    if value:
        root = Path(value).expanduser().resolve()
        candidates = [root, root / 'IDE']
    else:
        executable = shutil.which('gw_sh') or shutil.which('gw_sh.exe')
        candidates = [Path(executable).resolve().parent.parent] if executable else []
    for path in candidates:
        if any((path / 'bin' / name).is_file() for name in ('gw_sh.exe', 'gw_sh')):
            return path
    raise RuntimeError('Set GOWIN_HOME to your Gowin installation, or pass --gowin-home.')


def tool(directory, *names):
    for name in names:
        candidate = Path(directory) / name
        if candidate.is_file():
            return candidate
    raise FileNotFoundError('Missing executable: ' + ', '.join(names))


def tcl_path(path):
    value = Path(path).resolve().as_posix()
    if any(char in value for char in '{}\n\r'):
        raise ValueError('Tcl paths must not contain braces or newlines')
    return '{' + value + '}'
