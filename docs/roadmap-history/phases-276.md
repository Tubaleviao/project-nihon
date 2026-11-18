## Phase 276 — First sounds wired in: clicks, windows, footsteps, the dig, pickups, a creature's attack, ambience and music

Phase 275 built the audio pipeline (the `Sound` autoload, the fabric's event table, the bus layout, placeholder
files) but nothing in gameplay called it, and no boot path turned it off on a dedicated server. This phase wires
in a first set of sounds, so the pipeline is in use. Each one has a placeholder made by the generator.

- **UI, at the shared points:** every button that enters the tree plays `ui.click` (one `SceneTree.node_added`
  hook in `Sound`; a button with the meta `no_click_sound` stays silent). `UiSlice.open_window` / `close_window` /
  `_close_all_windows` and the Esc menu play `ui.window_open` / `ui.window_close` once per real change.
- **Footsteps:** the local player plays one step per 1.6 m walked on the ground (`AudioWiring.step_due`), at the
  feet. The surface comes from what is underfoot (`surface_for`). A placed block gives the fabric's
  `footsteps.block` surface. Natural ground gives the surface of the terrain material that the biome's flat
  ground is drawn with (`footsteps.terrain`, which covers every terrain material). Three surfaces: grass, stone
  and sand.
- **The dig:** every `block_changed` "mine" plays `world.dig` at the dug block, so everyone near it hears it: the
  digger, a listen host, another client. The local player's own completed mine also plays the held tool's strike
  (`item.<tool>.hit`, for a tool that has the event), at the aimed point.
- **Pickups:** the local inventory's `item_picked_up` and the local player's loose-item pick play `world.pickup`
  (2D). A remote actor's pick, re-run on the host, plays nothing there.
- **A creature's attack:** each swing the host resolves, or a client receives as `combat_hit_synced`, plays
  `creature.<Type>.attack` at the creature. The client uses the same key rule as the animation.
- **Ambience and music:** `Sound.play_loop(channel, event, fade)` keeps one loop per channel and cross-fades when
  the event changes. Once a second, the ambience follows the biome under the player (`ambience.<Biome>`, faded out
  where the biome has none), and `music.main_theme` starts once the player is in the world.
- **Who hears what:** 3D sounds are placed at scene positions (world plus the player's scene offset) and skipped
  when the listener is beyond the event's `maxDistance`. `AudioWiring.apply_boot_role` (run when the booting root wires the module) turns `Sound` off on a
  dedicated server (`--server`) and on any headless boot, and a server root connects no sound handler.

**Acceptance criteria**
- [x] `npm run validate` and `check-drift` pass. `node tools/check_sounds.js` also proves the validator rejects a
  footstep table that misses a terrain material, names an unknown one, names a surface with no `footstep.<surface>`
  event or a block surface with no event, or puts a footstep event off its surface key.
- [x] `python3 tools/gen_placeholder_audio.py --check` and `--self-test` pass with the new placeholders.
- [x] Suite (`sound_wiring_tests.gd`), checked through the `Sound.trace` test hook and never through audible
  output:
  - Each wired event fires through the registry: the dig, the tool strike, both pickups, a creature's attack on
    the host and on a client, a footstep, the ambience and the music, a button click, and a window opening and
    closing (each once).
  - A placement, a remote actor's mine or pick, and a player's swing play nothing.
  - Every wired event plays on its event's bus, and that bus has a volume option.
  - The footstep surface follows the block or biome underfoot, and every biome resolves to a surface that has an
    event. Steps fall once per stride, only on the ground.
  - A loop channel fades in, cross-fades and fades out, then frees its player.
  - A server or headless boot turns `Sound` off, and a server root wires and plays nothing.

**Delivered.** New events: `ui.window_open`, `ui.window_close`, `footstep.stone` (3 variants), `footstep.sand` (3),
`world.dig` (3, 3d) and `world.pickup` (2, 2d). Phase 275's `ui.click`, `footstep.grass`, `item.StonePick.hit`,
`creature.GraywolfPack.attack`, `ambience.TemperateForest` and `music.main_theme` are now played from gameplay.
The fabric's `SoundEvents` gains `footsteps` (`{ terrain: { TerrainGrass/Moss/Dirt/Mud: grass, TerrainRock:
stone, TerrainSand/Snow: sand }, block: stone }`). The gameplay wiring is `src/audio/audio_wiring.gd`, one module
in `GameRoot`'s wiring list. `Sound` gains `play_loop` / `stop_channel` / `channel_event` / `step_fades`, the
button hook and the `tracing` / `trace` test hook.

Left out: remote players' footsteps (only the local player's own steps play), steepness (a slope that the terrain
shader draws as rock still sounds like the biome's ground), and music on the main menu.
