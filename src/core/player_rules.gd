extends RefCounted
## Shared rules about a player BODY — the two numbers more than one layer has to agree
## on. Same shape as `skill_tiers.gd`: a neutral module both sides preload, so neither
## has to reach into the other.
##
## `MAX_HP` and `RESPAWN_DELAY` were owned by `PlayerSlice` alone, and that was right while
## only the local body cared. It stopped being right in Phase 39: the host SIMULATES a
## remote peer's health through the persistence layer (`PlayerRegistry`, which floors a
## peer at nothing and parks a respawn deadline), and that floor and that delay have to be
## the same ones the peer's own client respawns to — "the host's floor for a PEER must not
## drift from the ceiling the peer's own client uses" (see `PlayerRegistry.RESPAWN_DELAY`).
## Reading them off `PlayerSlice` made the persistence layer preload a presentation slice
## for two constants: persistence importing presentation, in the wrong direction, for
## arithmetic. The names stay on `PlayerSlice` (aliased, below it) so every existing reader
## — the slice itself, the harness, the suite — is unchanged.
##
## Values are unchanged; this is a move, not a retune.

## The body's full-health ceiling: the value a respawn restores and the cap every hit
## clamps to.
const MAX_HP := 100.0

## How long a downed body waits before it comes back up. Wall-clock seconds, because the
## host's copy of the wait has to survive the peer's own process being gone (the deadline
## is parked on the durable record, not ticked in a frame loop).
const RESPAWN_DELAY := 5.0
