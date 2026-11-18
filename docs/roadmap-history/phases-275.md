## Phase 275 — Audio foundation: a sound loader, an event table, a bus layout and placeholder sounds

The game has no sound files, no `assets/sounds/` and no playback code. The options window (Phase 225) sets
Master, Music and Effects volumes, and `GameSettings.ensure_buses` creates the Music and Effects buses on first use
because the project ships no `default_bus_layout.tres`. The asset rules every sound must follow are already set:
the placeholder rule (every private key has a public placeholder at the same key, CI never checks out the
submodule) and the `.raw` rule (files are read with `FileAccess.get_file_as_bytes()` and decoded by the game,
never `load()`).

- **Loader:** `AssetOverlay.load_sound(key)` decodes `.ogg.raw` bytes with
  `AudioStreamOggVorbis.load_from_buffer`, through `resolve_path` (the production pack wins by key), and caches
  the stream. A key with no file or bytes that do not decode warns once and returns null; nothing crashes.
- **Event table in the fabric:** `fabric/gameplay/sounds.js` `EVENTS`: event id → `key`, `bus`, `spatial`
  (`2d`/`3d`), `variants`, `volumeDb`, `pitchJitter`, `loop`, `maxDistance` (3d). The `SoundEvents` world system
  carries it, its `buses` and its `files` (the asset keys of each event, derived from the key so the runtime and
  the placeholder tool share one rule) into `godot/world_systems/soundevents.tres`.
- **Play API:** the `Sound` autoload (`src/audio/sound_player.gd`): `play(event_id, at = null) -> Node`,
  `plan(event_id, at = null) -> Dictionary` (the same choices, without playing), `playing(event_id)`,
  `stop(event_id)`, `stop_all()`, `enabled`, `rng`. Gameplay never names a path.
- **Key layout:** `sounds/ui/<event>.ogg.raw`, `sounds/sfx/items/<ItemId>/<event>_01.ogg.raw` (`_02`.. variants),
  `sounds/sfx/creatures/<Entity>/<event>_01.ogg.raw`, `sounds/sfx/player/footsteps/<surface>_01.ogg.raw`,
  `sounds/sfx/world/<thing>_01.ogg.raw`, `sounds/ambience/<Biome>.ogg.raw` (loops),
  `sounds/music/<track>.ogg.raw` (loops), documented in `assets/README.md`.
- **Buses:** `default_bus_layout.tres` with Master → Music, Effects, Ambience, UI; `GameSettings` sets them and
  never creates one. Ambience and UI volume sliders join the Sound tab, labelled through the catalog.
- **Placeholders:** `tools/gen_placeholder_audio.py` writes a deterministic tone, click or noise per key from the
  event table (variants too), lists them under `sounds` in `assets/manifest.json`, and `--check` fails on a
  stale, missing or orphaned file.
- A starter set of events (one per folder kind) exists so the pipeline is tested end to end. Wiring sounds into
  gameplay is the next phase.

**Acceptance criteria**
- [x] `npm run validate` and `check-drift` pass; the validator rejects a key outside the layout, a wrong bus, a
  positional UI/ambience/music sound, variants on a single-file folder, a 3d sound with no range, an unknown
  item, creature or biome, a shared key, a bad id, an out-of-range volume or jitter and a changed bus list;
  `node tools/check_sounds.js` proves each.
- [x] `python3 tools/gen_placeholder_audio.py --check` passes in CI without ffmpeg, and `--self-test` proves it
  fails on a missing file, an orphan, an edited file, a non-Vorbis file, a changed synth, a lock row with no
  event, a manifest without the key and a missing lock.
- [x] Suite (`audio_tests.gd`): the bus layout is Master → Music, Effects, Ambience, UI and matches the fabric;
  every event's files exist, are in the manifest and the manifest lists nothing else; every placeholder decodes
  and is cached; a missing key and an unknown event play nothing and warn once; `play` puts an event on its bus
  with its volume, a variant and a pitch inside the jitter, 3D at a position; loops play until `stop`; a sound in
  a mounted pack overrides by key.
- [x] Suite (`options_tests.gd`): the Ambience and UI volumes round-trip through the settings file and apply to
  their buses; every label is in both `en` and `pt_BR`.

**Delivered.** `AssetOverlay.load_sound` decodes and caches, warning once per unplayable key (the cache is cleared
by `reload_manifest`). The fabric table ships six starter events: `ui.click`, `footstep.grass` (3 variants, 3d),
`item.StonePick.hit` (2, 3d), `creature.GraywolfPack.attack` (2, 3d), `ambience.TemperateForest` and
`music.main_theme`. `Sound.play` makes an `AudioStreamPlayer` (or an `AudioStreamPlayer3D` for a 3d event given a
`Vector3`) as its own child, sets the stream's `loop` from the event, and frees a one-shot when it finishes; it
returns null when `enabled` is false (for a dedicated server, which no boot path sets yet). `GameSettings` maps
each volume option to its bus through `VOLUME_BUSES` and warns about a bus the layout lacks instead of creating
it; `ensure_buses` is gone. The options window builds its rows from `GameSettings.SPEC`, so the two new sliders
needed only the spec rows and their `options.volume_ambience` / `options.volume_ui` catalog keys.

Encoding decision: Python's stdlib synthesizes the PCM (48 kHz; mono for effects, stereo for UI, ambience and
music; noise from a 31-bit LCG seeded by the key's CRC) and ffmpeg encodes it (libvorbis `-qscale:a 0`,
`-fflags +bitexact -flags:a +bitexact -serial_offset 0`, no metadata). Two encodes on one machine are
byte-identical (checked), but libvorbis is floating point and another build could give other bytes, so CI never
encodes: `assets/sounds/placeholders.lock.json` records each key's PCM hash and file hash, `--check` re-synthesizes
and compares (stdlib only), and a plain run re-encodes only a missing or stale key. The ten placeholder files
total about 95 KB.
