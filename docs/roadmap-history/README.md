# Roadmap history

Completed phases moved out of [ROADMAP.md](../../ROADMAP.md) to keep it short. Text is unchanged.

| Phases | File |
|---|---|
| 1–19 | [phases-01-19.md](phases-01-19.md) |
| 20–32 | [phases-20-32.md](phases-20-32.md) |
| 33–38 | [phases-33-38.md](phases-33-38.md) |
| 39–42 | [phases-39-42.md](phases-39-42.md) |
| 43–59 | [phases-43-59.md](phases-43-59.md) |
| 60–74 | [phases-60-74.md](phases-60-74.md) |
| 75–98 | [phases-75-98.md](phases-75-98.md) |
| 99–129 | [phases-99-129.md](phases-99-129.md) |
| 130–146 | [phases-130-145.md](phases-130-145.md) |
| 147 | [phases-147.md](phases-147.md) |
| 148 | [phases-148.md](phases-148.md) |
| 149 | [phases-149.md](phases-149.md) |
| 150 | [phases-150.md](phases-150.md) |
| 151 | [phases-151.md](phases-151.md) |
| 152 | [phases-152.md](phases-152.md) |
| 153 | [phases-153.md](phases-153.md) |
| 154 | [phases-154.md](phases-154.md) |
| 155 | [phases-155.md](phases-155.md) |
| 156 | [phases-156.md](phases-156.md) |
| 157 | [phases-157.md](phases-157.md) |
| 158 | [phases-158.md](phases-158.md) |
| 159 | [phases-159.md](phases-159.md) |
| 160 | [phases-160.md](phases-160.md) |
| 161 | [phases-161.md](phases-161.md) |
| 162 | [phases-162.md](phases-162.md) |
| 163 | [phases-163.md](phases-163.md) |
| 164 | [phases-164.md](phases-164.md) |
| 165 | [phases-165.md](phases-165.md) |
| 166 | [phases-166.md](phases-166.md) |
| 167 | [phases-167.md](phases-167.md) |
| 168 | [phases-168.md](phases-168.md) |
| 169 | [phases-169.md](phases-169.md) |
| 170 | [phases-170.md](phases-170.md) |
| 171 | [phases-171.md](phases-171.md) |
| 172 | [phases-172.md](phases-172.md) |
| 173 | [phases-173.md](phases-173.md) |
| 174 | [phases-174.md](phases-174.md) |
| 175 | [phases-175.md](phases-175.md) |
| 176 | [phases-176.md](phases-176.md) |
| 177 | [phases-177.md](phases-177.md) |
| 178 | [phases-178.md](phases-178.md) |
| 179 | [phases-179.md](phases-179.md) |
| 180 | [phases-180.md](phases-180.md) |
| 181 | [phases-181.md](phases-181.md) |
| 182 | [phases-182.md](phases-182.md) |
| 183 | [phases-183.md](phases-183.md) |
| 184 | [phases-184.md](phases-184.md) |
| 185 | [phases-185.md](phases-185.md) |
| 186 | [phases-186.md](phases-186.md) |
| 187 | [phases-187.md](phases-187.md) |
| 188 | [phases-188.md](phases-188.md) |
| 189 | [phases-189.md](phases-189.md) |
| 190 | [phases-190.md](phases-190.md) |
| 191 | [phases-191.md](phases-191.md) |
| 192 | [phases-192.md](phases-192.md) |
| 193 | [phases-193.md](phases-193.md) |
| 194 | [phases-194.md](phases-194.md) |
| 195 | [phases-195.md](phases-195.md) |
| 196 | [phases-196.md](phases-196.md) |
| 197 | [phases-197.md](phases-197.md) |
| 198 | [phases-198.md](phases-198.md) |
| 199 | [phases-199.md](phases-199.md) |
| 203 | [phases-203.md](phases-203.md) |
| 204 | [phases-204.md](phases-204.md) |
| 205 | [phases-205.md](phases-205.md) |

Phases with no section of their own were merged into another phase:

| Phase | Merged into |
|---|---|
| 102–104 | [Phase 101](phases-99-129.md#phase-101--chat-and-admin-commands-are-host-authoritative-exact-and-proven-on-the-wire--done) |
| 105 | [Phase 99](phases-99-129.md#phase-99--housekeeping-sweep-legacy-tiles-roadmapreadme-hygiene-and-review-leftovers--done) |
| 144 | Split into [Phase 166](phases-166.md)–[169](phases-169.md) |

## Arcs

The arc introductions that framed these phases in [ROADMAP.md](../../ROADMAP.md), moved here when the
arc closed. Text is unchanged.

### Arc: make it look and feel like an RPG (Phases 173–181, 183)

After 172 phases the engine is strong: a deterministic planet, host-authoritative multiplayer,
persistence, crafting, combat, taming and settlements. But it does not yet look or play like an
RPG. Items and windows show letters, the character has no attributes, and a player never creates a
character: they spawn as a handle. This arc pays down the follow-up debt and makes the frame
budget honest. Then it gives the game icons, attributes, a character sheet and character creation.

Phases: [173](phases-173.md), [174](phases-174.md), [175](phases-175.md), [176](phases-176.md),
[177](phases-177.md), [178](phases-178.md), [179](phases-179.md), [180](phases-180.md),
[181](phases-181.md), [183](phases-183.md).

### Out of arc: admin tools (Phase 182)

Requested during playtesting, and done ahead of the arc: an admin needs to set the weather, the
time of day, a player's speed and health, and to regenerate a world whose recorded terrain is out of
date (for example, a world recorded around the pre-worldgen-9 spawn pit).

Phase: [182](phases-182.md).

### Next, ahead of the arc: fast flight and worldgen fixes (Phases 187–191)

Found while flying with `/fly` and `/speed 10` (90 m/s): the ground fell behind the player, and a
regenerated world was snow almost everywhere. Like Phase 182, this runs ahead of the RPG arc: Phase
179 resumed after Phase 191. Phase 188 comes second because a worldgen bump is cheaper the fewer worlds
have recorded the old plateaus. Phases 189–191 then raise the admin speed cap on a slow machine.

Measured on seed 42 at 90 m/s with the native builder (probe in the Phase 187 PR): chunk builds ran
at low priority, so 11 builds sat in flight while three ran, and the chunk under the body was missing
for seconds at a time. Once builds keep up, the main thread is the next wall. Each attached chunk costs
9.3 ms of collision, 5–6.5 ms of dispatch and bookkeeping, 4.5–12 ms of creature spawns and 1.7 ms of
render mesh, at 27 chunks/s.

Phases: [187](phases-187.md), [188](phases-188.md), [189](phases-189.md), [190](phases-190.md),
[191](phases-191.md).

### Out of arc: creature bodies (Phase 192)

Found while playing: creatures walked through each other and through the player. Requested ahead of
the arc, like Phase 182.

Phase: [192](phases-192.md).

### Out of arc: a lighter collision ring (Phase 193)

Found on PR #524: the playtest walk step's median p95 process time reached 21.1 ms (limit 20) on a slow
runner. Profiled locally, the biggest cost in the walk was Jolt taking the collision trimeshes of the 16
chunks two rings out, which only the 60 m aim ray needed.

Phase: [193](phases-193.md).

### Arc: first steps (Phases 184–186)

A new player lands in the world with no guidance except instructions scattered through the UI
(tooltips that say "drag here", a map hint bar, chat and trade prompts). This arc gives them one
guided path for the first hour: move, gather, craft the first tools and stations, build a shelter
with a bed, and kill a first creature. The bed becomes their spawn point. Each tutorial step
appears once, never comes back after it is dismissed, and the whole tutorial can be switched off.
The scattered UI instructions are removed, so the tutorial is the one place that teaches.

Phases: [184](phases-184.md), [185](phases-185.md), [186](phases-186.md).
