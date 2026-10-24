#!/usr/bin/env python3
"""Icons for every held stack that is not an item: materials and harvest/loot outputs (Phase 176).

Items already get a rendered icon from ``gen_item_assets.py``. Everything else a player can hold -
the 12 materials mined or felled into the pack and the outputs of the creature harvest tables (hides,
meat, bones, trophies) - is drawn here with the same vector canvas as ``gen_ui_icons.py`` and written
beside the item icons, at the same key ``icons/items/<id>.png.raw`` (32x32 RGBA):

* a material is drawn from its palette colour and a form: ore chunk, block, log, sheaf or pile;
* a harvest output is drawn from its kind: hide, meat, bone, fang, horn, feather, scale, trophy,
  organ, vial, sac, crystal, core, stone or shard.

``holdables.py`` is the one list of ids; a material or drop without a row below fails the run, so a
new fabric entry cannot ship with the glyph fallback. Pure Python, deterministic.

    python3 tools/gen_holdable_icons.py              # write everything
    python3 tools/gen_holdable_icons.py --out DIR    # write the same tree under DIR (CI diffs two runs)
    python3 tools/gen_holdable_icons.py --check      # fail if a file is stale, missing or orphaned
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gen_ui_icons as ui  # noqa: E402
import holdables  # noqa: E402
from gen_item_assets import MATERIAL_COLORS  # noqa: E402

ROOT = ui.ROOT
ICON_DIR = Path("assets/icons/items")

# Materials the item generator has no colour for (it only paints what an item is made of).
MATERIAL_COLORS = dict(MATERIAL_COLORS, Soil=(112, 78, 52), Snow=(226, 236, 246))

# material -> form
MATERIAL_FORMS = {
    "Aethermite": "ore", "Ferrite": "ore", "Lumenfite": "ore", "Veilsteel": "ore", "Voidite": "ore",
    "Grass": "block", "Thornwood": "log", "Duskfiber": "sheaf",
    "Ashite": "pile", "Sand": "pile", "Snow": "pile", "Soil": "pile",
}

# harvest/loot output -> (kind, colour)
DROPS = {
    "alpha_wolf_fang": ("fang", (232, 226, 206)),
    "bison_bone": ("bone", (226, 214, 188)),
    "bison_hide": ("hide", (120, 78, 48)),
    "bison_horn": ("horn", (84, 70, 60)),
    "bison_meat": ("meat", (176, 56, 60)),
    "boar_hide": ("hide", (92, 72, 58)),
    "boar_tusk": ("fang", (244, 236, 214)),
    "crystallised_phase_shard": ("crystal", (150, 190, 240)),
    "gargoyle_crest": ("trophy", (150, 70, 52)),
    "gargoyle_wing_fragment": ("wing", (110, 100, 112)),
    "glimmer_fur_tuft": ("tuft", (236, 170, 96)),
    "glimmer_pelt": ("hide", (236, 150, 72)),
    "hawk_feather": ("feather", (176, 134, 88)),
    "hawk_talon": ("fang", (60, 54, 60)),
    "lava_core_organ": ("organ", (240, 108, 40)),
    "luminescent_reagent": ("vial", (112, 240, 176)),
    "petrified_binding_stone": ("stone", (140, 134, 128)),
    "phase_locked_core": ("core", (176, 110, 240)),
    "raw_boar_meat": ("meat", (214, 108, 112)),
    "rift_shard": ("crystal", (150, 70, 210)),
    "shadow_phase_membrane": ("membrane", (72, 60, 120)),
    "slug_shell_shard": ("shard", (232, 176, 120)),
    "superheated_slime_vial": ("vial", (255, 130, 60)),
    "veilstalker_venom_sac": ("sac", (96, 190, 90)),
    "void_core_crystal": ("core", (96, 52, 160)),
    "void_scale": ("scale", (70, 50, 130)),
    "void_serpent_fang": ("fang", (150, 120, 220)),
    "warden_sigil": ("trophy", (222, 190, 90)),
    "wolf_fang": ("fang", (214, 214, 206)),
    "wolf_pelt": ("hide", (122, 124, 130)),
}


def _tone(rgb, k):
    """rgb scaled by k towards black (k < 1) or white (k > 1)."""
    if k <= 1:
        return tuple(int(v * k) for v in rgb)
    return tuple(int(v + (255 - v) * (k - 1)) for v in rgb)


def _ramp(name, rgb):
    """Register a four-step ramp (base, dark, darker, light) in the shared palette."""
    for suffix, k in (("", 1.0), ("_d", 0.72), ("_dd", 0.5), ("_l", 1.4)):
        ui.PALETTE[name + suffix] = _tone(rgb, k)
    return name


# ---------------------------------------------------------------------------
# Forms: each takes the canvas and a ramp name; design space is 0..100, y down.
# ---------------------------------------------------------------------------
def f_ore(c, m):
    c.poly([(14, 70), (26, 40), (48, 22), (74, 30), (88, 56), (80, 80), (40, 84)], m + "_d")
    c.poly([(22, 66), (32, 44), (48, 30), (70, 36), (60, 54), (44, 74)], m)
    c.poly([(36, 46), (48, 30), (62, 36), (50, 46)], m + "_l")
    c.line((62, 60), (78, 76), 5, m + "_dd")


def f_block(c, m):
    c.poly([(50, 14), (88, 32), (50, 50), (12, 32)], m + "_l")
    c.poly([(12, 32), (50, 50), (50, 88), (12, 70)], m + "_d")
    c.poly([(50, 50), (88, 32), (88, 70), (50, 88)], m + "_dd")


def f_log(c, m):
    c.rect(12, 34, 76, 70, m + "_d")
    c.line((20, 44), (68, 44), 3, m)
    c.line((20, 58), (68, 58), 3, m)
    c.ellipse(76, 52, 12, 18, m + "_l")
    c.ellipse(76, 52, 7, 11, m)
    c.ellipse(76, 52, 2.5, 4, m + "_dd")


def f_sheaf(c, m):
    for x0, x1 in ((24, 14), (36, 30), (50, 50), (64, 70), (76, 86)):
        c.line((x0, 82), (x1, 14), 6, m if x0 % 2 == 0 else m + "_l")
    c.rect(24, 52, 78, 62, m + "_dd")
    c.line((28, 57), (74, 57), 2, m + "_d")


def f_pile(c, m):
    c.poly([(8, 82), (30, 46), (46, 30), (62, 46), (92, 82)], m + "_d")
    c.poly([(22, 82), (38, 54), (46, 38), (58, 54), (74, 82)], m)
    c.poly([(36, 56), (46, 38), (54, 52)], m + "_l")
    c.circle(78, 76, 4, m + "_l")
    c.circle(14, 78, 3, m + "_l")


def d_hide(c, m):
    c.poly([(26, 18), (50, 12), (74, 18), (92, 38), (80, 52), (84, 80), (70, 86), (64, 66),
            (36, 66), (30, 86), (16, 80), (20, 52), (8, 38)], m + "_d")
    c.poly([(30, 26), (50, 20), (70, 26), (82, 40), (72, 50), (60, 58), (40, 58), (28, 50), (18, 40)], m)
    c.line((36, 34), (64, 34), 4, m + "_l")
    c.line((50, 28), (50, 56), 3, m + "_dd")


def d_tuft(c, m):
    for x, tip in ((28, 20), (42, 10), (56, 8), (70, 18)):
        c.poly([(x - 8, 82), (x, tip), (x + 8, 82)], m if x % 2 == 0 else m + "_l")
    c.rect(20, 72, 78, 88, m + "_dd")


def d_meat(c, m):
    c.ellipse(46, 50, 34, 28, m + "_dd")
    c.ellipse(46, 48, 30, 24, m)
    c.ellipse(38, 42, 12, 8, m + "_l")
    c.circle(66, 60, 7, "cream")
    c.line((70, 64), (88, 82), 8, "cream")
    c.circle(90, 84, 6, "cream_d")


def d_bone(c, m):
    c.line((24, 76), (76, 24), 12, m + "_d")
    c.line((24, 76), (76, 24), 7, m)
    for p in ((20, 66), (34, 82), (66, 18), (80, 34)):
        c.circle(p[0], p[1], 9, m)
    c.line((38, 62), (58, 42), 3, m + "_l")


def d_fang(c, m):
    c.poly([(30, 14), (74, 14), (78, 26), (60, 60), (44, 90), (38, 56)], m + "_d")
    c.poly([(38, 20), (68, 20), (56, 52), (46, 78), (44, 50)], m)
    c.line((44, 24), (60, 24), 4, m + "_l")


def d_horn(c, m):
    c.poly([(14, 80), (10, 40), (28, 16), (60, 10), (88, 14), (60, 28), (44, 44), (40, 80)], m + "_d")
    c.poly([(22, 74), (20, 42), (34, 24), (58, 18), (46, 36), (32, 52), (30, 74)], m)
    c.line((24, 60), (32, 32), 3, m + "_l")
    c.rect(12, 78, 42, 90, "steel_d")


def d_feather(c, m):
    c.poly([(24, 84), (14, 50), (34, 18), (74, 8), (88, 12), (80, 44), (54, 74)], m + "_d")
    c.poly([(30, 76), (24, 52), (40, 26), (72, 16), (68, 44), (50, 64)], m)
    c.line((20, 90), (82, 14), 4, m + "_dd")
    c.line((38, 52), (62, 36), 3, m + "_l")


def d_wing(c, m):
    c.poly([(8, 50), (30, 14), (60, 22), (92, 12), (74, 40), (84, 64), (50, 58), (30, 86)], m + "_d")
    c.poly([(20, 48), (34, 26), (58, 32), (76, 24), (64, 42), (68, 54), (48, 48), (34, 68)], m)
    c.line((30, 30), (74, 24), 3, m + "_l")
    c.line((30, 80), (60, 50), 3, m + "_dd")


def d_scale(c, m):
    c.poly([(50, 8), (86, 30), (76, 74), (50, 92), (24, 74), (14, 30)], m + "_d")
    c.poly([(50, 18), (76, 34), (68, 68), (50, 80), (32, 68), (24, 34)], m)
    c.poly([(50, 24), (66, 36), (50, 50), (34, 36)], m + "_l")
    c.line((50, 50), (50, 76), 3, m + "_dd")


def d_trophy(c, m):
    c.poly([(50, 8), (88, 26), (82, 64), (50, 92), (18, 64), (12, 26)], m + "_d")
    c.poly([(50, 18), (78, 32), (74, 60), (50, 80), (26, 60), (22, 32)], m)
    c.poly([(50, 26), (66, 50), (50, 70), (34, 50)], m + "_dd")
    c.circle(50, 48, 7, m + "_l")


def d_organ(c, m):
    c.ellipse(50, 56, 34, 28, m + "_dd")
    c.ellipse(50, 54, 30, 24, m)
    c.ellipse(42, 46, 12, 8, m + "_l")
    c.line((50, 30), (50, 8), 6, m + "_d")
    c.line((50, 14), (70, 10), 5, m + "_d")
    c.line((48, 76), (48, 90), 4, m + "_dd")


def d_vial(c, m):
    c.rect(42, 8, 58, 24, "wood")
    c.poly([(42, 24), (58, 24), (60, 40), (80, 72), (74, 90), (26, 90), (20, 72), (40, 40)], "steel_l")
    c.poly([(30, 70), (44, 52), (56, 52), (70, 70), (68, 84), (32, 84)], m)
    c.line((36, 74), (62, 74), 3, m + "_l")
    c.circle(44, 62, 3, m + "_l")


def d_sac(c, m):
    c.poly([(40, 10), (60, 10), (56, 28), (82, 50), (78, 80), (50, 92), (22, 80), (18, 50), (44, 28)], m + "_d")
    c.poly([(42, 30), (58, 30), (72, 52), (68, 74), (50, 84), (32, 74), (28, 52)], m)
    c.circle(42, 52, 7, m + "_l")
    c.line((40, 10), (60, 10), 6, "wood_d")


def d_crystal(c, m):
    c.poly([(50, 6), (68, 40), (62, 90), (38, 90), (32, 40)], m + "_d")
    c.poly([(50, 14), (60, 40), (56, 82), (44, 82), (40, 40)], m)
    c.poly([(50, 14), (54, 40), (48, 78), (44, 40)], m + "_l")
    c.poly([(22, 90), (14, 60), (28, 50), (34, 90)], m + "_dd")
    c.poly([(66, 90), (72, 56), (86, 64), (80, 90)], m + "_dd")


def d_core(c, m):
    c.circle(50, 50, 38, m + "_dd")
    c.circle(50, 50, 32, m)
    c.ring(50, 50, 20, 4, m + "_l")
    c.circle(50, 50, 9, m + "_l")
    c.circle(40, 38, 4, "white")


def d_stone(c, m):
    c.poly([(12, 74), (20, 38), (46, 18), (78, 28), (90, 60), (72, 86), (30, 86)], m + "_d")
    c.poly([(24, 70), (30, 42), (48, 28), (70, 36), (62, 58), (44, 76)], m)
    c.line((54, 28), (50, 60), 3, m + "_dd")
    c.line((30, 56), (44, 62), 3, m + "_dd")
    c.line((68, 62), (84, 66), 3, "gold")


def d_shard(c, m):
    c.poly([(8, 80), (22, 30), (60, 10), (92, 36), (74, 84), (36, 92)], m + "_d")
    c.poly([(20, 74), (30, 38), (58, 22), (78, 40), (66, 72), (38, 80)], m)
    c.arc(52, 52, 18, 4, 200, 330, m + "_l")
    c.arc(52, 52, 8, 4, 200, 330, m + "_l")


def d_membrane(c, m):
    c.poly([(10, 36), (46, 14), (90, 30), (80, 64), (54, 90), (20, 72)], m + "_d")
    c.poly([(20, 40), (46, 24), (78, 36), (70, 60), (52, 78), (28, 66)], m)
    for a, b in (((46, 24), (40, 60)), ((60, 30), (56, 66)), ((30, 38), (30, 62))):
        c.line(a, b, 2.5, m + "_l")


FORMS = {"ore": f_ore, "block": f_block, "log": f_log, "sheaf": f_sheaf, "pile": f_pile}
KINDS = {
    "hide": d_hide, "tuft": d_tuft, "meat": d_meat, "bone": d_bone, "fang": d_fang, "horn": d_horn,
    "feather": d_feather, "wing": d_wing, "scale": d_scale, "trophy": d_trophy, "organ": d_organ,
    "vial": d_vial, "sac": d_sac, "crystal": d_crystal, "core": d_core, "stone": d_stone,
    "shard": d_shard, "membrane": d_membrane,
}


def draw(item_id, kind, rgb):
    """Icon bytes of one holdable of the given material form or drop kind."""
    m = _ramp("h_" + item_id, rgb)
    c = ui.Canvas()
    c.place(0.84, 8, 8)
    (FORMS.get(kind) or KINDS[kind])(c, m)
    return c.to_png()


# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------
def owned_ids() -> set:
    """Ids whose icon this generator writes: every holdable that is not an item."""
    return {i for i, k in holdables.holdable_kinds().items() if k != "item"}


def validate():
    problems = []
    for mat in holdables.materials():
        if mat not in MATERIAL_FORMS:
            problems.append(f"material {mat} has no form in gen_holdable_icons.py")
        if mat not in MATERIAL_COLORS:
            problems.append(f"material {mat} has no palette colour in gen_holdable_icons.py")
    for mat, form in MATERIAL_FORMS.items():
        if form not in FORMS:
            problems.append(f"material {mat}: no form {form}")
    for drop in holdables.drops():
        if drop in holdables.items():
            continue
        if drop not in DROPS:
            problems.append(f"harvest output {drop} has no kind in gen_holdable_icons.py")
        elif DROPS[drop][0] not in KINDS:
            problems.append(f"harvest output {drop}: no drawing for kind {DROPS[drop][0]}")
    if problems:
        sys.exit("\n".join("FAIL " + p for p in problems))


def outputs() -> dict:
    validate()
    kinds = holdables.holdable_kinds()
    files = {}
    for i, k in kinds.items():
        if k == "material":
            files[ICON_DIR / f"{i}.png.raw"] = draw(i, MATERIAL_FORMS[i], MATERIAL_COLORS[i])
        elif k == "drop":
            kind, rgb = DROPS[i]
            files[ICON_DIR / f"{i}.png.raw"] = draw(i, kind, rgb)
    seen = {}
    for rel, data in files.items():
        if data in seen:
            sys.exit(f"FAIL {rel} is byte-identical to {seen[data]}")
        seen[data] = rel
    return files


def write(files, root):
    for rel, data in files.items():
        path = root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    print(f"wrote {len(files)} holdable icons under {root}")


def check(files):
    problems = []
    for rel, data in files.items():
        if not (ROOT / rel).exists():
            problems.append(f"missing {rel}")
        elif (ROOT / rel).read_bytes() != data:
            problems.append(f"{rel} differs from the generator output")
    kinds = holdables.holdable_kinds()
    for f in sorted((ROOT / ICON_DIR).glob("*.png.raw")):
        name = f.name[: -len(".png.raw")]
        if name not in kinds:
            problems.append(f"orphan {ICON_DIR / f.name}: not a holdable id")
    for p in problems:
        print("FAIL", p)
    if problems:
        print("holdable icons are stale: run `python3 tools/gen_holdable_icons.py` and commit the result")
        return 1
    print(f"ok: {len(files)} holdable icons current")
    return 0


def main():
    args = sys.argv[1:]
    files = outputs()
    if args == ["--check"]:
        sys.exit(check(files))
    if args == []:
        write(files, ROOT)
    elif len(args) == 2 and args[0] == "--out":
        write(files, Path(args[1]))
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
