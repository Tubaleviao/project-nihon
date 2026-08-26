#!/usr/bin/env python3
"""Regenerate the committed placeholder art.

Placeholders live at canonical ``res://`` paths under ``assets/`` so a public
clone always resolves every asset reference. The ``.raw`` suffix keeps Godot's
import pipeline from claiming the file, so its raw bytes survive intact in any
export — see ``assets/README.md`` and ``tools/build_pck.sh``. Production art
(kept in the private ``project-nihon-assets`` repo) is packed into a ``.pck``
that overlays it at runtime.

The output is an intentionally ugly magenta/black checkerboard so a shipped
placeholder can never be mistaken for real art.
"""
import struct
import sys
import zlib
from pathlib import Path

SIZE = 64
CELL = 8
COL_A = (255, 0, 255)   # magenta
COL_B = (8, 8, 8)       # near-black


def _chunk(ctype: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + ctype + data + struct.pack(">I", zlib.crc32(ctype + data))


def _png(width: int, height: int, color_at) -> bytes:
    raw = bytearray()
    for y in range(height):
        raw.append(0)  # filter type 0
        for x in range(width):
            raw.extend(color_at(x, y))
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)  # 8-bit RGB
    return (
        b"\x89PNG\r\n\x1a\n"
        + _chunk(b"IHDR", ihdr)
        + _chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + _chunk(b"IEND", b"")
    )


def checker(x: int, y: int):
    return COL_A if ((x // CELL) + (y // CELL)) % 2 == 0 else COL_B


def main() -> None:
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("assets/textures/placeholder_character.png.raw")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(_png(SIZE, SIZE, checker))
    print(f"wrote {out}")


if __name__ == "__main__":
    main()
