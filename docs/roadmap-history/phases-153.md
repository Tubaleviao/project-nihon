# Roadmap history — Phase 153

Completed phase, archived from [ROADMAP.md](../../ROADMAP.md). See the [index](README.md).

---

## Phase 153 — Items in the world: equipment, held tools and icons everywhere

**Goal:** even with item models on disk, the game never loads them. `CharacterSlice._attach_equipment`
always builds `_make_box(size, …)`, and a missing icon falls back to a text glyph. This phase draws
every worn and held item with its model, and every item slot with its icon, as Phase 143 did for
creatures.

**Newel dependency:** NO.

**Depends on:** Phase 152.

**Deliverables:**
- `AssetOverlay.item_model_key(id)` → `models/items/<ItemId>.glb.raw`. `CharacterSlice`
  loads it once per item type (cached like `CreatureVisuals._template`, off the main thread for the
  first load) and attaches it at the equipment socket by its `grip` node. RIGID, SKINNED and HYBRID
  modes keep today's socket rules. A missing or broken key keeps the box, with one warning per
  item.
- The equipment palette tint (Phase 22 `_equipment_base_index`, metal/emission channels) applies to
  the model's materials, so Primary/Secondary/Accent still work.
- Sheathed weapons hang from the hip socket using the model's long axis, not the box rotation hack.
- Remote avatars (peer equipment replication, Phase 47) show the same models.
- UI: inventory, hotbar, character window, craft/repair rows and trade windows all use
  `UiSlice.item_icon_key`. The text-glyph fallback stays only for an id with no icon key.
- Impostors and LOD (Phase 23): equipment beyond the model range stays a box or the impostor, so far
  avatars cost the same as today.
- The README GIFs are re-captured once items render (a human check, filed as an issue).

**Acceptance criteria:**
- [x] Suite: equipping each equippable item attaches a node built from its model (not a `BoxMesh`)
  at the slot's socket, and unequipping frees it.
- [x] Suite: an item with a missing model key attaches a box and warns once.
- [x] Suite: a peer's worn item renders as its model on another client (harness step
  `equipment_recorded` extended to assert the model node).
- [x] Suite: every UI surface that shows an item resolves a texture for each item in
  `GameData.ITEMS`. No glyph fallback is hit.
- [x] Suite: no item model nodes are built when `render_visuals` is false.
- [x] Playtest bot: the `craft` step screenshot shows the crafted tool in hand (the bot asserts the
  hand socket holds a model node), and no step reports a new hitch over 50 ms.
- [x] Suite green on both boot paths, harness green.

**Notes:** item models load synchronously on first use (cached per item type) rather than off the main thread;
craft/repair/market rows gained icons (the trade window lists no items). The playtest bot puts a sword in hand during `craft`
because no recipe yields an equippable item; the hitch count is reported, not asserted.
