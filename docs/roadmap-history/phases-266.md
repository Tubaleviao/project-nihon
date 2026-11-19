## Phase 266 — A chibi character worth looking at: the art direction and the player rig

The owner finds the player character ugly and not the style they want: the cute, big-headed chibi
look of classic 2000s isometric MMOs (the owner's reference is Ragnarok Online). The goal is that
feel in this game's own art; no assets, sprites or likenesses are taken from any other game.

- **An art direction document** (`docs/art/character-style.md`): proportions (head to body about
  1:2 to 1:2.5, within `CharacterCreation.headRatio`), silhouette rules, big expressive eyes, simple
  shapes, flat or toon shading with an outline, a limited palette (the existing `DefaultPalette`
  regions), and how hair and equipment read at the default camera distance.
- **The decision to make first** (owner, filed as an issue): a toon-shaded 3D chibi rig, or
  pre-rendered sprites in 8 directions drawn over the 3D world (the classic look, harder to combine
  with free camera rotation and equipment). The document records the choice and the reason.
- **The placeholder rig** (`gen_placeholder_glb.py`) is redrawn to those proportions so the public
  build already has the shape, and the production rig in `assets-prod/` follows with the same bones
  and clips. A toon shader and outline for characters, if chosen, live in `character_material`.
- The hair meshes (Phase 265) are redrawn to the same style.

**Acceptance criteria**
- `docs/art/character-style.md` exists with the proportions, and the choice between 3D and
  sprites is recorded in it.
- A suite test measures the placeholder rig's head height against its full height and asserts it
  is within `CharacterCreation.headRatio`.
- The placeholder rig keeps every bone and clip the production rig has (the placeholder rule), and
  the playtest `walk` and `create` steps pass with it.
- Whether the result looks good is a human judgement: filed as GitHub issue #674.
