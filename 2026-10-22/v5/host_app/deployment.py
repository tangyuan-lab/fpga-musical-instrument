"""设备提交凭据。编辑撤销、电脑混音与设备发布版本使用不同的身份。"""
from __future__ import annotations

import copy
import hashlib
import json
from dataclasses import dataclass

from .device_v2 import display_name


def _digest(parts):
    h = hashlib.sha256()
    for part in parts:
        data = part if isinstance(part, bytes) else json.dumps(part, sort_keys=True, ensure_ascii=False).encode('utf-8')
        h.update(len(data).to_bytes(8, 'little')); h.update(data)
    return h.hexdigest()


def patch_digest(patch):
    # ADSR 在 BEGIN 头中，不能仅比较波表 CRC。显示名也属于设备可见内容。
    return _digest([patch.resource_id, display_name(patch.name), patch.binary(),
                    [patch.attack, patch.decay, patch.sustain, patch.release]])


def song_digest(song, project):
    dependencies = sorted({n - 2 for section in song.sections
                           for n in section.timbres + [section.live_timbre] if n >= 2})
    if any(n >= len(project.patches) for n in dependencies):
        raise ValueError('配器引用的音色不存在')
    return _digest([song.resource_id, display_name(song.name), song.midi(), song.arrangement(),
                    song.duration, [(n, patch_digest(project.patches[n])) for n in dependencies]])


@dataclass(frozen=True)
class Receipt:
    kind: int
    slot: int
    resource_id: str
    revision: int
    digest: str


class DeploymentSession:
    """旧协议没有内容回读：只有本连接完整上传并核对后才建立凭据。"""
    def __init__(self):
        self.receipts = {}
        self.highwater = {}

    def reset(self):
        self.receipts.clear()

    def prepare(self, project, catalog=()):
        project.validate()
        snapshot = copy.deepcopy(project)
        for entry in catalog:
            rid = entry['resource_id']
            self.highwater[rid] = max(self.highwater.get(rid, 0), entry['revision'])
        for item in snapshot.songs + snapshot.patches:
            revision = max(item.revision, self.highwater.get(item.resource_id, 0),
                           project.publication_versions.get(item.resource_id, 0)) + 1
            if revision > 0xffffffff:
                raise ValueError('设备发布版本已耗尽，请复制为新资源')
            item.revision = revision
            self.highwater[item.resource_id] = revision
            project.publication_versions[item.resource_id] = revision
        return snapshot

    def accept(self, snapshot, catalog):
        pending = {}
        for kind, items in ((0, snapshot.songs), (1, snapshot.patches)):
            for slot, item in enumerate(items):
                match = next((c for c in catalog if c['kind'] == kind and c['slot'] == slot
                              and c.get('ready') and c['resource_id'] == item.resource_id
                              and c['revision'] == item.revision), None)
                if match is None:
                    self.reset()
                    raise ValueError('上传 ACK 后设备目录未确认全部资源，未建立同步凭据')
                digest = song_digest(item, snapshot) if kind == 0 else patch_digest(item)
                pending[kind, item.resource_id] = Receipt(kind, slot, item.resource_id, item.revision, digest)
        self.receipts = pending

    def song_match(self, song, project, catalog):
        receipt = self.receipts.get((0, song.resource_id))
        if receipt is None:
            return None
        try:
            if song_digest(song, project) != receipt.digest:
                return None
            # 歌曲内容相同仍需核对自定义音色的目录版本，防止被屏幕/其他会话替换。
            deps = {n - 2 for section in song.sections for n in section.timbres + [section.live_timbre] if n >= 2}
            required = [receipt]
            for slot in deps:
                patch = project.patches[slot]
                p = self.receipts.get((1, patch.resource_id))
                if p is None or p.slot != slot or p.digest != patch_digest(patch):
                    return None
                required.append(p)
            for p in required:
                if not any(c['kind'] == p.kind and c['slot'] == p.slot and c.get('ready')
                           and c['resource_id'] == p.resource_id and c['revision'] == p.revision for c in catalog):
                    return None
        except (ValueError, IndexError):
            return None
        return next(c for c in catalog if c['kind'] == 0 and c['slot'] == receipt.slot)
