"""显示外部音乐组件的安装状态；文件存在不等于外部软件运行验收通过。"""
from pathlib import Path
import importlib.metadata,json

def status_text():
    root=Path(__file__).resolve().parents[1];lines=[]
    def read_manifest(path):
        try:
            data=json.loads(path.read_text(encoding='utf-8')) if path.is_file() else {}
            return data if isinstance(data,dict) else {}
        except (OSError,ValueError):
            lines.append('组件状态文件不可读，请重新运行准备脚本：'+str(path));return {}
    for package,label in [('verovio','五线谱排版'),('partitura','乐谱解析')]:
        try:lines.append(f'{label}：{package} {importlib.metadata.version(package)} 已安装')
        except importlib.metadata.PackageNotFoundError:lines.append(f'{label}：未安装；运行 python scripts/prepare_music_stack.py --install-python')
    manifest=root/'build/tools/music/manifest.json'
    data=read_manifest(manifest)
    for field,label in [('fluidsynth','参考合成器'),('soundfont','默认参考音源'),('musescore','外部校谱器')]:
        path=root/data.get(field,'__missing__')
        lines.append(label+'：'+(str(path) if path.is_file() else '尚未准备；运行 python scripts/prepare_music_stack.py --with-musescore'))
    report=root/'build/tests/musescore_roundtrip/result.json'
    checked=read_manifest(report)
    lines.append('MuseScore 实际往返验证：'+('通过（仅构造样谱）' if checked.get('passed') else '待完成；仍可使用导出/导回按钮与其他 MusicXML 编辑器校谱'))
    full=read_manifest(root/'build/tests/musescore_nocturne/result.json')
    if full.get('passed'):
        lines.append(f'Nocturne 整曲时间线往返：通过（{full.get("input_notes",0)}音符，音高/起止/力度/声部一致）；PDF识谱仍需人工确认')
    bridge=read_manifest(root/'build/tools/omr_bridge/manifest.json')
    if bridge:lines.append('kern 转换桥：已准备；转换通过不表示识谱准确')
    transcoda=read_manifest(root/'build/tools/transcoda_env/manifest.json')
    if transcoda.get('dependency_import_passed'):
        lines.append('Transcoda：依赖导入通过；模型下载暂缓，尚无实际识别结果，未替换默认引擎')
    return '\n'.join(lines)
