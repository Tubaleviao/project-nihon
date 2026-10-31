// Phase 203 — what a material is worth in a building, as ENTITY FIELDS beside its deposit fields. The
// structure rules (fabric/gameplay/structure.js) and Phases 205, 210 and 212 read them off the generated
// material resources.
//
//   rarity          the item rarity scale (common .. legendary); clan tiers weigh buildings by it (ClanTiers).
//   durability      a placed block's base durability; a rarer material never has less (validated).
//   structuralClass how many floors a structure carrying this material may have (Structure.classes).
//                   `hardness` mixes a Janka scale (woods) with a Mohs scale (stones, metals), so it
//                   cannot rank strength: the class is its own field.
const { RARITIES } = require('../../gameplay/items/shared')

// Ordered weakest first; maxFloors rises strictly and the last class reaches Structure.maxFloors.
const STRUCTURAL_CLASSES = ['earth', 'wood', 'stone', 'concrete', 'steel', 'composite']

function structuralFields({ rarity, durability, structuralClass, why }) {
  return {
    rarity: {
      type: 'enum',
      values: RARITIES,
      description: 'How rare the material is (the item rarity scale); clan tiers weigh buildings by it (Phase 203)',
      defaultValue: rarity,
    },
    durability: {
      type: 'integer',
      description: `Base durability of a placed block; weather, age and damage lower it (StructureDurability, Phase 203). ${why}`,
      defaultValue: durability,
    },
    structuralClass: {
      type: 'enum',
      values: STRUCTURAL_CLASSES,
      description: 'Structural class: the most floors a structure carrying this material may have (Structure.classes, Phase 203)',
      defaultValue: structuralClass,
    },
  }
}

module.exports = { STRUCTURAL_CLASSES, structuralFields }
