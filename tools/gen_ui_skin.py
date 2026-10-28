#!/usr/bin/env python3
"""Public placeholders for UI skins: flat colour at each key's final size (Phase 181).

The character creation screen (``src/ui/creation_screen.gd``) reads its skin as PNGs at overlay keys and builds
its 9-slice ``StyleBoxTexture``s in code, so the private repo can replace the pixels without a code change.
This writes every key of the screen's ``SKIN`` table under ``assets/textures/ui/creation/``, at the size the
table names, as a flat fill with a 2 px lighter border (so a 9-slice frame reads as one), and lists each key in
``assets/manifest.json``. The table is read from the GDScript, so the sizes live in one place.

    python3 tools/gen_ui_skin.py              # write everything
    python3 tools/gen_ui_skin.py --out DIR    # write the same tree under DIR (CI diffs two runs)
    python3 tools/gen_ui_skin.py --check      # fail if a file is stale, missing or orphaned

Pure Python, deterministic.
"""
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_placeholder import _png  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = Path("assets/manifest.json")
SKIN_DIR = Path("assets/textures/ui/creation")
SCREEN_GD = ROOT / "src/ui/creation_screen.gd"
KEY_PREFIX = "textures/ui/creation/"
BORDER = 2

# Skin id -> (fill, border). Every id of the screen's SKIN table must be here.
COLOURS = {
    "backdrop": ((16, 14, 24), (16, 14, 24)),
    "panel": ((34, 30, 46), (92, 84, 120)),
    "rig_frame": ((22, 20, 32), (150, 132, 96)),
    "button": ((58, 52, 78), (120, 110, 150)),
    "button_hover": ((78, 70, 104), (170, 156, 204)),
    "button_pressed": ((104, 84, 52), (220, 188, 120)),
}


def read_skin():
    """skin id -> (key, width, height), from creation_screen.gd's SKIN table."""
    rows = re.findall(r'"(\w+)":\s*\{\s*"key":\s*"([^"]+)",\s*"size":\s*Vector2i\((\d+),\s*(\d+)\)\s*\}',
                      SCREEN_GD.read_text())
    if not rows:
        sys.exit(f"{SCREEN_GD}: no SKIN table found")
    out = {}
    for sid, key, w, h in rows:
        if not key.startswith(KEY_PREFIX) or not key.endswith(".png.raw"):
            sys.exit(f"FAIL skin {sid}: key {key} is not under {KEY_PREFIX}")
        if sid not in COLOURS:
            sys.exit(f"FAIL skin {sid} has no colour in gen_ui_skin.py")
        out[sid] = (key, int(w), int(h))
    return out


def draw(sid, w, h):
    fill, border = COLOURS[sid]

    def at(x, y):
        edge = x < BORDER or y < BORDER or x >= w - BORDER or y >= h - BORDER
        return border if edge else fill

    return _png(w, h, at)


def outputs():
    files = {}
    for sid, (key, w, h) in sorted(read_skin().items()):
        files[Path("assets") / key] = draw(sid, w, h)
    return files


# gen_ui_icons.py re-appends its own keys at the end of the textures table; the skin keys go just before the
# first of them, so each generator leaves the other's order as it found it.
ICON_PREFIXES = ("icons/ui/", "icons/skills/", "icons/attributes/", "icons/hair/")


def manifest_text(files, root):
    manifest = json.loads((root / MANIFEST).read_text())
    others = [(k, v) for k, v in manifest["textures"].items() if not k.startswith(KEY_PREFIX)]
    cut = next((i for i, (k, _) in enumerate(others) if k.startswith(ICON_PREFIXES)), len(others))
    skin = [(str(rel)[len("assets/"):],) * 2 for rel in sorted(files)]
    manifest["textures"] = dict(others[:cut] + skin + others[cut:])
    return json.dumps(manifest, indent=2) + "\n"


def write(files, root):
    for rel, data in files.items():
        path = root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    for stale in (root / SKIN_DIR).glob("*.png.raw"):
        if SKIN_DIR / stale.name not in files:
            stale.unlink()
    if (root / MANIFEST).exists():
        (root / MANIFEST).write_text(manifest_text(files, root))
    print(f"wrote {len(files)} UI skin placeholders under {root}")


def check(files):
    problems = []
    for rel, data in files.items():
        if not (ROOT / rel).exists():
            problems.append(f"missing {rel}")
        elif (ROOT / rel).read_bytes() != data:
            problems.append(f"{rel} differs from the generator output")
    for f in sorted((ROOT / SKIN_DIR).glob("*")):
        if SKIN_DIR / f.name not in files:
            problems.append(f"orphan {SKIN_DIR / f.name}")
    if (ROOT / MANIFEST).read_text() != manifest_text(files, ROOT):
        problems.append(f"{MANIFEST} does not list exactly the UI skin keys")
    for p in problems:
        print("FAIL", p)
    if problems:
        print("UI skin placeholders are stale: run `python3 tools/gen_ui_skin.py` and commit the result")
        return 1
    print(f"ok: {len(files)} UI skin placeholders current")
    return 0


def main():
    args = sys.argv[1:]
    files = outputs()
    if args == ["--check"]:
        sys.exit(check(files))
    if args == []:
        write(files, ROOT)
    elif len(args) == 2 and args[0] == "--out":
        out = Path(args[1])
        (out / MANIFEST.parent).mkdir(parents=True, exist_ok=True)
        (out / MANIFEST).write_text((ROOT / MANIFEST).read_text())
        write(files, out)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
