"""源小节核对凭据；延音链的全部源小节通过后，才确认对应演奏音符。"""
import copy
from .score_audit import audit
from .score_document import xml_root


def snapshot(document):
    root=xml_root(document.current_xml);issues,measures,_=audit(root);note_bars={}
    by_key={(m['part'],m['index']):m for m in measures}
    for part in root.findall('part'):
        for index,measure in enumerate(part.findall('measure')):
            key=by_key[part.get('id'),index]['id']
            for note in measure.findall('note'):
                if note.get('id'):note_bars[note.get('id')]=key
    bad={(i['part'],i['measure']) for i in issues if i['severity']=='error'}
    valid={m['id'] for m in measures if document.reviewed_measures.get(m['id'])==m['content_hash'] and (m['part'],m['measure']) not in bad}
    return issues,measures,note_bars,valid


def mark_measure(song,measure_id,confirmed=True):
    after=copy.deepcopy(song);document=after.score_document
    if document is None:raise ValueError('请先生成或导入MusicXML谱面')
    issues,measures,note_bars,valid=snapshot(document)
    current=next((m for m in measures if m['id']==measure_id),None)
    if current is None:raise ValueError('源小节身份已变化，请刷新列表')
    if confirmed:
        errors=[i['message'] for i in issues if (i['severity']=='error' or i['code'] in ('missing_tempo','missing_meter')) and (i['part']=='*' or i['part']==current['part'] and i['measure']==current['measure'])]
        if errors:raise ValueError('请先修复本小节结构错误：'+'；'.join(errors))
        document.reviewed_measures[measure_id]=current['content_hash'];valid.add(measure_id)
    else:document.reviewed_measures.pop(measure_id,None);valid.discard(measure_id)
    for note in after.notes:
        chain=document.links.get(note.note_id,[note.note_id]);bars={note_bars.get(identifier) for identifier in chain}
        if measure_id not in bars:continue
        note.uncertain=not bars or None in bars or not bars.issubset(valid)
    after.revision+=1
    return after
