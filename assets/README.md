# Assets — public placeholders + private production art

Project Nihon keeps **production art private** while shipping a **fully-runnable
public clone**. This directory holds the public side of that split.

## The model

- **Canonical paths.** Every asset is referenced by a stable `res://` path under
  `res://assets/` (e.g. `res://assets/textures/placeholder_character.png`).
  Code references these paths and nothing else.
- **Public placeholders.** This repo commits *ugly* placeholder files at those
  exact paths, so a fresh `git clone` opens and runs in Godot with zero
  missing-resource errors.
- **Private production art.** Real art lives in the private
  [`project-nihon-assets`](https://github.com/Tubaleviao/project-nihon-assets)
  repo, wired in as the `assets-prod/` git submodule. That repo mirrors the
  `assets/` tree and tracks large binaries with **Git LFS**.
- **The `.pck` override.** Production art is packed into a single `assets.pck`
  (see `tools/pack_pck.gd` / `tools/build_pck.sh`). At startup the `AssetOverlay`
  autoload mounts that pack over `res://`, so every placeholder path is replaced
  by its production counterpart — no code change, no private path in code.
- **Builds.** The Steam/release build bundles `assets.pck`; the public/GitHub
  build ships placeholders only.
- **DLC alignment.** The pack-mount mechanism is exactly how paid DLC content
  packs will be layered later: a `.pck` is the unit of optional content.

## Regenerating a placeholder

```bash
python3 tools/gen_placeholder.py assets/textures/placeholder_character.png
```

## Building the production pack

```bash
git submodule update --init assets-prod   # private repo — requires access
tools/build_pck.sh                        # emits assets.pck (gitignored)
```

The `assets.pck` is gitignored and must never be committed — it is built from
private art and committing it would leak that art into the public repo.
