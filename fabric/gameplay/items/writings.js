const { defineEntity, RARITIES, DURABILITY_STATES, itemStateMachine, itemShape } = require('./shared')
const { WRITING_ITEMS } = require('../writing')

// Phase 209 — a written book or blueprint is a pack item that names what it teaches (WRITING_ITEMS in
// gameplay/writing.js). It is written at the writing rule's station for its cost by a player who knows the
// content, and reading it teaches the reader and keeps it.
// Each writing gets its own rune so every icon is distinct: books are Duskfiber, blueprints Sand.
const SLAB = { Book: 'Duskfiber', Blueprint: 'Sand' }
const RUNE = {
  TechBasicSmithing: 'Ferrite', TechMasterForge: 'Veilsteel', TechBasicCarpentry: 'Thornwood', TechTextileWeaving: 'Grass',
  TechArcaneForging: 'Aethermite', TechAlchemy: 'Lumenfite', TechVoidMastery: 'Voidite',
  TechConcrete: 'Concrete', TechSteel: 'Steel', TechLeyframe: 'Leyframe',
  RecipeBed: 'Grass', RecipeChest: 'Ferrite', RecipeDoor: 'Thornwood', RecipeHearth: 'Ashite',
  palisade: 'Duskfiber', storehouse: 'Veilsteel', workshop: 'Aethermite', watchtower: 'Lumenfite',
}
const lookOf = (writing, teaches) => ({ slab: SLAB[writing], rune: RUNE[teaches] })
const KIND_TEXT = { technology: 'the technology', station: 'how to build the station of', project: 'the settlement project' }

const writingItem = (key, { writing, teaches, kind }) => { const look = lookOf(writing, teaches); return defineEntity({
  tags: ['item', 'writing'],
  description: `A ${writing.toLowerCase()} that teaches ${KIND_TEXT[kind]} ${teaches}. Reading it teaches it and keeps it, so it can be read again or lent.`,
  goal: 'Research shared by writing, never through a clan (ResearchSharedByWriting, Phase 209)',
  fields: {
    id:        { type: 'uuid', primaryKey: true },
    condition: { type: 'enum', values: DURABILITY_STATES },
    weight:    { type: 'decimal', description: `kg per ${writing.toLowerCase()}`, defaultValue: 0.5 },
    rarity:    { type: 'enum', values: RARITIES, defaultValue: 'uncommon' },
    stackable: { type: 'boolean', description: 'True; copies of one writing stack', defaultValue: true },
    writing:   { type: 'string', description: 'The writing rule it follows (GameData.WRITINGS)', defaultValue: writing },
    teaches:   { type: 'string', description: 'The technology, recipe or project key it teaches', defaultValue: teaches },
    teachesKind: { type: 'string', description: 'technology, station or project', defaultValue: kind },
    shape: itemShape({ archetype: 'tablet', parts: look }),
    durability: { type: 'integer', description: 'Binding integrity', defaultValue: 100 },
  },
  relations: Object.fromEntries([...new Set(Object.values(look))].map((m) => [m.toLowerCase(), { name: m.toLowerCase(), kind: 'hasOne', target: m }])),
  stateMachine: itemStateMachine(),
  behaviors: {
    degrade: {
      description: `A ${writing.toLowerCase()} does not wear while carried or read`,
      rules: ['Reading never consumes or wears it'],
      auth: { roles: ['maintainer'] },
    },
    repair: {
      description: `Re-bind a worn ${writing.toLowerCase()} at a carpentry bench`,
      rules: ['Requires a carpentry bench; no additional materials consumed'],
      auth: { roles: ['maintainer'] },
    },
  },
}) }

module.exports = Object.fromEntries(Object.entries(WRITING_ITEMS).map(([k, v]) => [k, writingItem(k, v)]))
