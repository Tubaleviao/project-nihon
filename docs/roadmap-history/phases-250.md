# Roadmap history — Phase 250

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 250 — The server's ceiling: one machine serving, another running the bots ✅ Done

The crowd numbers in the README (Phase 163) come from one desktop machine running the server, the
watching client and every bot at once, so the bots steal the server's CPU and the link is loopback.
How many players one dedicated server holds is unknown.

- `tools/stress.sh` gains a split mode: `STRESS_ROLE=server` boots only the dedicated server and the
  host recorder and waits for bots; `STRESS_ROLE=bots STRESS_SERVER=<addr>` runs the watcher and the
  bot process against a remote server. The "steady" and "stop" handshake goes over the network
  (a control message or a small TCP side channel) instead of shared files.
- Run the ladder (every pattern, crowd sizes up past the first failure) with the server on one
  machine and the bots on another over a real LAN, then over the `wan_br` profile.
- The report records each machine (CPU, cores, RAM, OS, Godot build, native on or off, release or
  debug), and per pattern: the largest crowd that met every budget, tick time, CPU and memory per
  player, bandwidth per player up and down, and the first bottleneck.
- Write `docs/perf/server-ceiling.md`: the measured limits, the machines, the command to repeat it,
  and how many players one server can hold with headroom for play. The README's crowd line points
  to it.

**Acceptance criteria**
- A suite test on the split-mode parsing: a bots role with no server address is refused, and the
  control messages round-trip.
- A loopback CI run of the split mode (both roles on one runner) reaches "steady", runs one small
  pattern and writes a report with the machine fields filled.
- `docs/perf/server-ceiling.md` exists with numbers from a two-machine run. The run itself needs two
  machines, so if none are available to automation it is filed as a GitHub issue (per the rule at
  the top of this file) and the document records the loopback numbers until the issue is closed.

**Delivered**
- `tools/stress.sh` split mode (`STRESS_ROLE`, `STRESS_SERVER`, `STRESS_CTL_PORT`, and `STRESS_LOOPBACK_SPLIT=1` for both roles on one machine); the "steady" and "stop" handshake and the host and watcher reports cross a TCP side channel (`tools/stress_ctl.py`, grammar in `StressRules.control_encode` / `control_decode`).
- The report has a Machines table (CPU, cores, RAM, OS, Godot build, native on or off, release or debug) for each role.
- `docs/perf/server-ceiling.md` records the loopback numbers; the two-machine run is [issue #685](https://github.com/Tubaleviao/project-nihon/issues/685), per the rule at the top of the roadmap.
