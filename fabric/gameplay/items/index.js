const authored = require('./authored')
const equipment = require('../equipment')

// Phase 295 — every equipment item gets its derived fields: what it can do (`works`, the runtime reads the work table
// through EquipmentRules) and the damage it deals by type (`combatDamage`). Neither is authored.
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
    out[k] = { ...e, fields }
  }
  return out
}

module.exports = withDerived(authored)
