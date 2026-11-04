"""在隔离环境中转换OMR原始kern；不识谱、不补速度/力度、不确认任何音符。"""
from pathlib import Path
import argparse,hashlib,importlib.metadata,json


def main():
    parser=argparse.ArgumentParser();parser.add_argument('source');parser.add_argument('target');args=parser.parse_args()
    import converter21
    from music21 import converter
    source=Path(args.source).resolve();target=Path(args.target).resolve();target.parent.mkdir(parents=True,exist_ok=True)
    converter21.register();score=converter.parse(str(source),format='humdrum',forceSource=True)
    score.write('musicxml',fp=str(target))
    manifest=dict(source=str(source),source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
        output_sha256=hashlib.sha256(target.read_bytes()).hexdigest(),
        versions={p:importlib.metadata.version(p) for p in ('music21','converter21')},
        review='unconfirmed',recognition=False)
    target.with_suffix('.bridge.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(manifest,ensure_ascii=True))

if __name__=='__main__':main()
