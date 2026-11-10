# Project Nihon — Roadmap

Project Nihon is an open-source sandbox MMORPG where players build a
civilization. This document tracks the design and implementation roadmap.
The game's entire design bible — materials, creatures, skills, items, world
systems — is authored as a Newel fabric and generated into documentation,
runtime assets, and Godot resources.

See `../newel/ROADMAP.md` for the Newel-side changes each phase depends on.

**Human verification is not an acceptance criterion.** A criterion must be decidable by the
automated gates — `pnpm validate`, `pnpm check-drift`, the headless suite on both boot paths,
`tools/net_harness.sh`, CI. A check that needs a person at the keyboard (a playtest, a screenshot
judgement, a visual inspection) is not a criterion: it is filed as a GitHub issue and the phase
proceeds without it, so unpublished human work never parks the roadmap. The phase records the
issue number where the criterion used to be.

**Follow-up debt cap.** No new feature phase starts while more than 10 `autopilot-followup`
issues are open. Burn them down first (fix, fold into the next phase, or close with a reason).

---

## Phase index

Phases 1–220 and 223 are done (200 and 201 were aborted). Their specs and acceptance criteria, and the
introductions of the arcs they belonged to, are archived in
[docs/roadmap-history/](docs/roadmap-history/README.md).

### Next: playtest fixes and the game's front door (Phases 219–226)

Filed by the owner on 2026-11-06 after playing `main`. Four are bugs found in play (typing in the
chat box, Enter jumping, re-creating a character, an overfull character window). Three give the game
what every game has and this one does not: a main menu, a pause menu on Esc and an options window.
The last lets a player keep several characters and pick one from the main menu. The bugs come first,
because the menus reuse the keyboard routing Phase 219 fixes.

| Phase | Title | Status |
|---|---|---|
| 219 | A focused text field owns the keyboard: no reversed text, no movement, jumps or hotkeys while typing | Done ([phases-219.md](docs/roadmap-history/phases-219.md)) |
| 220 | Enter never jumps: a `jump` action on Space only | Done ([phases-220.md](docs/roadmap-history/phases-220.md)) |
| 221 | Re-creating a character from the Character window | Done ([phases-221.md](docs/roadmap-history/phases-221.md)) |
| 222 | The Character window fits: fewer rows, the friend code moves to the map | Done ([phases-222.md](docs/roadmap-history/phases-222.md)) |
| 223 | A main menu: play a local world or join a server | Done ([phases-223.md](docs/roadmap-history/phases-223.md)) |
| 224 | The Esc menu: resume, options, exit to main menu, quit | Open |
| 225 | The options window: sound, graphics and game settings | Open |
| 226 | Several characters per player: a new one starts from scratch, chosen in the main menu | Open |

### Arc: one character across worlds (Phases 227–231)

Decided by the owner on 2026-11-07. A player can take a character into a friend's world, level up
there, and keep that progress in their own world. Enshrouded does this by trusting a character file
held by the client. That breaks this game's trust rule (the host never trusts client-reported
state), and it would let one world flood another's economy. So only the character's **knowledge**
moves between worlds, and only as **evidence the host can verify**:

- **Travels:** the player's identity (a keypair), name, appearance, skill XP and cosmetics.
- **Stays in the world:** inventory, equipment, research (technology is per player, but it is
  discovered again in each world, never ported), books learned, position, spawn bed, clan
  membership and owned structures.
- **Skills are capped by the gear:** a combat skill's advanced abilities need a weapon of the same
  tier, and a crafting skill's advanced recipes need a tool and a crafting station of the same tier.
  Weapons, tools and stations are all made in the world. A ported master swordsman still has to
  research, gather and forge a master-tier blade in the new world first, and a ported master smith
  has to build a master-tier forge and hammer before making master-tier goods, so the new world's
  early game stays intact.
- **Cosmetics** are bound to the player's key. They travel to every world because they do nothing
  to the economy, and they can never be traded, dropped, gifted or worn by another player.
- No trophy items for now.

The arc starts after Phase 226, because the keypair identifies the player (the account) and Phase
226 separates player from character.

| Phase | Title | Status |
|---|---|---|
| 227 | Identity and portability in the fabric: keypair identity, what travels, gear-gated skills, bound cosmetics | Open |
| 228 | Keypair identity at runtime: a challenge-response join replaces the cached player id | Open |
| 229 | Skills capped by the gear: advanced abilities need a weapon of their tier, advanced recipes a tool and station of theirs | Open |
| 230 | Characters across worlds: signed progress, an import policy per world | Open |
| 231 | Cosmetics bound to the key: they travel and cannot be shared | Open |

### Next: water, travel and the barber (Phases 232–236)

Filed by autopilot on 2026-11-10 from the Deferred list and the open review follow-ups. Phase 232
finishes the review notes on Phase 217's lakes and rivers (#573) and the mount follow-ups (#593).
Phase 233 makes water flow where players dig. Phases 234 and 235 are the boats and roads the
deferred fast-travel item names. Phase 236 is the hair and dye screen the owner deferred on
2026-11-06. They follow Phase 231.

| Phase | Title | Status |
|---|---|---|
| 232 | Water that holds up: lake shores, the river seam and mounts at fords | Open |
| 233 | Flowing water: a bounded cellular automaton on edited chunks | Open |
| 234 | Boats: crossing lakes, rivers and the sea | Open |
| 235 | Roads: built paths that speed travel on foot and on a mount | Open |
| 236 | Changing hair style and colour: scissors and dye | Open |

## Phase 224 — The Esc menu

Esc today only closes the focused window or field. With nothing open, it does nothing.

- Esc closes, in order: a focused text field, the top open window, then opens a pause menu:
  **Resume**, **Options**, **Exit to main menu**, **Quit game**. Esc again closes the menu.
- On a listen host the world keeps running for connected players (it is an MMO); leaving saves
  first. On a client, exit disconnects cleanly.
- While the menu is open, world input is frozen (Phase 219's rule).

**Acceptance criteria**
- A suite test presses Esc with a window open (it closes, no menu), then again (menu opens), then
  again (menu closes).
- A suite test runs Exit to main menu on a listen host and asserts the save was written and the main
  menu is shown with no world nodes left (no orphans).
- #599 (swap-back): the root swap in `main.gd` (`_back_to_menu`) that Exit to main menu reuses
  moves into a testable static, and a suite test drives it with a stub root (old root freed, a fresh
  `GameRoot` with the notice).
- #599 (address rule): `RecentServers.valid_address` and `BootWiring._valid_host_address` are one
  function; a suite test feeds both paths the same addresses.
- #599 (explored map): a local world's revealed map is keyed by its world folder; a suite test
  creates two local worlds with the same seed and finds separate explored maps.
- #599 (menu join): a net harness step boots a client from a real main menu (no `--net-harness`
  role) through `MenuWiring.start` and joins the host.

**Closes:** #599

## Phase 225 — The options window

Settings exist in scattered places (language since Phase 131, the tutorial switch since Phase 186,
admin-only tools). They get one window, reachable from the main menu and the Esc menu.

- **Sound**: master, music, effects volume (audio buses).
- **Graphics**: window mode, resolution, VSync, view distance (the near/far ring policy), FPS cap.
- **Game**: language, tutorial on/off and reset, mouse sensitivity and invert, controls list.
- Saved to the existing user settings file and applied at once. Language follows the CLAUDE.md
  order: saved preference, then OS locale, then `en`.

**Acceptance criteria**
- A suite test changes each setting, saves, reloads the settings in a fresh object and reads back the
  same values, and asserts the change was applied (bus volume, `TranslationServer` locale, tutorial
  flag).
- A suite test asserts every options label is a key in both `en` and `pt_BR`.

## Phase 226 — Several characters per player

Decided by the owner (2026-11-06): a player cannot re-create a character in place (Phase 221), but
can create other characters from the main menu, and each new one starts from scratch. Today a
player id is one character: the registry, the creation record, inventory, skills, attributes,
research, clan membership and owned structures all key on the player id.

- **Fabric first** (separate PR): a character entity under the player (account), what belongs to the
  character (body, name, inventory, equipment, skills, attributes, research, books learned, clan
  membership, owned structures, spawn bed) and what belongs to the player (friend code, settings,
  admin flag). A character limit per player per server, and whether a deleted character's
  structures fall to its clan or become ownerless.
- **Runtime:** the registry keys character state by character id. The host refuses a new character
  over the limit, and a new character gets no items, skills, research or memberships from the
  player's other characters. Names stay unique per server across all characters (`name_taken`).
- **Main menu:** after choosing a local world or joining a server, a character list (name, body
  preview, last played) with **Play**, **New character** (the creation screen) and **Delete** (with a
  confirmation typed as the character's name). The host sends the list; the client never decides
  which characters exist.
- Existing saves migrate: each player's one character becomes their first character, unchanged.

**Acceptance criteria**
- `npm run validate` and `check-drift` pass with the character entity; a `tools/check_*.js` rejects
  a table that puts inventory or skills on the player instead of the character.
- A suite test creates two characters for one player: the second has an empty inventory, base
  attributes, no skills, no research and no clan, and the first is unchanged.
- A suite test refuses a character over the limit and a name already used by another character on
  the server.
- A suite test loads a pre-Phase-226 save and finds each player's character as their first, with
  the same state.
- A net harness step: a client lists its characters, creates a second, enters with it, reconnects
  and enters with the first.

## Phase 227 — Identity and portability in the fabric

Design-only (a fabric PR, no GDScript). Everything after it reads from this phase's entities.

- **`PlayerKeyIdentity` decision**, superseding `PlayerIdentityModel`: a player is a public key.
  The client generates a signing keypair once and keeps the private key in `user://`, never sent
  anywhere. The id the host stores is the key's fingerprint. On join the host sends a fresh random
  nonce and the client signs it, so presenting someone else's id without their private key fails.
  The decision names the algorithm: RSA through Godot's built-in `Crypto`/`CryptoKey`, or Ed25519,
  which needs a GDExtension. Record the trade-off (key and signature size, a dependency, the
  headless server). It also names the migration of saves keyed by a minted `player_id`, and that
  every host has a key too, whose fingerprint the client signs into the join answer (Phase 228).
- **Portability table:** each character field (from Phase 226's character entity) is marked
  `portable` or `world_bound`, following the arc introduction. Technology/research, inventory,
  equipment, books learned, clan membership and owned structures are `world_bound`.
- **World import policy:** `local` (default; every character starts from scratch, as today),
  `trusted` (accepts progress signed by listed host keys), `open` (accepts progress signed by any
  host). A **progress delta** entity: player key, character id, issuing host key, world id, skill
  XP gained per skill, sequence number, and the host's signature.
- **Gear-gated skills:** every weapon, crafting tool and crafting station gets a `tier` (from
  `SKILL_TIERS`). Each combat ability and each recipe gets a `requiredTier`. A rule says a combat
  ability is usable only when both the skill and the equipped weapon reach that tier, and a recipe
  can be crafted only when the crafting skill, the tool it uses and the station it is made at all
  reach that tier. Recipes that need no tool or no station skip that check.
- **Bound cosmetics:** a cosmetic entity kind (skin, emote, decoration, pet, per
  `MonetizationModel`) and a **cosmetic grant**: cosmetic id, owner key, issuer key, signature. A
  rule says cosmetics are never items: they have no stack, no trade, no drop, no chest, no loot.
  Cosmetic names are i18n keys, not prose.

**Acceptance criteria**
- `npm run validate` and `npm run check-drift` pass with the new entities, and
  `PlayerIdentityModel` is `superseded`.
- A new `tools/check_portability.js` (and its CI step) rejects a table that marks technology,
  inventory, equipment or owned structures as portable, a weapon, crafting tool or crafting station
  with no tier, a recipe with no `requiredTier`, and a cosmetic that
  can be traded, dropped or stored.

## Phase 228 — Keypair identity at runtime

- The client creates its keypair on first boot (`user://identity/`, private key file readable only
  by the user where the OS allows it) and reuses it after that. Losing the file means a new player,
  as losing a save does.
- Every host gets its own signing key here (`user://` for a listen host, the save folder for a
  dedicated server) and a world id; Phase 230 reuses them.
- The join handshake: the client sends its public key, the host replies with its own public key and
  a single-use nonce with an expiry, and the client signs `join | host key fingerprint | nonce`.
  Binding the host's key into the signed message stops a malicious host from relaying a nonce from
  another host and replaying the victim's answer there. The host verifies the signature and that the
  fingerprint is its own before binding the peer, and accepts no other intent from the peer until
  then. It refuses a key already bound to a live peer, an expired or reused nonce, an oversized key,
  a signature over another host's fingerprint and a bad signature, and it rate-limits failed
  attempts per address. Refusals reach the client as reason keys shown through `I18n.t()`.
- `PlayerRegistry` keys records by the key fingerprint. The cached-id claim is removed.
- **Migration:** an existing save's minted `player_id` records are bound once to the first key
  that joins and presents the old cached id. After that the old id is refused. The old id is a
  bearer secret only its client holds (the friend code never reveals it), so this is no weaker than
  today. A dedicated server logs every binding.
- The friend code (Phase 222 moves it to the map) keeps working; it does not reveal the key.

**Acceptance criteria**
- A suite test generates a key, signs a host nonce, and joins. Another test fails to join with: a
  replayed nonce, an expired nonce, a signature from another key, a signature over another host's
  key fingerprint, a key held by a live peer, and a key over the size limit. A peer that sends a
  gameplay intent before the handshake completes has it dropped. The refusal reason keys exist in
  both `en` and `pt_BR`.
- A suite test loads a pre-Phase-228 save, joins with the old cached id and a new key, finds the
  same record, and is refused when it presents the same old id with a second key.
- A net harness step: a client joins with its key, disconnects, reconnects and gets the same
  record. A second client that copies the first's public key but not its private key is refused.

## Phase 229 — Skills capped by the gear

- The weapon, tool, station, ability and recipe tiers generated in Phase 227 load through `GameData`.
- **Combat:** the host decides whether an ability can be used from the skill tier **and** the
  equipped weapon's tier. An ability above the weapon's tier is refused with a localized reason key
  (`combat.refuse.weapon_tier`) and greyed out in the hotbar and skill UI, which show the tier needed.
- **Crafting:** the host decides whether a recipe can be crafted from the crafting skill's tier, the
  tier of the tool it uses (from the crafter's inventory or hand) **and** the tier of the station it
  is crafted at. A recipe above either is refused with `craft.refuse.tool_tier` or
  `craft.refuse.station_tier` and greyed out in the crafting window, which shows the tool or station
  tier needed. The host reads the station's tier from its own placed-structure record, never from the
  client.
- Skill XP still grows with any weapon, tool or station. Only use is capped, so carrying weaker gear
  never loses progress.

**Acceptance criteria**
- A suite test gives a character master Swordsmanship and a novice sword. Novice abilities resolve
  and higher abilities are refused with `combat.refuse.weapon_tier`. With a master sword, all of
  them resolve.
- A suite test gives a character master Smithing. A master-tier recipe is refused with a novice
  hammer at a master forge (`craft.refuse.tool_tier`) and with a master hammer at a novice forge
  (`craft.refuse.station_tier`), and crafts with both at master tier. No materials are consumed by a
  refused craft.
- A suite test: a client that sends an ability intent above its weapon's tier, or a craft intent
  naming a station tier it does not have, is refused by the host. No damage is applied and no item
  is made.
- A suite test: the hotbar and crafting window projections mark an ability or recipe above the
  equipped weapon, held tool or station tier as unavailable and carry the tier needed.
- A suite test asserts the refusal and tier labels are keys in both `en` and `pt_BR`.

## Phase 230 — Characters across worlds

- Each host signs with the key and world id from Phase 228.
- While a portable character is in a world, the host sends it a signed **progress delta** for the
  skill XP gained there since the last delta: at every autosave and on a clean logout or host
  shutdown. A dropped connection cannot be sent to, so it loses at most one autosave interval. The
  client stores the deltas in `user://characters/<id>/`. The skill XP never comes from the client;
  it comes from the host's signature over the host's own count.
- **Import:** joining a world with policy `trusted` or `open`, the client presents the character's
  name, appearance and its deltas. Skill XP comes only from verified deltas, never from a
  client-held total. The host verifies every signature, refuses a delta whose player key is not the
  key that signed the join (Phase 228), keeps only issuers its policy accepts, skips deltas it signed
  itself (its own record already holds that XP), skips duplicates by (issuer, sequence) and adds the
  XP. It records the applied (issuer, sequence) pairs per player key in its save, so presenting the
  same deltas on the next join adds nothing. The character arrives with its name, appearance, skills
  and cosmetics, and with no items, research, books or memberships. A world with policy `local`
  ignores the import and offers a fresh character.
- **Going home:** the home world applies its own policy the same way, so XP earned at a friend's
  comes back only if home is `trusted` with that friend's host key (or `open`). A `local` home
  keeps only its own XP.
- **`open` trusts anyone who runs a host**, since anyone can make a host key and sign any count. It
  is never the default, the options window says so, and it is bounded like every import.
- The import is bounded: a maximum number of deltas, a maximum file size, a cap on XP per delta and
  on XP imported per key per day (both from the fabric), and a rate limit on imports per key.
- The policy is a host setting in the options window (Phase 225) and a `--import-policy` flag for a
  dedicated server. All text through `I18n.t()`.

**Acceptance criteria**
- A suite test: host A signs a delta, host B with policy `trusted` listing A imports it and finds
  the XP. With policy `local` the character starts fresh. With `trusted` not listing A, the delta is
  ignored.
- A suite test refuses a delta with a bad signature, a delta issued to another player key, a
  duplicate (issuer, sequence), XP over the per-delta or per-day cap, and an import over the size
  or count limit. None of them changes the record. Presenting an already applied delta set on a
  second join, or a delta the importing host signed itself, adds no XP.
- A suite test asserts an imported character has an empty inventory, no research and no clan.
- A net harness step: a client plays on host A, gains skill XP, leaves, joins host B (`trusted` with
  A) and has the XP, then goes back to A (`trusted` with B) and has the XP earned on B.

## Phase 231 — Cosmetics bound to the key

- A cosmetic is owned by a **grant** signed by an issuer key. The official shop's public key is
  pinned in the game (the suite pins a test issuer key in its place). A host may add its own issuer
  key for cosmetics earned in its world; those show in that world and in worlds whose import policy
  trusts that host, and an unknown issuer's grant is refused.
- On join the client presents its grants. The host verifies each signature and that the grant's
  owner key is the key that signed the join nonce (Phase 228). A grant held by another key is
  refused, so copying a friend's grant file does nothing.
- Cosmetics travel to every world whatever the import policy, because they have no economic effect.
  They are applied only to the owner's own characters.
- Trade, drop, chest, loot and gift paths refuse a cosmetic. It never becomes an inventory item.
- Cosmetic names and the refusal reasons are keys shown through `I18n.t()`.

**Acceptance criteria**
- A suite test: a grant signed by the pinned shop key for the joining key is accepted and the
  cosmetic shows on that player's character. The same grant presented by another key is refused, and
  so is a grant with a bad signature or an unknown issuer.
- A suite test: trading, dropping, storing in a chest and gifting a cosmetic are all refused by the
  host.
- A suite test asserts every cosmetic name and refusal key exists in both `en` and `pt_BR`.
- A net harness step: a client joins host B (policy `local`) and its cosmetics are present; a second
  client given a copy of the first's grant files has none.

## Phase 232 — Water that holds up: lake shores, the river seam and mounts at fords

Phase 217 put lakes and rivers on unrecorded land, and #589 fixed half of its review notes. The rest
are visible in play (a lake edge hanging as a wall of water, rivers jumping 512 m at the X seam,
water stopping dead at an older recorded chunk) or cost frame time (fresh water meshed on the main
thread for every chunk). Mounts still refuse any river, even a stream their own creature fords.

- **Lake shores:** `Hydrology.lake_of_cell` samples the ground with detail noise and massifs, not the
  shape alone, and the surface is clamped so no ground outside the disc lies below it. A lake whose
  rim cannot hold the surface is dropped.
- **River seam:** the river cell wrap period is an exact divisor of the circumference (or rivers are
  traced in seam-wrapped coordinates, `seam_wrap.gd`), so a river crossing the X seam continues on
  the other side.
- **Frontier:** a lake or river that reaches a recorded chunk of an older generator ends at a shore,
  not a cut: `frontier.gd` eases the water surface down to the recorded ground over `BLEND_CHUNKS`,
  as it already eases heights.
- **Spawn plain:** lake discs and river segments are excluded by their full extent, not their centre
  or vertices.
- **Build cost:** `voxel_build.build_chunk` skips fresh water when the chunk has no features, and
  builds the fresh-water surface on the worker thread with the rest of the chunk.
- **Mounts at fords:** `MountWiring._in_water` uses `CreaturePath.blocks_water(width,
  CreatureAI.FORD_WIDTH_M)`, so a ground mount carries its rider across a stream its creature would
  ford, and still refuses a wide river or a lake.
- Any change to world-gen output bumps `TerrainSlice.WORLDGEN_VERSION` with a history line and
  updates `_test_worldgen_golden`.

**Closes:** #573, #593

**Acceptance criteria**
- #573 (lake edge): a suite test samples the rim of 50 lakes on the pinned seed and finds no ground
  sample outside a disc below its surface.
- #573 (river seam): a suite test traces a river across the X seam and finds its two ends within one
  river width of each other.
- #573 (frontier): a suite test records an older-version chunk beside a lake and asserts the water
  surface meets the recorded ground with no vertical step over 0.5 m.
- #573 (spawn plain): a suite test asserts no lake disc or river segment overlaps the spawn plain on
  20 seeds.
- #573 (build cost): a suite test builds a chunk with no features and asserts no fresh-water node is
  made; the playtest `flight` step's worker and main-thread budgets still pass.
- #573: the items fixed by #589 (cache reset, record changes, crossing width, ice material) keep
  their tests; the issue's checklist is ticked in full.
- #593: a suite test calls the real `MountWiring._in_water` against a wired `CreatureSlice` (no
  stub): a stream narrower than `FORD_WIDTH_M` is not water, a wide river and a lake are.
- `WORLDGEN_VERSION` bumped and golden values updated if world-gen output changed; suite, both boot
  paths and `tools/net_harness.sh` green.

## Phase 233 — Flowing water: a bounded cellular automaton on edited chunks

Deferred since Phase 51, now possible because Phase 137 has a dirty-chunk pass for falling sand and
Phase 217 has fresh water. Today water is a static surface: a pit dug beside a lake stays dry and a
dam does nothing.

- **Fabric first** (separate PR): a `FluidFlow` table with the levels a cell can hold (8), the cells
  updated per tick per chunk, the flow budget per tick for the whole server, how far a source spreads
  over flat ground before it stops, and which materials water passes (none of the solids, sand
  falls through as in Phase 137).
- **Runtime:** water cells live only in chunks a player has edited near water. The static sea, lakes
  and rivers act as infinite sources at their surface; an edit that opens a hole in a shore, river
  bed or sea floor marks the chunk dirty and water flows in, down then sideways, level by level. A
  dam (a placed block) stops it; removing the dam starts it again. Untouched land never runs the
  automaton, so a fresh world costs nothing.
- **Authority:** the host runs the automaton on the server tick, deterministic per chunk (fixed
  update order, no floats in the cell state). Clients receive per-chunk water deltas through the
  existing chunk record sync, scoped to peers in range, and never compute flow themselves.
- **Persistence:** water cells are saved with the chunk's edits in the region store, so a flooded
  pit is still flooded after a restart. A chunk that settles (no change over a whole pass) leaves
  the dirty set.
- Swimming (`PlayerSlice._swimming_now`) and creature paths read the water cells as they read the
  static surface. Water cells are meshed with the fresh-water material (ice in a frozen chunk, where
  flow is off).

**Acceptance criteria**
- `npm run validate` and `check-drift` pass; a `tools/check_fluid.js` rejects a table with zero
  levels, a negative budget or an unknown material, and CI runs it.
- A suite test digs a channel from a lake into a dry pit and, after N host ticks, the pit holds water
  level with the lake; placing a block across the channel first leaves it dry.
- A suite test runs the same edits twice from the same seed and gets identical water cells
  (determinism), and asserts a world with no edits near water has an empty dirty set.
- A suite test asserts a settled chunk leaves the dirty set and that the tick's cell updates never
  exceed the fabric budget.
- A suite test saves a flooded chunk, reloads the region and finds the same water cells; a player
  in the flooded pit reports the swimming state.
- A net harness step: the host floods a pit and a client in range receives the water cells; a client
  out of range receives none.

## Phase 234 — Boats: crossing lakes, rivers and the sea

Deferred "Fast travel beyond waystones" names roads and boats. With lakes and rivers (Phase 217),
water is now the main obstacle on foot, and ground mounts (Phase 216) refuse it.

- **Fabric first** (separate PR): a raft (wood and fibre, carpentry, early tier) and a boat (planks
  and nails, later tier) as placeable vehicles, with speed on water, seats, durability, the water
  depth each needs, and their recipes and technologies. A `tools/check_*.js` proves the table rejects
  a vehicle with no seats or a speed under swimming speed.
- **Runtime:** a vehicle is a world entity placed on water deeper than its draft, owned by the
  player who placed it (structure ownership rules, Phase 205). Mounting reuses the mount flow
  (Phase 216): interact to board, the vehicle moves with the rider's input, dismount on shore. A
  second seat carries a passenger.
- **Authority:** the host moves the vehicle, rate-limits and validates input like a mount, refuses
  boarding from out of reach, and beaches it (stops it) on ground shallower than its draft. A
  client never reports the vehicle's position.
- **Persistence:** a placed vehicle and its durability are saved with the world; picking it up
  returns the item.
- Labels and refusal reasons (`boat_too_shallow`, `boat_full`, …) are `I18n.t()` keys in `en` and
  `pt_BR`.

**Acceptance criteria**
- `npm run validate` and `check-drift` pass; the new check is in CI.
- A suite test places a raft on a lake, boards it, drives it across and asserts it moves at the
  fabric speed and stops at the shore; placing it on dry land or in water shallower than its draft is
  refused.
- A suite test: a passenger boards the second seat and moves with the boat; a third player is
  refused with `boat_full`.
- A suite test saves and reloads a world with a placed boat and finds it at the same position with
  the same durability; picking it up returns the item.
- A suite test asserts every vehicle label and refusal key exists in both `en` and `pt_BR`.
- A net harness step: a client crafts and places a raft, boards and crosses a lake; the host's
  position for it matches the client's within one tick, and a forged position update is ignored.

## Phase 235 — Roads: built paths that speed travel on foot and on a mount

The other half of the deferred fast-travel item. A clan that wants its villages close builds roads
between them, which costs work instead of being free like a waystone.

- **Fabric first** (separate PR): road surfaces (packed dirt, gravel, stone paving, by tier) with a
  walking and mount speed multiplier each, their recipes, the skill they grow (Building) and the
  durability lost to traffic.
- **Runtime:** a road is laid with a tool on the ground's top voxel layer (a voxel edit with a road
  material, Phase 205 ownership and dismantling rules apply). `PlayerSlice.walking_speed` and the
  mount speed read the surface under the body; off road nothing changes. Weather's speed factor
  (Phase 128) still applies on top.
- **Authority:** the host computes the speed from its own voxel data. The client predicts with the
  same function but the host's position is authoritative; a client claiming road speed off road is
  corrected.
- Roads show on the minimap and the map (Phase 222) as lines.
- Road names and prompts are `I18n.t()` keys in `en` and `pt_BR`.

**Acceptance criteria**
- `npm run validate` and `check-drift` pass; a `tools/check_roads.js` rejects a multiplier below 1 or
  a road with no recipe, and CI runs it.
- A suite test lays a stone road and asserts walking speed on it is the fabric multiplier times
  `SPEED` and unchanged one voxel beside it; rain still slows the walk on the road.
- A suite test asserts a mount on a road moves at its speed times the road multiplier.
- A suite test asserts a road voxel survives save and reload and is drawn on the minimap.
- A net harness step: a client walks along a road and the host accepts the speed; a client sending
  road-speed movement off road is corrected by the host.

## Phase 236 — Changing hair style and colour: scissors and dye

Decided by the owner on 2026-11-06 (Deferred): not the creation screen, but a separate screen, open
only to a player who has crafted scissors (style) or dye (colour).

- **Fabric first** (separate PR): scissors (smithing, worn on use, durability) and dyes (alchemy,
  one per colour family, consumed on use), with their recipes, technologies and the hair styles and
  colours each unlocks. Styles and colours are the ones the creation screen already offers (Phase
  181); no new art.
- **Runtime:** a **Barber** window, opened from the Character window, shows the styles (needs
  scissors in the inventory) and colours (needs the matching dye). The client sends the choice; the
  host checks the item, wears the scissors or consumes the dye, updates the character's appearance
  and syncs it to peers in range. A choice without the item, or a style or colour not in the table,
  is refused.
- The doll in the Character window and the player's body in the world show the change at once.
- Labels and refusals (`needs_scissors`, `needs_dye`) are `I18n.t()` keys in `en` and `pt_BR`.

**Acceptance criteria**
- `npm run validate` and `check-drift` pass; a `tools/check_barber.js` rejects a dye whose colour is
  not a creation colour, and CI runs it.
- A suite test changes the hair style with scissors (durability drops by one) and the colour with a
  dye (one dye consumed), and asserts the appearance saved on the character is the new one.
- A suite test asserts the host refuses a style change without scissors, a colour change without the
  matching dye, and a style or colour id not in the table.
- A suite test asserts every Barber label and refusal key exists in both `en` and `pt_BR`.
- A net harness step: a client changes its hair colour and a second client sees the new colour on
  that body.

---

## Deferred (in priority order)

- **Fast travel beyond waystones** — a planet takes about 90 days to walk around. Phase 125 added
  waystones, Phase 216 mounts, and boats and roads are Phases 234–235. Ships for crossing oceans
  between continents remain.
- **Physics ragdolls** — Phase 157 animates deaths with a host-chosen landing spot and authored
  clips, so the headless server stays deterministic. A client-only ragdoll blend on top is later
  polish.
- **Localized fabric content** — entity names and descriptions (items, creatures, skills,
  technologies) translated through catalogs generated by Newel (`../newel/ROADMAP.md` Phase 15),
  consumed with the Phase 131 locale settings.
- **Public wiki deployment** — VitePress (or equivalent) static-site deployment and CI-triggered
  wiki regeneration from the fabric (deferred from Phase 9).
- **Voxel techniques from GDVoxelPlayground** — <https://github.com/JorisAR/GDVoxelPlayground>
  (MIT) was evaluated and not adopted wholesale: it ray-marches a fixed 128³ GPU grid, which does
  not fit an unbounded streamed world with a headless server. Worth borrowing later, CPU-side and
  deterministic: **WFC** for ruins, villages and dungeons, and a **brick occupancy map** if meshing
  becomes the bottleneck.
- **Raids** (dropped 2026-10-31, was Phase 200) — a warned, bounded creature attack on a village. Not wanted for now. Its spec is in git history (ROADMAP.md before PR #540).
- **Clan skills** — abilities (such as teleporting every member to one place) for the two or three members who contribute most to a clan. Contribution is to be defined, probably as a share of members' experience given to the clan. Clan tiers (Phase 210) give nothing until then.
- **Elder buildings** — buildings only a clan's top contributors can build. To be designed.
- **Settlement against settlement** — Phase 205 lets anyone destroy a structure they do not own. Organized sieges, wars and disputes between clans need governance and fairness rules first.
- **Real cross-region multiplayer run** — Phase 135 emulates WAN profiles in the harness. A run
  between real regions remains.
- **Automatic LOD mesh decimation** — simplified meshes are hand-authored (Phase 23).
- **Dynamic impostor re-bake** — impostor billboards are baked offline. A live re-bake on palette
  change is deferred from Phase 23.
- **Server sharding (last, not before maturity)** — split the authoritative simulation across
  servers by region once one headless server (Phase 27) with spatial hashing (Phase 28) and
  interest management (Phase 29) saturates. No structural change is needed before then. Revisit
  when Brazil-region load approaches one server's ceiling.
