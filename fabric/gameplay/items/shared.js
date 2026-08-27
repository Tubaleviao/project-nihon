const { defineEntity } = require('@newel/core')

const RARITIES = ['common', 'uncommon', 'rare', 'epic', 'legendary']
const DURABILITY_STATES = ['pristine', 'worn', 'damaged', 'broken']

function itemStateMachine() {
  return {
    field: 'condition',
    initial: 'pristine',
    states: {
      pristine: 'Freshly crafted or repaired; full stat effectiveness',
      worn:     'Showing use; minor stat penalties apply',
      damaged:  'Significantly degraded; notable stat penalties; repair strongly advised',
      broken:   { description: 'Unusable; must be repaired at a workshop before use', terminal: false },
    },
    transitions: [
      { from: 'pristine', to: 'worn',    trigger: 'degrade' },
      { from: 'worn',     to: 'damaged', trigger: 'degrade' },
      { from: 'damaged',  to: 'broken',  trigger: 'degrade' },
      { from: 'broken',   to: 'pristine', trigger: 'repair' },
      { from: 'damaged',  to: 'pristine', trigger: 'repair' },
      { from: 'worn',     to: 'pristine', trigger: 'repair' },
    ],
  }
}

function consumableStateMachine() {
  return {
    field: 'condition',
    initial: 'pristine',
    states: {
      pristine: 'Full potency or freshness; ready for use',
      worn:     'Reduced potency; still usable',
      damaged:  'Significantly degraded; use with caution',
      broken:   { description: 'Spoiled or fully depleted; cannot be used or repaired', terminal: true },
    },
    transitions: [
      { from: 'pristine', to: 'worn',    trigger: 'degrade' },
      { from: 'worn',     to: 'damaged', trigger: 'degrade' },
      { from: 'damaged',  to: 'broken',  trigger: 'degrade' },
    ],
  }
}

// Equipment-visual fields attached to equippable items (characters.md §6, §7,
// §10, §16, §17, §21, §35, §39). Separate from the item's inventory/economic
// fields — these describe how the item composes into a character's visual
// appearance. Non-equippable items (ingots, food, components) omit these.
function equipmentVisualFields({ slot, deformationMode, masks, hideRegions, attachments, minLodLevel, size, metalTone, emissionColor = 200, compatibleTags }) {
  return {
    equipmentSlot:   { type: 'string', description: 'Equipment slot — what is equipped (§6)', defaultValue: slot },
    deformationMode: { type: 'string', description: 'SKINNED | RIGID | HYBRID (§10)', defaultValue: deformationMode },
    masks:           { type: 'json', description: 'Color/mask regions present on the asset (§17)', defaultValue: masks },
    hideRegions:     { type: 'json', description: 'Body regions this item hides to prevent clipping (§16)', defaultValue: hideRegions },
    attachments:     { type: 'json', description: 'Attachment state → socket map (§7)', defaultValue: attachments },
    minLodLevel:     { type: 'integer', description: 'Coarsest LOD at which this part still renders (§35)', defaultValue: minLodLevel },
    size:            { type: 'json', description: 'Placeholder mesh extents [x, y, z]', defaultValue: size },
    metalTone:       { type: 'string', description: 'Metal tone for metal-mask regions (§21)', defaultValue: metalTone },
    emissionColor:   { type: 'integer', description: 'Palette index in the emission region (192–223) for emissive regions (§22)', defaultValue: emissionColor },
    compatibleTags:  { type: 'json', description: 'Semantic tags required to equip (§39)', defaultValue: compatibleTags },
  }
}

module.exports = { defineEntity, RARITIES, DURABILITY_STATES, itemStateMachine, consumableStateMachine, equipmentVisualFields }
