const authored = require('./authored')
const equipment = require('../equipment')

// Phase 295 — every equipment item gets its derived fields: what it can do (`works`), the damage it deals by type
// (`combatDamage`), and, until Phase 296 moves the runtime onto the work table, the old `toolType`, `harvestTool` and
// `efficiency` the runtime still reads (the bridge). None of these is authored.
const BRIDGE_DESC = {
  toolType:    'Derived (Phase 295 bridge, removed by Phase 296) from the work table: the old tool class the runtime reads',
  harvestTool: 'Derived (Phase 295 bridge, removed by Phase 296) from the work table: knife (dissect) or bonetool (cutBone)',
  efficiency:  'Derived (Phase 295 bridge, removed by Phase 296): the harvest work speed, in (0, 1]',
}

function withDerived(items) {
  const specs = equipment.itemSpecs(items)
  const d = equipment.equipmentData()
  const out = {}
  for (const [k, e] of Object.entries(items)) {
    const s = specs[k]
    if (!s.category || !d.categories[s.category]) { out[k] = e; continue }
    const fields = { ...e.fields }
    fields.works = { type: 'json', description: 'Derived from the work table (Phase 295): { <work>: speed } for every work this item can do', defaultValue: equipment.worksOf(s, d) }
    fields.combatDamage = { type: 'json', description: 'Derived (Phase 295): combat damage per damage type, the category multiplier times its traits\' shares', defaultValue: equipment.combatDamage(s, d) }
    const legacy = equipment.legacyToolFields(s, d)
    for (const [f, v] of Object.entries(legacy)) {
      fields[f] = { type: f === 'efficiency' ? 'decimal' : 'string', description: BRIDGE_DESC[f], defaultValue: v }
    }
    out[k] = { ...e, fields }
  }
  return out
}

module.exports = withDerived(authored)
