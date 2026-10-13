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
which is what the character shader does with no mask bound.

    python3 tools/gen_placeholder.py               # every placeholder below
    python3 tools/gen_placeholder.py <out>         # the checkerboard, to <out>
    python3 tools/gen_placeholder.py --mask <out>  # a black mask, to <out>

An ``<out>`` that is one of the mask files writes a mask, not the
checkerboard. The default outputs resolve against the repo root, so the script
works from any directory.
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

ROOT = Path(__file__).resolve().parent.parent
CHECKER_OUT = ROOT / "assets/textures/placeholder_character.png.raw"
MASK_OUTS = (ROOT / "assets/textures/characters/player_color_mask.png.raw",
             ROOT / "assets/textures/characters/player_channel.png.raw")


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


def _write(out: Path, color_at) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(_png(SIZE, SIZE, color_at))
    print(f"wrote {out}")


def _is_mask(out: Path) -> bool:
    return out.resolve() in MASK_OUTS


def main() -> None:
    args = sys.argv[1:]
    if args[:1] == ["--mask"] and len(args) == 2:
        _write(Path(args[1]), black)
    elif len(args) == 1 and not args[0].startswith("-"):
        out = Path(args[0])
        _write(out, black if _is_mask(out) else checker)
    elif not args:
        _write(CHECKER_OUT, checker)
        for out in MASK_OUTS:
            _write(out, black)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
