"""One list of every id that can sit in an inventory slot (Phase 176).

A stack a player can hold is one of: an item (``GameData.ITEMS``), a material mined or felled into the
pack (``GameData.MATERIALS``), or a harvest/loot output named by a creature's ``drops`` table. The
generator (``gen_holdable_icons.py``), the item generator's orphan check and the suite all read this
list; the suite's twin is ``src/inventory/holdables.gd``, which reads ``GameData`` for the same three
sets. Both are derived from the generated ``godot/`` data, so a new fabric entry shows up in both.
"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GODOT = ROOT / "godot"


def _class_ids(sub: str) -> list:
    """Entity ids of ``godot/<sub>/*.gd`` (the generated ``class_name <Id>Data``)."""
    ids = []
    for gd in sorted((GODOT / sub).glob("*.gd")):
        m = re.search(r"^class_name (\w+)Data$", gd.read_text(), re.M)
        if m and gd.with_suffix(".tres").exists():
            ids.append(m.group(1))
    return ids


def items() -> list:
    return _class_ids("items")


def materials() -> list:
    return _class_ids("materials")


def drops() -> list:
    """Item ids named by any creature's harvest table or taming yield, in first-seen order, duplicates removed."""
    seen = []
    for tres in sorted((GODOT / "creatures").glob("*.tres")):
        text = tres.read_text()
        entries = []
        m = re.search(r"^drops = (\[.*\])$", text, re.M)
        if m:
            entries += json.loads(m.group(1))
        t = re.search(r"^tame = (\{.*\})$", text, re.M)
        if t:
            entries += json.loads(t.group(1)).get("yields", [])
        for entry in entries:
            if entry["item"] not in seen:
                seen.append(entry["item"])
    return seen


def holdable_kinds() -> dict:
    """id -> "item" | "material" | "drop", sorted by id. An id that is also an item stays an item."""
    kinds = {}
    for i in items():
        kinds[i] = "item"
    for m in materials():
        kinds.setdefault(m, "material")
    for d in drops():
        kinds.setdefault(d, "drop")
    return dict(sorted(kinds.items()))
