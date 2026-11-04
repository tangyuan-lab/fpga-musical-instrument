"""常见和弦音级字典：精确集合识别；根音歧义优先显示最低音对应的候选。

11/13 表示完整叠置，另收录实际演奏常用的省略五音/九音版本。
缺少根音、完全任意的省略音与调性推断不在本字典的识别范围内。
"""
from collections import defaultdict

PC_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
QUALITIES = {
    "": (0,4,7), "m": (0,3,7), "dim": (0,3,6), "aug": (0,4,8),
    "sus2": (0,2,7), "sus4": (0,5,7), "5": (0,7),
    "6": (0,4,7,9), "m6": (0,3,7,9), "6/9": (0,2,4,7,9), "m6/9": (0,2,3,7,9),
    "7": (0,4,7,10), "maj7": (0,4,7,11), "m7": (0,3,7,10),
    "mMaj7": (0,3,7,11), "dim7": (0,3,6,9), "m7b5": (0,3,6,10),
    "aug7": (0,4,8,10), "augMaj7": (0,4,8,11),
    "7sus2": (0,2,7,10), "7sus4": (0,5,7,10), "maj7sus4": (0,5,7,11),
    "add9": (0,2,4,7), "madd9": (0,2,3,7), "add11": (0,4,5,7),
    "madd11": (0,3,5,7), "add#11": (0,4,6,7), "addb9": (0,1,4,7),
    "9": (0,2,4,7,10), "maj9": (0,2,4,7,11), "m9": (0,2,3,7,10),
    "mMaj9": (0,2,3,7,11), "9sus4": (0,2,5,7,10),
    "11": (0,2,4,5,7,10), "maj11": (0,2,4,5,7,11), "m11": (0,2,3,5,7,10),
    "13": (0,2,4,5,7,9,10), "maj13": (0,2,4,5,7,9,11), "m13": (0,2,3,5,7,9,10),
    "13sus4": (0,2,5,7,9,10), "7add13": (0,4,7,9,10), "maj7add13": (0,4,7,9,11),
    "7b5": (0,4,6,10), "7#5": (0,4,8,10), "7b9": (0,1,4,7,10),
    "7#9": (0,3,4,7,10), "7#11": (0,4,6,7,10), "7b13": (0,4,7,8,10),
    "9b5": (0,2,4,6,10), "9#5": (0,2,4,8,10), "9#11": (0,2,4,6,7,10),
    "maj9#11": (0,2,4,6,7,11), "maj7#11": (0,4,6,7,11),
    "m7b9": (0,1,3,7,10), "m9b5": (0,2,3,6,10),
    "7b5b9": (0,1,4,6,10), "7b5#9": (0,3,4,6,10),
    "7#5b9": (0,1,4,8,10), "7#5#9": (0,3,4,8,10),
    "13b9": (0,1,4,7,9,10), "13#9": (0,3,4,7,9,10),
    "13#11": (0,2,4,6,7,9,10), "maj13#11": (0,2,4,6,7,9,11),
    "7alt": (0,1,3,4,6,8,10),
}
# 省略音明确标注，避免把不完整音组伪称为完整叠置和弦。
for _name in ("7", "maj7", "m7", "mMaj7", "9", "maj9", "m9", "mMaj9",
              "11", "maj11", "m11", "13", "maj13", "m13", "7b9", "7#9", "7#11", "7b13"):
    QUALITIES[_name + "(no5)"] = tuple(i for i in QUALITIES[_name] if i != 7)
QUALITIES.update({
    "13(no11)": (0,2,4,7,9,10), "maj13(no11)": (0,2,4,7,9,11),
    "m13(no11)": (0,2,3,7,9,10), "13(no5,11)": (0,2,4,9,10),
    "maj13(no5,11)": (0,2,4,9,11), "m13(no5,11)": (0,2,3,9,10),
})


def chord_table():
    table = defaultdict(list)
    for quality, intervals in QUALITIES.items():
        assert len(intervals) == len(set(intervals)) and 0 in intervals
        for root in range(12):
            mask = sum(1 << ((root + step) % 12) for step in intervals)
            name = PC_NAMES[root] + quality
            if name not in table[mask]:
                table[mask].append(name)
    return dict(table)


def root_of(name):
    return next(pc for pc in sorted(PC_NAMES, key=len, reverse=True) if name.startswith(pc))


def display_label(names, bass=None):
    preferred = [name for name in names if root_of(name) == bass] if bass is not None else []
    candidates = preferred or names
    result = candidates[0]
    for name in candidates[1:]:
        if len(result) + len(name) + 1 > 18:
            result = candidates[0] + (" /+" if len(candidates[0]) <= 15 else "+")
            break
        result += "/" + name
    assert len(result) <= 18
    return result


def lookup_code(branch,formatter=display_label):
    """平衡二叉查表：只在音组变化时运行，每次至多十余次 mask 比较。"""
    def leaf(mask, names):
        lines = [f'chordTxt.txt="{formatter(names)}"']
        for pc, root in enumerate(PC_NAMES):
            if any(root_of(name) == root for name in names):
                lines += branch(f"bassPc.val=={pc}", [f'chordTxt.txt="{formatter(names, root)}"'])
        return branch(f"pcMask.val=={mask}", lines)

    def tree(items):
        if len(items) == 1:
            return leaf(*items[0])
        middle = len(items)//2
        return branch(f"pcMask.val<{items[middle][0]}", tree(items[:middle]), tree(items[middle:]))
    return tree(sorted(chord_table().items()))
