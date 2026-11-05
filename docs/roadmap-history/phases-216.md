# Roadmap history — Phase 216

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 216 — Mounts: ride a tamed creature ✅ Done

**Goal:** the first fast travel beyond waystones (Deferred: "Fast travel beyond waystones"). A
player who has tamed a mountable creature can mount it, travel faster than on foot, and dismount.
Taming (`src/creature/taming_slice.gd`) already binds a creature to its tamer as a companion.

**Newel dependency:** NO.

**Deliverables:**
- Fabric: a `mount` field on creatures (speed factor, stamina or none, which terrain it can cross,
  rider offset), set on at least one existing tameable creature; a validator with
  `tools/check_mounts.js` proving it rejects bad tables (speed factor ≤ 1, mount on a non-tameable
  creature), and a CI step. Separate fabric PR, as the convention asks.
- Runtime: mount and dismount intents on `GameBus`, validated on the host (the creature is the
  player's own tamed companion, within reach, alive, not already ridden). While mounted the player's
  movement speed is the mount's factor times the walking speed, the companion follows the rider's
  exact position (Phase 171 `{chunk, local}`), and the host rejects movement faster than the mount
  allows. Damage to the mount or its death dismounts the rider; logging out dismounts and leaves the
  companion beside the player.
- A Mount/Dismount entry in the gesture or companion UI and a key binding, with `en` and `pt_BR`
  strings in `locale/ui.csv`.
- A `mount` step in `--playtest-bot`, after `travel`: tame, mount, ride 200 m, dismount.

**Acceptance criteria:**
- [x] `npm run validate` and `node tools/check_mounts.js` pass; the checker rejects each bad fixture.
- [x] Suite: mounting someone else's companion, a wild creature, a dead one or one out of reach is
  refused with a key; a valid mount succeeds and is synced to other peers.
- [x] Suite: a mounted player's accepted speed is the mount factor times walking speed, and a client
  reporting more is clamped by the host.
- [x] Suite: the mount's death and the rider's logout each dismount; no orphan nodes.
- [x] Harness: a client mounts on the host, the host broadcasts who rides what to every peer (the harness has one
  client, so that client sees the broadcast; a second observer is not a harness role), the rider dismounts.
- [x] Playtest: the `mount` step passes and its mounted cruising speed (the median of its 0.5 s legs that moved) is at least the fabric factor
  × walking speed × 0.9.
- [x] Suite green on both boot paths, harness green; locale key-parity test passes.

**Delivered:** one PR carried the fabric, runtime, UI and tests (the convention asks for a separate fabric PR; the
fabric commit is its own commit on the branch). Added `mount` to the tutorial's input actions so the controls row
stays in order.

