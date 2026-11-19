## Phase 265 — One body everywhere: the creation screen, the Character window and the world draw the same avatar

The world avatar is the `models/player_rig.glb` rig with its material and palette
(`attach_default_rig`). The creation screen and the Character window's doll are built by the older
procedural body in `character_part_2.gd` `_make_visual`, so they show a different character. That
body draws hair as one box tinted by the hair colour and never reads the style, which is why picking
a hair style changes nothing on the right of the creation screen. The per-style hair meshes
(`models/characters/hair/<id>.glb.raw`, drawn by `gen_placeholder_glb.py`) are never loaded.

- **One builder:** an avatar builder (for example `src/character/avatar_builder.gd`) takes an
  appearance and a worn set and returns the rig the world uses: the player rig, its material and
  palette indices, the hair style's mesh on the head socket, and the worn equipment on their
  sockets. The world avatar, the creation screen's rig and the Character window's doll all call it.
  The procedural box body remains only as the fallback when no rig is listed in the manifest.
- **Hair:** the chosen style's mesh is loaded from its key and tinted by the hair colour; a style
  change on the creation screen swaps it on the next frame. The same mesh is what other players see.
- **The doll and the creation rig animate** with the idle clip, lit like the world's camera sees the
  avatar, so the three views match.

**Acceptance criteria**
- Suite tests: for the same appearance and worn set, the world avatar, the creation rig and the
  doll have the same mesh resources, the same material parameters and the same attached nodes.
- Suite tests: every hair style in `CharacterCreation.hairStyles` loads its own mesh on the head
  socket; two different styles give different meshes; changing the style on the creation screen
  replaces the hair mesh.
- Every hair key has a placeholder in `assets/` (the placeholder rule), checked by the suite.
- The playtest `create` and `character_sheet` steps assert the rig's hair mesh matches the chosen
  style, and still render non-blank.
