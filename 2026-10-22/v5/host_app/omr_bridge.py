"""可取消的kern→MusicXML桥；转换结果仍是待校正候选。"""
from pathlib import Path
import os
from .process_job import run_tool


def convert_kern(source,folder,cancel=None):
    root=Path(__file__).resolve().parents[1];source=Path(source).resolve();folder=Path(folder).resolve()
    python=Path(os.environ.get('FPGA_OMR_BRIDGE_PYTHON',str(root/'build/tools/omr_bridge/Scripts/python.exe')))
    if not python.is_file():raise RuntimeError('缺少隔离的kern转换环境，请运行 python scripts/prepare_omr_bridge.py')
    if not source.is_file():raise FileNotFoundError(source)
    target=folder/'candidate.musicxml'
    run_tool([str(python),str(root/'scripts/convert_kern_candidate.py'),str(source),str(target)],folder,cancel=cancel,timeout=120,memory_mib=1024)
    if not target.is_file():raise RuntimeError('转换器未生成MusicXML，请查看process.log')
    return target
