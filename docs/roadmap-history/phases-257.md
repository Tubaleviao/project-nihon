## Phase 257 — Split files named by what they do

Phase 154's 1,500-line cap is met: seven files sit at 1,497–1,500 lines and nine are named by
number (`net_part_1.gd`, `net_part_2.gd`, `net_part_3.gd`, `ui_part_1.gd`, `ui_part_2.gd`,
`chunk_part_1.gd`, `character_part_1.gd`, `character_part_2.gd`, `character_part_3.gd`; 4,038
lines). The split satisfies the cap's letter: a reader must know which part holds a function, which
is harder than one long file. The cap stays; the parts get names.

- Each `*_part_N.gd` is renamed for its responsibility (for example `net_part_2.gd` →
  `net_player_state.gd` if that is what it holds) and its header comment says what belongs there and
  what does not. Functions that landed in a part only because the slice was full move to the file
  whose name fits.
- The suite's source audit (`MAX_SOURCE_LINES`) also refuses any `.gd` whose name matches
  `_part_\d+` or ends in a digit, and refuses a file within 50 lines of the cap unless its header
  names the split that is planned for it.
- `CLAUDE.md`'s architecture section names the new files where it names the slices.

**Acceptance criteria**
- No file under `src/` matches `_part_\d+\.gd`; the audit test proves it rejects a fixture that
  does.
- The suite, the net harness and the playtest bot pass unchanged (a rename is behaviour-free).
- `grep -c` of the old names in `src/`, `tools/`, `docs/` and `CLAUDE.md` is 0.
