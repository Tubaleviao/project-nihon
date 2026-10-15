#!/usr/bin/env python3
"""Regenerate the committed placeholder textures.

Placeholders live at canonical ``res://`` paths under ``assets/`` so a public
clone always resolves every asset reference. The ``.raw`` suffix keeps Godot's
import pipeline from claiming the file, so its raw bytes survive intact in any
export — see ``assets/README.md`` and ``tools/build_pck.sh``. Production art
(kept in the private ``project-nihon-assets`` repo) is packed into a ``.pck``
that overlays it at runtime.

The body detail texture is an intentionally ugly magenta/black checkerboard so a
shipped placeholder can never be mistaken for real art. The body masks
(``color_mask`` R/G/B = Primary/Secondary/Accent, ``channel`` R/G/B =
Metal/Emission/Wear) are all black, opaque RGBA: base colour only, no channel,
which is what the character shader does with no mask bound. The player rig's own
detail sheet (``textures/characters/player.png.raw``, laid out on the rig's UVs)
is all white, opaque RGBA: what ``detail_tex`` does unbound, so binding it on
the rig changes nothing in a public clone.

    python3 tools/gen_placeholder.py                # every placeholder below
    python3 tools/gen_placeholder.py <out>          # <out>'s own sheet, to <out>
    python3 tools/gen_placeholder.py --mask <out>   # a black mask, to <out>
    python3 tools/gen_placeholder.py --white <out>  # a white sheet, to <out>

Item icons (``icons/items/<ItemId>.png.raw``, 32x32 RGBA) are a flat tile per item in a
colour derived from its id, with a magenta border so a placeholder is never mistaken for
art. ``ITEM_IDS`` lists the ids the production pack ships. The GraywolfPack creature
textures (``textures/creatures/GraywolfPack*.png.raw``) are the checkerboard (base) and
two black masks (``_channel``, ``_color_mask``), like the player's. The nine roster creatures
(``CREATURE_SIZES``) get the same three sheets at 128x128 or 64x64.

A bare ``<out>`` writes the sheet its default path gets (black for the mask
files, white for the rig detail file) and the checkerboard for any other path.
The default outputs resolve against the repo root, so the script works from
any directory.
"""
import struct
import sys
import zlib
from pathlib import Path

SIZE = 64
CELL = 8
COL_A = (255, 0, 255)   # magenta
COL_B = (8, 8, 8)       # near-black
MASK = (0, 0, 0, 255)   # opaque black: no mask region, no channel
WHITE = (255, 255, 255, 255)  # opaque white: detail multiplies by 1

ICON_SIZE = 32
ICON_BORDER = 2
ITEM_IDS = (
    "AethermiteBow AethermiteDust AethermiteShard AlchemyPotion AshiteBlock CarpenterAxe "
    "DuskfiberCloak EnchantedAethermiteShard FerriteHelmet FerriteIngot FerritePick FerriteShield "
    "FerriteShortSword FieldRations LumenfiteOrb RefinedVoiditeShard ThornwoodPlank VeilsteelChestplate "
    "VeilsteelIngot VeilsteelLongsword VeilsteelPick VoiditeEdge VoidRuneTablet"
).split()

ROOT = Path(__file__).resolve().parent.parent
CHECKER_OUT = ROOT / "assets/textures/placeholder_character.png.raw"
MASK_OUTS = (ROOT / "assets/textures/characters/player_color_mask.png.raw",
             ROOT / "assets/textures/characters/player_channel.png.raw")
RIG_DETAIL_OUT = ROOT / "assets/textures/characters/player.png.raw"
WOLF_OUT = ROOT / "assets/textures/creatures/GraywolfPack.png.raw"
WOLF_MASK_OUTS = (ROOT / "assets/textures/creatures/GraywolfPack_channel.png.raw",
                  ROOT / "assets/textures/creatures/GraywolfPack_color_mask.png.raw")
# Creature roster: name -> texture size (the base sheet, ``_color_mask`` and ``_channel`` share it).
CREATURE_SIZES = {
    "ForestBoar": 128, "SteppeBison": 128, "CinderGargoyle": 128, "VoidSerpent": 128, "LavaSlug": 128,
    "RiftWarden": 128, "GlimmerFox": 64, "RidgeHawk": 64, "VeilStalker": 64,
}
CREATURE_DIR = ROOT / "assets/textures/creatures"
ICON_DIR = ROOT / "assets/icons/items"


def _chunk(ctype: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + ctype + data + struct.pack(">I", zlib.crc32(ctype + data))


def _png(width: int, height: int, color_at) -> bytes:
    """8-bit RGB, or RGBA when `color_at` returns four components (at every pixel)."""
    channels = len(color_at(0, 0))
    if channels not in (3, 4):
        raise ValueError(f"color_at must return 3 or 4 components, got {channels}")
    raw = bytearray()
    for y in range(height):
        raw.append(0)  # filter type 0
        for x in range(width):
            px = color_at(x, y)
            if len(px) != channels:
                raise ValueError(f"pixel ({x}, {y}) has {len(px)} components, expected {channels}")
            raw.extend(px)
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6 if channels == 4 else 2, 0, 0, 0)
    return (
        b"\x89PNG\r\n\x1a\n"
        + _chunk(b"IHDR", ihdr)
        + _chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + _chunk(b"IEND", b"")
    )


def checker(x: int, y: int):
    return COL_A if ((x // CELL) + (y // CELL)) % 2 == 0 else COL_B


def black(x: int, y: int):
    return MASK


def white(x: int, y: int):
    return WHITE


def _write(out: Path, color_at, size: int = SIZE) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(_png(size, size, color_at))
    print(f"wrote {out}")


def _icon_color(item_id: str) -> tuple:
    """A stable mid-tone colour per item id (crc32 of the id; no hash() salting)."""
    h = zlib.crc32(item_id.encode())
    return (64 + h % 128, 64 + (h >> 8) % 128, 64 + (h >> 16) % 128, 255)


def _write_icon(out: Path, item_id: str) -> None:
    fill = _icon_color(item_id)
    edge = ICON_SIZE - ICON_BORDER

    def color_at(x: int, y: int):
        on_edge = min(x, y) < ICON_BORDER or max(x, y) >= edge
        return (*COL_A, 255) if on_edge else fill

    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(_png(ICON_SIZE, ICON_SIZE, color_at))
    print(f"wrote {out}")


# Every default output and the sheet it gets: the no-argument run writes all of
# them, and a bare ``<out>`` naming one of them writes its sheet.
OUTPUTS = {
    CHECKER_OUT: checker,
    **{out: black for out in MASK_OUTS},
    RIG_DETAIL_OUT: white,
    WOLF_OUT: checker,
    **{out: black for out in WOLF_MASK_OUTS},
}
# Roster creatures: (path, sheet, size) for the base sheet and the two black masks.
CREATURE_OUTPUTS = [
    (CREATURE_DIR / f"{name}{suffix}.png.raw", sheet, size)
    for name, size in CREATURE_SIZES.items()
    for suffix, sheet in (("", checker), ("_color_mask", black), ("_channel", black))
]
FLAGS = {"--mask": black, "--white": white}


def main() -> None:
    args = sys.argv[1:]
    if len(args) == 2 and args[0] in FLAGS:
        _write(Path(args[1]), FLAGS[args[0]])
    elif len(args) == 1 and not args[0].startswith("-"):
        out = Path(args[0])
        sizes = {path.resolve(): (sheet, size) for path, sheet, size in CREATURE_OUTPUTS}
        sheet, size = sizes.get(out.resolve(), (OUTPUTS.get(out.resolve(), checker), SIZE))
        _write(out, sheet, size)
    elif not args:
        for out, color_at in OUTPUTS.items():
            _write(out, color_at)
        for path, sheet, size in CREATURE_OUTPUTS:
            _write(path, sheet, size)
        for item_id in ITEM_IDS:
            _write_icon(ICON_DIR / f"{item_id}.png.raw", item_id)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
