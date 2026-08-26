# Assets — public placeholders + private production art

Project Nihon keeps **production art private** while shipping a **fully-runnable
public clone**. This directory holds the public side of that split.

## The model

- **Canonical keys.** Every asset is referenced by a stable relative key (e.g.
  `textures/placeholder_character.png.raw`), resolved at runtime through
  `AssetOverlay.resolve_path()`/`AssetOverlay.load_texture()` — code never
  hardcodes `res://assets/...` or `res://_overlay/...` directly.
- **The `.raw` convention.** Every asset under `res://assets/` (and its private
  counterpart in `assets-prod/`) carries an extra trailing `.raw` suffix, e.g.
  `placeholder_character.png.raw`. Godot's import pipeline compiles any
  *recognized* extension (`.png`, `.wav`, …) into a compiled resource under
  `res://.godot/imported/...` and drops the raw bytes at the bare path
  entirely from a real export — `FileAccess`/`Image.load()` on that bare path
  fail in a shipped build even though they work fine from the editor. The
  `.raw` suffix is unrecognized by the importer, so the file is packed
  byte-for-byte and stays readable via `FileAccess.get_file_as_bytes()` in
  every context, editor or export. Read such files with
  `AssetOverlay.load_texture()` (which uses `get_file_as_bytes()` +
  `Image.load_png_from_buffer()`) — never `load()`/`Image.load()`.
- **Public placeholders.** This repo commits *ugly* placeholder files at those
  exact `.raw` paths, so a fresh `git clone` opens and runs in Godot with zero
  missing-resource errors, no private submodule required.
- **Private production art.** Real art lives in the private
  [`project-nihon-assets`](https://github.com/Tubaleviao/project-nihon-assets)
  repo, wired in as the `assets-prod/` git submodule (mirroring `assets/`'s
  layout and `.raw` convention, tracked with **Git LFS**). It also carries a
  `.gdignore`, so Godot's scanner never touches it in place.
- **The `.pck` override.** `tools/build_pck.sh` stages a plain copy of
  `assets-prod/` into a disposable pack-only project
  (`tools/pack_project/_overlay/`) and runs Godot's own exporter
  (`godot --export-pack`) over it, producing `assets.pck`. Because
  `--export-pack` cannot remap a file's path, the pack's internal paths land
  under `res://_overlay/<rel>`, not `res://assets/<rel>`. At startup the
  `AssetOverlay` autoload mounts that pack over `res://`; `resolve_path(rel)`
  then prefers `res://_overlay/<rel>` when present, falling back to the
  committed placeholder at `res://assets/<rel>` otherwise — no code change,
  no private path in code.
- **Builds.** `export_presets.cfg`'s "Linux"/"Windows Desktop" presets exclude
  both `assets-prod/*` and `_overlay/*`, and force-include `assets/*` (raw
  files aren't swept in automatically). The Steam/release build additionally
  ships `assets.pck` alongside the executable; the public/GitHub build ships
  placeholders only.
- **DLC alignment.** The pack-mount mechanism is exactly how paid DLC content
  packs will be layered later: a `.pck` is the unit of optional content.

## Regenerating a placeholder

```bash
python3 tools/gen_placeholder.py assets/textures/placeholder_character.png.raw
```

## Building the production pack

```bash
git submodule update --init assets-prod   # private repo — requires access
tools/build_pck.sh                        # emits assets.pck (gitignored)
```

The `assets.pck` is gitignored and must never be committed — it is built from
private art and committing it would leak that art into the public repo.

## Verifying the override works

`src/tests/test_suite.gd`'s `_test_asset_pck_round_trip_override` builds a
fixture pck with `PCKPacker`, mounts it via
`ProjectSettings.load_resource_pack()`, and asserts `AssetOverlay.resolve_path`
now serves the overlaid bytes instead of the placeholder — this is a real
mount + read-back, not just a check that the relevant constants look right.
