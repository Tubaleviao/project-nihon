## Phase 268 — Stations are made, carried and placed from the hotbar

B cycles a station type, N toggles a ghost and V places it, so every station is available from the
start. Only the types with a fabric placement item cost anything (the waystone since Phase 130, the
bed, chest and door, the settlement hearth); forges and benches are free (`station_slice.gd`
`placement_item`).

- **Fabric (separate PR):** every placeable station type names a `placementItem` tagged `station`,
  and each item has a recipe. The first station (the carpentry bench) is hand-made from what the
  newcomer grounds give; later ones (forge, masonry bench, alchemy bench, arcane forge…) need an
  earlier station, as their recipes say. The rule `ChestsAndDoors` checks for chests and doors (a
  placement item must be tagged `station`) extends to every placeable type.
- **No shortcuts:** the B, N and V station handlers in `player_slice.gd` (`_cycle_station_type`,
  the preview toggle, `_place_station`) and their input labels are removed. V stays the proposals
  window shortcut. Host-side placement for NPC villages (`settlement_wiring.gd`) keeps its own path.
- **Hotbar placement:** a station item in the selected hotbar slot shows its ghost at the aimed spot
  every frame, tinted by `place_refusal` (valid or refused, with the refusal's reason as a hint), and
  the use input places it. The host consumes one item and refuses without it, as now. A rotate input
  (the build material's R is reused while a station item is selected) turns the ghost in 90° steps,
  and the rotation travels with the request.
- **Picking up again:** a new host-checked intent lets a station's owner, within reach, pick up a
  placed station and get its item back (there is no player path today: `remove_station` is host-only;
  Phase 213's dismantle covers structure blocks). A chest keeps its `spillsOnDestroy` rule.
- The tutorial's `first_stations` chapter names crafting the station item before placing it.

**Acceptance criteria**
- `npm run validate` and `check-drift` pass; a `check_*.js` rejects a placeable station type with no
  placement item, and a placement item with no recipe.
- Suite tests: B, N and V no longer place or cycle stations; with no station item selected no ghost is
  shown; with one selected, the ghost follows the aim and reports the same refusal as the host; the use
  input emits one placement request with the rotation; the host refuses a placement whose item is not
  in the bag, and consumes it on success.
- Net harness step: a client crafts a station item, selects it, places it, and the second client sees
  the station; a placement request without the item is refused.
- Suite test: the owner picks up a placed station and gets its item back; another player, or the owner
  out of reach, is refused.
- The playtest `place` step places from the hotbar.
