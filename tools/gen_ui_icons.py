#!/usr/bin/env python3
"""UI icons from one generator: window dock, skills, HP and status effects (Phase 175).

Writes 32x32 RGBA icons, one per key:

* ``assets/icons/ui/window/<key>.png.raw`` - every ``WindowDock`` entry (``src/ui/window_dock.gd``);
* ``assets/icons/skills/<Skill>.png.raw`` - every skill under ``fabric/gameplay/skills/``: a frame
  coloured by the skill's category (the file it lives in) around a symbol for the skill;
* ``assets/icons/attributes/<attribute>.png.raw`` - every attribute of ``fabric/gameplay/attributes.js``;
* ``assets/icons/ui/hud/hp.png.raw`` and ``assets/icons/ui/hud/<effect>.png.raw`` - HP and every
  status effect of ``fabric/gameplay/combat.js``.

A small vector DSL (polygons, circles, ellipses, strokes, arcs) is rasterized at 128x128 on a fixed
palette and downsampled to 32x32 by block mode (so only palette colours appear), then a 1 px
outline is added. A category without a frame, a window or effect without a drawing, or a skill
without a symbol fails the run. Pure Python, no Blender, no GPU; output is deterministic.

    python3 tools/gen_ui_icons.py              # write everything
    python3 tools/gen_ui_icons.py --out DIR    # write the same tree under DIR (CI diffs two runs)
    python3 tools/gen_ui_icons.py --check      # fail if a file is stale, missing or orphaned

The private repo hand-polishes over the same keys (``project-nihon-assets``).
"""
import json
import math
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_placeholder import _png  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = Path("assets/manifest.json")
WINDOW_DIR = Path("assets/icons/ui/window")
HUD_DIR = Path("assets/icons/ui/hud")
SKILL_DIR = Path("assets/icons/skills")
ATTRIBUTE_DIR = Path("assets/icons/attributes")
DOCK_GD = ROOT / "src/ui/window_dock.gd"
SKILLS_DIR = ROOT / "fabric/gameplay/skills"
COMBAT_JS = ROOT / "fabric/gameplay/combat.js"
ATTRIBUTES_JS = ROOT / "fabric/gameplay/attributes.js"
KEY_PREFIXES = ("icons/ui/", "icons/skills/", "icons/attributes/")

RENDER = 128
ICON = 32
STEP = RENDER // ICON
K = RENDER / 100.0  # design space is 0..100

PALETTE = {
    "ink": (30, 24, 36),
    "cream": (238, 226, 190), "cream_d": (196, 180, 140),
    "steel": (176, 184, 196), "steel_d": (104, 112, 128), "steel_l": (226, 232, 240),
    "wood": (150, 104, 56), "wood_d": (98, 64, 34), "wood_l": (190, 144, 88),
    "gold": (240, 200, 64), "gold_d": (176, 128, 32),
    "red": (214, 64, 56), "red_d": (140, 36, 40),
    "orange": (240, 140, 40), "yellow": (252, 232, 96),
    "green": (84, 168, 80), "green_d": (44, 104, 56),
    "blue": (64, 128, 216), "blue_d": (36, 76, 140), "sky": (136, 196, 240),
    "purple": (140, 80, 200), "purple_d": (80, 40, 124),
    "teal": (56, 200, 192), "skin": (232, 180, 140), "white": (250, 250, 252),
    "black": (50, 46, 58),
}

# Skill category -> (frame, fill). Every entry of SKILL_CATEGORIES must be here.
FRAMES = {
    "combat": ("red", "red_d"),
    "crafting": ("orange", "wood_d"),
    "magic": ("purple", "purple_d"),
    "exploration": ("teal", "blue_d"),
    "social": ("gold", "gold_d"),
    "survival": ("green", "green_d"),
}


# ---------------------------------------------------------------------------
# Canvas: shapes in design space (0..100, y down), painted in order at 128x128.
# ---------------------------------------------------------------------------
class Canvas:
    def __init__(self):
        self.px = [[None] * RENDER for _ in range(RENDER)]
        self.k = K
        self.ox = 0.0
        self.oy = 0.0

    def place(self, scale, dx, dy):
        """Draw the next shapes scaled and shifted (design units); returns self for chaining."""
        self.k, self.ox, self.oy = K * scale, dx * K, dy * K
        return self

    def reset(self):
        return self.place(1.0, 0.0, 0.0)

    def _p(self, p):
        return (self.ox + p[0] * self.k, self.oy + p[1] * self.k)

    def _fill(self, x0, y0, x1, y1, inside, color):
        c = PALETTE[color]
        for y in range(max(0, int(math.floor(y0))), min(RENDER, int(math.ceil(y1)) + 1)):
            row = self.px[y]
            for x in range(max(0, int(math.floor(x0))), min(RENDER, int(math.ceil(x1)) + 1)):
                if inside(x + 0.5, y + 0.5):
                    row[x] = c

    def poly(self, pts, color):
        q = [self._p(p) for p in pts]
        n = len(q)

        def inside(px, py):
            hit = False
            j = n - 1
            for i in range(n):
                xi, yi = q[i]
                xj, yj = q[j]
                if (yi > py) != (yj > py) and px < (xj - xi) * (py - yi) / (yj - yi) + xi:
                    hit = not hit
                j = i
            return hit

        self._fill(min(p[0] for p in q), min(p[1] for p in q), max(p[0] for p in q), max(p[1] for p in q), inside, color)

    def ellipse(self, cx, cy, rx, ry, color):
        c = self._p((cx, cy))
        a, b = rx * self.k, ry * self.k
        self._fill(c[0] - a, c[1] - b, c[0] + a, c[1] + b,
                   lambda px, py: ((px - c[0]) / a) ** 2 + ((py - c[1]) / b) ** 2 <= 1.0, color)

    def circle(self, cx, cy, r, color):
        self.ellipse(cx, cy, r, r, color)

    def rect(self, x0, y0, x1, y1, color):
        a, b = self._p((x0, y0)), self._p((x1, y1))
        self._fill(a[0], a[1], b[0], b[1], lambda px, py: a[0] <= px <= b[0] and a[1] <= py <= b[1], color)

    def rrect(self, x0, y0, x1, y1, r, color):
        a, b = self._p((x0, y0)), self._p((x1, y1))
        rr = r * self.k

        def inside(px, py):
            if not (a[0] <= px <= b[0] and a[1] <= py <= b[1]):
                return False
            cx = min(max(px, a[0] + rr), b[0] - rr)
            cy = min(max(py, a[1] + rr), b[1] - rr)
            return (px - cx) ** 2 + (py - cy) ** 2 <= rr * rr

        self._fill(a[0], a[1], b[0], b[1], inside, color)

    def line(self, p0, p1, w, color):
        a, b = self._p(p0), self._p(p1)
        h = w * self.k / 2
        dx, dy = b[0] - a[0], b[1] - a[1]
        ll = dx * dx + dy * dy or 1.0

        def inside(px, py):
            t = max(0.0, min(1.0, ((px - a[0]) * dx + (py - a[1]) * dy) / ll))
            return (px - a[0] - t * dx) ** 2 + (py - a[1] - t * dy) ** 2 <= h * h

        self._fill(min(a[0], b[0]) - h, min(a[1], b[1]) - h, max(a[0], b[0]) + h, max(a[1], b[1]) + h, inside, color)

    def arc(self, cx, cy, r, w, a0, a1, color):
        """Stroke along a circle from angle a0 to a1 (degrees, y down, 0 = right)."""
        c = self._p((cx, cy))
        ro, ri = (r + w / 2) * self.k, (r - w / 2) * self.k

        def inside(px, py):
            d2 = (px - c[0]) ** 2 + (py - c[1]) ** 2
            if d2 > ro * ro or d2 < ri * ri:
                return False
            ang = math.degrees(math.atan2(py - c[1], px - c[0])) % 360
            return (ang - a0) % 360 <= (a1 - a0) % 360

        self._fill(c[0] - ro, c[1] - ro, c[0] + ro, c[1] + ro, inside, color)

    def ring(self, cx, cy, r, w, color):
        self.arc(cx, cy, r, w, 0, 359.999, color)

    def to_png(self) -> bytes:
        img = [[None] * ICON for _ in range(ICON)]
        for y in range(ICON):
            for x in range(ICON):
                block = [self.px[y * STEP + j][x * STEP + i] for j in range(STEP) for i in range(STEP)]
                hits = [b for b in block if b is not None]
                if len(hits) * 2 < len(block):
                    continue
                counts = {}
                for b in hits:
                    counts[b] = counts.get(b, 0) + 1
                img[y][x] = max(counts.items(), key=lambda kv: (kv[1], kv[0]))[0]
        out = [row[:] for row in img]
        edge = PALETTE["ink"]
        for y in range(ICON):
            for x in range(ICON):
                if img[y][x] is None and any(
                        0 <= y + dy < ICON and 0 <= x + dx < ICON and img[y + dy][x + dx] is not None
                        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    out[y][x] = edge
        return _png(ICON, ICON, lambda x, y: (*out[y][x], 255) if out[y][x] is not None else (0, 0, 0, 0))


def _star(cx, cy, r_out, r_in, points=4, rot=-90):
    pts = []
    for i in range(points * 2):
        r = r_out if i % 2 == 0 else r_in
        a = math.radians(rot + i * 180.0 / points)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


# ---------------------------------------------------------------------------
# Symbols (design space 0..100). Shared by window, HUD and skill icons.
# ---------------------------------------------------------------------------
def s_sword(c):
    c.poly([(70, 12), (82, 14), (80, 26), (34, 72), (28, 66)], "steel")
    c.poly([(70, 12), (82, 14), (80, 26), (74, 22)], "steel_l")
    c.line((24, 60), (42, 78), 7, "gold_d")
    c.line((30, 70), (16, 84), 7, "wood_d")
    c.circle(14, 86, 5, "gold")


def s_bow(c):
    c.arc(40, 50, 38, 7, 300, 60, "wood")
    c.line((57, 14), (57, 86), 2.5, "cream")
    c.line((22, 50), (84, 50), 3, "wood_l")
    c.poly([(90, 50), (78, 43), (78, 57)], "steel")
    c.poly([(26, 50), (18, 43), (22, 50), (18, 57)], "cream")


def s_shield(c):
    c.poly([(18, 14), (82, 14), (82, 50), (50, 90), (18, 50)], "steel_d")
    c.poly([(26, 20), (74, 20), (74, 48), (50, 80), (26, 48)], "steel")
    c.rect(46, 20, 54, 80, "gold")
    c.rect(26, 38, 74, 46, "gold")


def s_fist(c):
    c.rrect(22, 36, 78, 84, 8, "skin")
    for i in range(4):
        c.circle(30 + i * 13, 36, 7, "skin")
    c.rect(22, 84, 78, 92, "steel_d")
    c.line((26, 56), (74, 56), 2.5, "wood_d")


def s_anvil(c):
    c.poly([(10, 30), (90, 30), (78, 48), (62, 48), (66, 64), (78, 74), (78, 84), (22, 84), (22, 74), (34, 64), (38, 48), (24, 48)], "steel")
    c.poly([(10, 30), (90, 30), (86, 36), (14, 36)], "steel_l")
    c.rect(22, 76, 78, 84, "steel_d")


def s_hammer(c):
    c.line((28, 80), (66, 30), 8, "wood")
    c.rrect(46, 12, 86, 36, 4, "steel")
    c.rect(46, 12, 56, 36, "steel_d")


def s_saw(c):
    c.poly([(10, 36), (84, 36), (84, 56), (10, 56)], "steel")
    for i in range(8):
        x = 12 + i * 9
        c.poly([(x, 56), (x + 9, 56), (x + 4, 68)], "steel_d")
    c.rrect(76, 28, 94, 64, 4, "wood")
    c.rect(10, 36, 84, 40, "steel_l")


def s_flask(c):
    c.poly([(42, 14), (58, 14), (58, 38), (84, 80), (78, 90), (22, 90), (16, 80), (42, 38)], "sky")
    c.poly([(28, 64), (72, 64), (84, 80), (78, 90), (22, 90), (16, 80)], "green")
    c.rect(40, 8, 60, 16, "wood")
    c.circle(46, 74, 4, "green_d")
    c.circle(60, 80, 3, "white")


def s_forge(c):
    c.rect(14, 56, 86, 88, "steel_d")
    c.poly([(30, 56), (70, 56), (60, 30), (40, 30)], "steel")
    c.poly([(50, 18), (60, 38), (50, 50), (40, 38)], "orange")
    c.poly([(50, 28), (56, 40), (50, 48), (44, 40)], "yellow")
    c.rect(22, 70, 78, 76, "black")


def s_voidanvil(c):
    c.poly([(14, 48), (86, 48), (76, 62), (62, 62), (66, 74), (76, 82), (76, 90), (24, 90), (24, 82), (34, 74), (38, 62), (24, 62)], "purple_d")
    c.poly([(14, 48), (86, 48), (82, 54), (18, 54)], "purple")
    c.circle(50, 26, 15, "purple")
    c.circle(50, 26, 8, "black")
    c.circle(46, 22, 3, "sky")


def s_map(c):
    c.poly([(10, 20), (36, 12), (64, 22), (90, 14), (90, 80), (64, 88), (36, 78), (10, 86)], "cream")
    c.line((36, 12), (36, 78), 2.5, "cream_d")
    c.line((64, 22), (64, 88), 2.5, "cream_d")
    c.line((46, 40), (78, 66), 6, "red")
    c.line((78, 40), (46, 66), 6, "red")


def s_feet(c):
    c.ellipse(34, 62, 11, 16, "wood_l")
    c.ellipse(66, 38, 11, 16, "wood_l")
    for cx, cy in ((24, 40), (34, 36), (44, 40)):
        c.circle(cx, cy, 4, "wood_l")
    for cx, cy in ((56, 16), (66, 12), (76, 16)):
        c.circle(cx, cy, 4, "wood_l")


def s_eye(c):
    c.ellipse(50, 50, 40, 24, "white")
    c.circle(50, 50, 16, "teal")
    c.circle(50, 50, 8, "black")
    c.circle(45, 45, 3, "white")
    c.line((14, 86), (86, 14), 6, "red")


def s_compass(c):
    c.circle(50, 50, 40, "gold_d")
    c.circle(50, 50, 33, "cream")
    c.poly([(50, 16), (60, 50), (50, 56), (40, 50)], "red")
    c.poly([(50, 84), (60, 50), (50, 44), (40, 50)], "steel_d")
    c.circle(50, 50, 5, "ink")


def s_flame(c):
    c.poly([(50, 6), (74, 36), (84, 60), (74, 84), (50, 94), (26, 84), (16, 60), (28, 36), (38, 44)], "orange")
    c.poly([(50, 36), (66, 60), (62, 82), (50, 90), (38, 82), (34, 60)], "yellow")
    c.poly([(50, 62), (58, 76), (50, 86), (42, 76)], "white")


def s_voidorb(c):
    c.circle(50, 50, 38, "purple_d")
    c.circle(50, 50, 24, "black")
    c.ring(50, 50, 44, 5, "purple")
    c.circle(40, 40, 5, "purple")


def s_plus(c):
    c.rrect(36, 12, 64, 88, 6, "green")
    c.rrect(12, 36, 88, 64, 6, "green")
    c.rrect(42, 20, 58, 80, 3, "white")
    c.rrect(20, 42, 80, 58, 3, "white")


def s_sparkle(c):
    c.poly(_star(46, 54, 40, 8), "yellow")
    c.poly(_star(78, 24, 16, 4), "white")
    c.poly(_star(24, 20, 10, 3), "sky")


def s_flag(c):
    c.line((24, 10), (24, 92), 6, "wood_d")
    c.poly([(28, 14), (84, 24), (28, 52)], "white")
    c.circle(24, 10, 5, "gold")


def s_scales(c):
    c.line((50, 14), (50, 84), 6, "gold_d")
    c.rect(28, 84, 72, 92, "gold_d")
    c.line((16, 28), (84, 28), 5, "gold")
    for x in (16, 84):
        c.line((x, 28), (x - 10, 58), 2.5, "steel_d")
        c.line((x, 28), (x + 10, 58), 2.5, "steel_d")
        c.ellipse(x, 62, 14, 6, "gold")


def s_speech(c):
    c.poly([(8, 22), (92, 22), (92, 66), (60, 66), (30, 88), (36, 66), (8, 66)], "white")
    for x in (28, 50, 72):
        c.circle(x, 44, 5, "blue_d")


def s_crown(c):
    c.poly([(12, 74), (12, 30), (32, 52), (50, 20), (68, 52), (88, 30), (88, 74)], "gold")
    c.rect(12, 74, 88, 88, "gold_d")
    for x, col in ((12, "red"), (50, "sky"), (88, "red")):
        c.circle(x, 28 if x != 50 else 18, 6, col)


def s_knife(c):
    c.poly([(84, 12), (40, 40), (30, 62), (50, 58), (62, 40)], "steel")
    c.poly([(84, 12), (40, 40), (50, 40)], "steel_l")
    c.line((30, 62), (14, 86), 9, "wood_d")
    c.line((34, 56), (46, 66), 5, "gold_d")


def s_bag(c):
    c.ellipse(50, 64, 34, 28, "wood")
    c.poly([(36, 20), (64, 20), (68, 42), (32, 42)], "wood")
    c.rect(34, 40, 66, 48, "red")
    c.ellipse(50, 66, 18, 14, "wood_l")
    c.rrect(40, 8, 60, 22, 4, "wood_d")


def s_bust(c):
    c.ellipse(50, 94, 38, 24, "steel_d")
    c.circle(50, 48, 22, "skin")
    c.poly([(26, 52), (26, 40), (36, 22), (50, 16), (64, 22), (74, 40), (74, 52), (64, 46), (36, 46)], "steel")
    c.rect(46, 44, 54, 64, "steel_d")
    c.poly([(50, 16), (60, 6), (66, 24)], "red")


def s_book(c):
    c.poly([(8, 24), (48, 30), (48, 86), (8, 80)], "cream")
    c.poly([(92, 24), (52, 30), (52, 86), (92, 80)], "cream")
    c.rect(47, 28, 53, 88, "red_d")
    for y in (42, 54, 66):
        c.line((16, y), (40, y + 3), 2.5, "cream_d")
        c.line((84, y), (60, y + 3), 2.5, "cream_d")


def s_gear(c):
    for i in range(8):
        a = math.radians(i * 45)
        p0 = (30 + 29 * math.cos(a), 36 + 29 * math.sin(a))
        c.line((30, 36), p0, 11, "steel_d")
    c.circle(30, 36, 22, "steel")
    c.circle(30, 36, 9, "ink")


def s_flaskmini(c):
    c.poly([(70, 38), (82, 38), (82, 54), (98, 86), (54, 86), (70, 54)], "sky")
    c.poly([(62, 72), (90, 72), (98, 86), (54, 86)], "green")
    c.rect(68, 32, 84, 40, "wood")


def s_swap(c):
    c.poly([(10, 30), (62, 30), (62, 16), (90, 38), (62, 60), (62, 46), (10, 46)], "green")
    c.poly([(90, 54), (38, 54), (38, 40), (10, 62), (38, 84), (38, 70), (90, 70)], "blue")


def s_coins(c):
    for i, y in enumerate((74, 56, 38)):
        c.ellipse(50, y + 12, 32, 12, "gold_d")
        c.rect(18, y, 82, y + 12, "gold_d")
        c.ellipse(50, y, 32, 12, "gold")
        c.ellipse(50, y, 20, 6, "yellow")


def s_globe(c):
    c.circle(50, 50, 40, "blue")
    c.poly([(26, 28), (44, 20), (54, 32), (44, 48), (30, 52), (20, 40)], "green")
    c.poly([(58, 54), (76, 50), (80, 68), (66, 82), (56, 70)], "green")
    c.ring(50, 50, 40, 5, "blue_d")
    c.arc(50, 50, 40, 2.5, 270, 90, "sky")


def s_scroll(c):
    c.rect(20, 22, 70, 78, "cream")
    c.ellipse(20, 50, 8, 28, "cream_d")
    c.ellipse(70, 50, 8, 28, "cream_d")
    for y in (36, 48, 60):
        c.line((30, y), (60, y), 2.5, "cream_d")
    c.line((54, 80), (92, 10), 6, "white")
    c.poly([(92, 10), (80, 14), (96, 26)], "steel_l")
    c.poly([(54, 80), (50, 90), (58, 84)], "ink")


def s_house(c):
    c.rect(20, 46, 80, 90, "cream")
    c.poly([(8, 50), (50, 12), (92, 50)], "red")
    c.rect(40, 66, 60, 90, "wood_d")
    c.circle(50, 56, 6, "yellow")
    c.poly([(66, 76), (72, 66), (78, 76), (72, 86)], "orange")


def s_keyboard(c):
    c.rrect(6, 24, 94, 78, 6, "steel_d")
    for r in range(3):
        for i in range(6 if r < 2 else 0):
            c.rect(12 + i * 13, 31 + r * 14, 22 + i * 13, 41 + r * 14, "steel_l")
    c.rect(24, 63, 76, 72, "steel_l")


def s_heart(c):
    c.circle(33, 36, 22, "red")
    c.circle(67, 36, 22, "red")
    c.poly([(12, 46), (88, 46), (50, 90)], "red")
    c.circle(28, 30, 6, "white")


def s_bolt(c):
    c.poly([(58, 6), (24, 54), (46, 54), (36, 94), (76, 40), (54, 40)], "yellow")
    c.poly([(58, 6), (46, 24), (60, 24)], "white")


def s_knockback(c):
    c.poly([(14, 38), (52, 38), (52, 20), (90, 50), (52, 80), (52, 62), (14, 62)], "steel")
    for y in (26, 50, 74):
        c.line((6, y), (22, y), 4, "cream_d")


def s_knockdown(c):
    c.circle(26, 62, 13, "skin")
    c.rrect(36, 54, 88, 70, 7, "blue")
    c.line((88, 62), (96, 76), 6, "blue_d")
    c.rect(8, 82, 92, 90, "wood_d")
    c.line((20, 30), (20, 46), 4, "cream_d")
    c.line((12, 38), (28, 38), 4, "cream_d")


def s_stagger(c):
    c.ring(50, 56, 30, 8, "yellow")
    c.poly(_star(50, 20, 12, 4), "gold")
    c.poly(_star(18, 40, 9, 3), "gold")
    c.poly(_star(82, 40, 9, 3), "gold")
    c.circle(50, 56, 10, "orange")


def s_crown_window(c):
    s_crown(c)


def _lay(c, scale, dx, dy, *fns):
    c.place(scale, dx, dy)
    for f in fns:
        f(c)
    c.reset()


def d_craft(c):
    _lay(c, 0.8, 4, 18, s_anvil)
    _lay(c, 0.6, 38, 0, s_hammer)


def d_tech(c):
    s_gear(c)
    s_flaskmini(c)


# Window key -> drawing; every WindowDock entry needs one.
WINDOWS = {
    "inventory": s_bag, "character": s_bust, "skills": s_book, "crafting": d_craft,
    "technology": d_tech, "trade": s_swap, "market": s_coins, "map": s_globe,
    "proposals": s_scroll, "settlement": s_house, "controls": s_keyboard, "admin": s_crown_window,
}

# HUD key -> drawing; every status effect of combat.js needs one.
HUD = {
    "hp": s_heart, "heat_burn": s_flame, "paralysis": s_bolt, "knockback": s_knockback,
    "knockdown": s_knockdown, "stagger": s_stagger,
}

def s_vital(c):
    s_heart(c)
    c.rect(44, 28, 56, 70, "white")
    c.rect(29, 43, 71, 55, "white")


# Attribute id -> drawing; every attribute of attributes.js needs one (Phase 179).
ATTRIBUTES = {
    "strength": s_fist, "vitality": s_vital, "resistance": s_shield,
    "agility": s_feet, "intelligence": s_sparkle, "perception": s_eye,
}

# Skill -> symbol; every skill needs one, and no two may look the same.
SYMBOLS = {
    "Swordsmanship": s_sword, "Archery": s_bow, "Shieldcraft": s_shield, "Unarmed": s_fist,
    "Smithing": s_anvil, "Carpentry": s_saw, "Alchemy": s_flask, "ArcaneForging": s_hammer,
    "VoidSmithing": s_voidanvil, "Cartography": s_map, "Tracking": s_feet, "Stealth": s_eye,
    "Navigation": s_compass, "ElementalMagic": s_flame, "VoidMagic": s_voidorb,
    "RestorationMagic": s_plus, "Enchanting": s_sparkle, "Diplomacy": s_flag, "Trade": s_scales,
    "Speechcraft": s_speech, "Leadership": s_crown, "Skinning": s_knife,
}


def draw_window(key):
    c = Canvas()
    c.place(0.92, 4, 4)
    WINDOWS[key](c)
    return c.to_png()


def draw_hud(key):
    c = Canvas()
    c.place(0.92, 4, 4)
    HUD[key](c)
    return c.to_png()


def draw_attribute(key):
    c = Canvas()
    c.place(0.92, 4, 4)
    ATTRIBUTES[key](c)
    return c.to_png()


def draw_skill(category, skill):
    frame, fill = FRAMES[category]
    c = Canvas()
    c.rrect(5, 5, 95, 95, 14, frame)
    c.rrect(11, 11, 89, 89, 9, fill)
    c.place(0.72, 14, 14)
    SYMBOLS[skill](c)
    return c.to_png()


# ---------------------------------------------------------------------------
# Inputs read from the repo: dock entries, skill categories and skills, status effects.
# ---------------------------------------------------------------------------
def read_windows():
    keys = re.findall(r'\{"key": "(\w+)",\s+"letter"', DOCK_GD.read_text())
    if not keys:
        sys.exit(f"{DOCK_GD}: no dock entries found")
    return keys


def read_categories():
    m = re.search(r"SKILL_CATEGORIES\s*=\s*\[([^\]]*)\]", (SKILLS_DIR / "shared.js").read_text())
    if not m:
        sys.exit("fabric/gameplay/skills/shared.js: SKILL_CATEGORIES not found")
    return re.findall(r"'(\w+)'", m.group(1))


def read_skills(categories):
    """skill -> category (the skill file it is defined in)."""
    skills = {}
    for cat in categories:
        f = SKILLS_DIR / f"{cat}.js"
        if f.exists():
            for name in re.findall(r"^  (\w+): defineEntity\(", f.read_text(), re.M):
                skills[name] = cat
    return skills


def read_effects():
    m = re.search(r"const STATUS_EFFECTS = \{(.*?)^\}", COMBAT_JS.read_text(), re.M | re.S)
    if not m:
        sys.exit("fabric/gameplay/combat.js: STATUS_EFFECTS not found")
    return re.findall(r"^  (\w+):\s*\{", m.group(1), re.M)


def read_attributes():
    m = re.search(r"const ATTRIBUTES\s*=\s*\[([^\]]*)\]", ATTRIBUTES_JS.read_text())
    if not m:
        sys.exit("fabric/gameplay/attributes.js: ATTRIBUTES not found")
    return re.findall(r"'(\w+)'", m.group(1))


def validate():
    problems = []
    for a in read_attributes():
        if a not in ATTRIBUTES:
            problems.append(f"attribute {a} has no drawing in gen_ui_icons.py")
    cats = read_categories()
    for cat in cats:
        if cat not in FRAMES:
            problems.append(f"skill category {cat} has no frame in gen_ui_icons.py")
    skills = read_skills(cats)
    for f in SKILLS_DIR.glob("*.js"):
        if f.stem not in cats and f.stem not in ("shared", "index"):
            problems.append(f"{f.name}: not a skill category in SKILL_CATEGORIES")
    for s in skills:
        if s not in SYMBOLS:
            problems.append(f"skill {s} has no symbol in gen_ui_icons.py")
    for w in read_windows():
        if w not in WINDOWS:
            problems.append(f"window {w} has no drawing in gen_ui_icons.py")
    for e in read_effects():
        if e not in HUD:
            problems.append(f"status effect {e} has no drawing in gen_ui_icons.py")
    if problems:
        sys.exit("\n".join("FAIL " + p for p in problems))
    return read_windows(), skills, read_effects()


def outputs():
    windows, skills, effects = validate()
    files = {}
    for w in windows:
        files[WINDOW_DIR / f"{w}.png.raw"] = draw_window(w)
    for s, cat in sorted(skills.items()):
        files[SKILL_DIR / f"{s}.png.raw"] = draw_skill(cat, s)
    for a in read_attributes():
        files[ATTRIBUTE_DIR / f"{a}.png.raw"] = draw_attribute(a)
    for h in ["hp"] + effects:
        files[HUD_DIR / f"{h}.png.raw"] = draw_hud(h)
    seen = {}
    for rel, data in files.items():
        if data in seen:
            sys.exit(f"FAIL {rel} is byte-identical to {seen[data]}")
        seen[data] = rel
    return files


def manifest_text(files, root):
    manifest = json.loads((root / MANIFEST).read_text())
    textures = {k: v for k, v in manifest["textures"].items() if not k.startswith(KEY_PREFIXES)}
    for rel in sorted(files):
        key = str(rel)[len("assets/"):]
        textures[key] = key
    manifest["textures"] = textures
    return json.dumps(manifest, indent=2) + "\n"


def write(files, root):
    for rel, data in files.items():
        path = root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    for d in (WINDOW_DIR, HUD_DIR, SKILL_DIR, ATTRIBUTE_DIR):
        keep = {r.name for r in files if r.parent == d}
        for stale in (root / d).glob("*.png.raw"):
            if stale.name not in keep:
                stale.unlink()
    if (root / MANIFEST).exists():
        (root / MANIFEST).write_text(manifest_text(files, root))
    print(f"wrote {len(files)} UI icons under {root}")


def check(files):
    problems = []
    for rel, data in files.items():
        if not (ROOT / rel).exists():
            problems.append(f"missing {rel}")
        elif (ROOT / rel).read_bytes() != data:
            problems.append(f"{rel} differs from the generator output")
    for d in (WINDOW_DIR, HUD_DIR, SKILL_DIR, ATTRIBUTE_DIR):
        for f in sorted((ROOT / d).glob("*.png.raw")):
            if d / f.name not in files:
                problems.append(f"orphan {d / f.name}")
    if (ROOT / MANIFEST).read_text() != manifest_text(files, ROOT):
        problems.append(f"{MANIFEST} does not list exactly the UI icon keys")
    for p in problems:
        print("FAIL", p)
    if problems:
        print("UI icons are stale: run `python3 tools/gen_ui_icons.py` and commit the result")
        return 1
    print(f"ok: {len(files)} UI icons current")
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
