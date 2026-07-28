const { defineEntity, RARITIES, itemStateMachine } = require('./shared')

module.exports = {

  // ─── FerritePick ──────────────────────────────────────────────────────────
  FerritePick: defineEntity({
    tags: ['item'],
    description:
      'Rough-hewn mining pick forged from ferrite ingots and a thornwood handle. ' +
      'The standard tool for extracting surface ore veins; wears quickly against hard rock.',
    goal: 'Entry-level mining tool; gates ore gathering for new players',
    fields: {
      id:        { type: 'uuid', primaryKey: true },
      condition: { type: 'enum', values: ['pristine', 'worn', 'damaged', 'broken'] },
      weight:    { type: 'decimal', description: 'kg; affects carry capacity' },
      rarity:    { type: 'enum', values: RARITIES },
      stackable: { type: 'boolean', description: 'Whether multiple instances stack in inventory' },
      durability: { type: 'integer', description: 'Remaining durability points before condition degrades' },
    },
    relations: {
      ferrite:   { name: 'ferrite',   kind: 'hasOne', target: 'Ferrite' },
      thornwood: { name: 'thornwood', kind: 'hasOne', target: 'Thornwood' },
    },
    stateMachine: itemStateMachine(),
    behaviors: {
      degrade: {
        description: 'Reduce durability after mining use; condition worsens when durability threshold crossed',
        rules: ['Each mining action consumes durability points scaled by rock hardness'],
        auth: { roles: ['maintainer'] },
      },
      repair: {
        description: 'Restore item to pristine condition at a forge using raw ferrite',
        rules: [
          'Requires a functional forge',
          'Repair costs one ferrite ingot per condition tier restored',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── VeilsteelPick ────────────────────────────────────────────────────────
  VeilsteelPick: defineEntity({
    tags: ['item'],
    description:
      'Heavy-duty pick smelted from veilsteel. Cuts through hardstone formations that shatter ferrite picks. ' +
      'Magic-resistant alloy resists aethermite corruption in ley-line veins.',
    goal: 'Mid-tier mining tool; required to extract deep-seam ores',
    fields: {
      id:        { type: 'uuid', primaryKey: true },
      condition: { type: 'enum', values: ['pristine', 'worn', 'damaged', 'broken'] },
      weight:    { type: 'decimal', description: 'kg; affects carry capacity' },
      rarity:    { type: 'enum', values: RARITIES },
      stackable: { type: 'boolean', description: 'Whether multiple instances stack in inventory' },
      durability: { type: 'integer', description: 'Remaining durability points before condition degrades' },
    },
    relations: {
      veilsteel:  { name: 'veilsteel',  kind: 'hasOne', target: 'Veilsteel' },
      thornwood:  { name: 'thornwood',  kind: 'hasOne', target: 'Thornwood' },
    },
    stateMachine: itemStateMachine(),
    behaviors: {
      degrade: {
        description: 'Reduce durability after mining use',
        rules: [
          'Veilsteel degrades at half the rate of ferrite tools against standard rock',
          'Against void-touched stone, degrades at standard rate',
        ],
        auth: { roles: ['maintainer'] },
      },
      repair: {
        description: 'Restore to pristine condition at a master forge using veilsteel ingots',
        rules: [
          'Requires Smithing: Journeyman',
          'Repair costs one veilsteel ingot per condition tier restored',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── CarpenterAxe ─────────────────────────────────────────────────────────
  CarpenterAxe: defineEntity({
    tags: ['item'],
    description:
      'Felling axe with a weighted ferrite head and a duskfiber-wrapped thornwood handle. ' +
      'Balanced for sustained chopping; also functions as a light combat weapon.',
    goal: 'Primary lumber-gathering tool; bridge between crafting and early combat',
    fields: {
      id:        { type: 'uuid', primaryKey: true },
      condition: { type: 'enum', values: ['pristine', 'worn', 'damaged', 'broken'] },
      weight:    { type: 'decimal', description: 'kg; affects carry capacity' },
      rarity:    { type: 'enum', values: RARITIES },
      stackable: { type: 'boolean', description: 'Whether multiple instances stack in inventory' },
      durability: { type: 'integer', description: 'Remaining durability points before condition degrades' },
    },
    relations: {
      ferrite:   { name: 'ferrite',   kind: 'hasOne', target: 'Ferrite' },
      thornwood: { name: 'thornwood', kind: 'hasOne', target: 'Thornwood' },
      duskfiber: { name: 'duskfiber', kind: 'hasOne', target: 'Duskfiber' },
    },
    stateMachine: itemStateMachine(),
    behaviors: {
      degrade: {
        description: 'Reduce durability after chopping use',
        rules: ['Hardwood species (Duskfiber trees) degrade the axe faster than softwood'],
        auth: { roles: ['maintainer'] },
      },
      repair: {
        description: 'Restore to pristine condition at a forge',
        rules: ['Repair costs one ferrite ingot; handle wrap (duskfiber) does not require replacement'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

}
