# Roadmap history — Phase 182

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 182 — Admin tools: /time, /speed, /fly, /heal, /regen world and an Admin window

**Goal:** an admin can change the time of day, a player's speed, flying and health, and regenerate
the world's terrain from a chat command or from an Admin window. The host checks and runs every
command, as Phase 85's admin commands do.

**Newel dependency:** NO. The commands are runtime tooling, not game design.

**Depends on:** Phase 85 (chat and admin commands), Phase 128 (`/weather`).

**Deliverables:**
- `/time <hh:mm | +hours>` moves the host clock forward (never backwards) and broadcasts it.
- `/speed <0.1–10> [player]` and `/fly [player]` set host-owned session moves, delivered to the
  player's client as an `admin_moves` packet. Flying has no gravity; Space climbs and Ctrl sinks.
- `/heal [player]` fills the bar of a live player: the host's own simulated HP for a peer, and an
  `admin_heal` packet to the peer's client. It does not revive a downed player.
- `identity_assigned` tells a client whether it is an admin. The Admin window (O, a dock box shown
  only to admins) types the same commands, so it adds no new authority.
- The host re-reads `admins.json` when it changes, and an `admin_status` packet tells each online
  player whose status flipped. Admin moves are session state: a rejoining player walks normally, on
  the host and on its own client. A carrier's speed cap follows its `/speed` and `/fly`.
- `/regen world` (second PR): wipe every chunk record, terrain edit, tree clear and ore depletion,
  both on disk and in memory. Keep players, inventories and stations. Tell every client to drop its
  copies and resend its scope. Re-place every player and station on the new ground.
- Every new string is in `locale/ui.csv` in `en` and `pt_BR`.

**Acceptance criteria:**
- [x] `admin_tests`: the parsers, refusal for non-admins, local and remote delivery (packets to the
  target's peer alone), heal not reviving, client routing and the strict admin flag, the hidden
  dock box, the window commands, and catalog keys in both languages.
- [x] Net harness step `admin_moves_synced`: the host's `/speed`, `/fly` and `/heal` reach the
  client's body, and the client is not told it is an admin.
- [x] `/regen world`: suite tests prove records, edits, clears and depletion are gone on the host
  and on disk (the old regions folder moved aside as a backup), and that stations keep their height
  above the new ground. The `world_regen_synced` harness step proves a client drops its copy.
- [x] Suite green on both boot paths.
