# Roadmap history — Phase 256

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 256 — A binary wire format for the hot packets ✅ Done

Every packet is a JSON string carried by two RPCs (`_rpc_c2h`, `_rpc_h2c`), parsed with `_parse`
and capped at `MAX_CLIENT_PACKET_BYTES`. The stress report ranks `remote_player_state` first among
hot spots (+2.01 kbit/s per peer per bot, 611% of the 64 kbit/s per-peer budget at 200 bots) and
`snapshot_chunk` second (229%). Phase 250 measures the server's ceiling; with text encoding it would
measure the encoding. The guards at `_accept_c2h` (size cap, token bucket, dedup) stay in front of
whatever is parsed.

- A `PacketCodec` (`src/networking/packet_codec.gd`, native port optional later) with a fixed
  layout per hot type: a one-byte type tag, a `u16` seq, and for `remote_player_state` the peer id
  and position quantised to centimetres as three `i32` (the rebase origin is sent with the chunk
  window, not per packet); `snapshot_chunk` carries its index, count and the chunk's bytes as a
  `PackedByteArray` instead of a base-64 string. Every other type stays JSON until it earns a layout.
- The two RPCs take a `PackedByteArray`; the first byte says binary or JSON (`{`), so a peer that
  predates the codec is read correctly and refused with the usual version mismatch.
- The host rejects a binary packet whose length does not match its type's layout, with the same
  silent drop and rate-limited warning as an oversized one.
- The stress baseline (`docs/perf/crowd-baseline.md`, `StressRules.BASELINE_LARGEST`) is re-recorded
  after the change, and the hot-spot table in this file's Phase 250 is updated from it.

**Acceptance criteria**
- A suite test round-trips each binary type through the codec, including positions at ±1,000 km
  from the origin, and rejects a packet one byte short and one byte long.
- A suite test asserts a `remote_player_state` packet is at most 20 bytes on the wire.
- The net harness passes under `lan`, `wan_br` and `wan_bad`; the `wan_bad` run no longer mutes
  creature position deltas for bandwidth (or the harness records why it still must).
- The stress run's `down_kbps_per_peer` at 16 bots in `lan/cluster` falls by at least 3× against the
  baseline recorded before this phase, and no series' largest passing size falls.

**Status (2026-11-19, done):** `PacketCodec` (`src/networking/packet_codec.gd`) carries `remote_player_state`
(19 bytes), `snapshot_chunk` and the host's `player_states` batch (the type the relay actually sends since
Phase 163) in fixed layouts, with deflate over packets of 32 bytes or more that shrink; everything else stays
JSON. A batch entry keeps its chunk and height exact and quantises local x and z to 0.5 mm (a position that is
not normalised travels as JSON). `seq` is a u16 on the wire and the dedup reads its wrap. Measured at 16 bots in
`lan/cluster` (`STRESS_MAX=16 STRESS_PATTERNS=cluster`, 20 s, seed 1): `down_kbps_per_peer` p95 19.8 before, 6.3
after (3.1×). The `wan_bad` profile does not mute creature position deltas for bandwidth in this tree (nothing
in the slice does: its 256 kbit/s cap only delays packets), so there was nothing to unmute.
