# Character style: the chibi player

Goal: the cute, big-headed chibi feel of classic 2000s isometric MMOs, in this game's own art. No assets,
sprites or likenesses are taken from any other game.

## Decision: a toon-shaded 3D rig, not pre-rendered sprites

The character stays a 3D skinned rig (`player_rig.glb.raw` plus the `characters/{bodies,heads,hair}` parts).
Reason: the camera rotates freely and flies; equipment, hair and the creation screen already attach to rig
bones (Phase 265); 8-direction sprites would need every equipment piece rendered in every direction and clip.
The classic look comes from proportions, shading and palette, not from sprites. Owner may overturn this in
issue #674's follow-ups.

## Proportions

- Head height over total height: 0.28 to 0.40 (`CharacterCreation.headRatio`), i.e. roughly 1:1.5 to 1:2.5
  head to body. The placeholder is 0.40 m head on a 1.10 m figure (0.36).
- Short limbs, small hands and feet, a wide head box wider than the shoulders.
- A suite test (`creation: the placeholder body and head meshes measure within the chibi head ratio`)
  measures the shipped meshes and fails if the ratio leaves the range.

## Silhouette

- Readable at the default camera distance as: big round head, small torso, stubby legs.
- Hair adds volume above and behind the head but never exceeds the head width by more than a hair box.
- Equipment keeps the silhouette: helmets replace hair volume, not add to it.

## Face, shading, palette

- Big, expressive eyes on the face plane (`textures/characters/eyes`), simple shapes, no fine detail.
- Flat or toon shading with a dark outline; any toon shader or outline lives in `character_material`.
- Colour from the existing `DefaultPalette` regions only; skin, hair and cloth tint per region.

## Rig contract

The placeholder keeps every bone and clip of the production rig (the placeholder rule in
`assets/README.md`); `tools/gen_placeholder_glb.py` generates it, and `assets-prod/` follows with the same
bones and clips.
