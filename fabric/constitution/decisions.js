const { defineEntity } = require('@newel/core')

// Phase 203 — the owner's decisions of 2026-10-31 share one shape: accepted, with the rule tables they bind as relations.
const ownerDecision = (description, goal, relations) => defineEntity({
  tags: ['decision'],
  description,
  goal,
  fields: {
    id:      { type: 'uuid', primaryKey: true },
    status:  { type: 'enum', values: ['proposed', 'accepted', 'superseded'], defaultValue: 'accepted' },
    decided: { type: 'string', description: 'The day the owner decided it', defaultValue: '2026-10-31' },
  },
  relations,
  stateMachine: {
    field: 'status',
    initial: 'accepted',
    states: {
      proposed:   'Decision is under community discussion',
      accepted:   'Decision is ratified and in effect',
      superseded: { description: 'Decision has been replaced by a newer decision', terminal: true },
    },
    transitions: [
      { from: 'proposed',              to: 'accepted',   trigger: 'accept' },
      { from: ['proposed', 'accepted'], to: 'superseded', trigger: 'supersede' },
    ],
  },
  behaviors: {
    accept: {
      description: 'Ratify this decision',
      rules: ['Decided by the project owner'],
      auth: { roles: ['maintainer'] },
    },
    supersede: {
      description: 'Mark this decision as replaced by a newer one',
      rules: ['A replacement decision must be accepted first'],
      auth: { roles: ['maintainer'] },
    },
  },
})

module.exports = {
  GodotEngine: defineEntity({
    tags: ['decision'],
    description: 'Use Godot 4.x as the game client engine. Chosen for its open-source license, GDScript ergonomics, and strong 3D/networking support.',
    goal: 'Lock in the client technology so all rendering, physics, and scripting work targets a single platform',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      status: { type: 'enum', values: ['proposed', 'accepted', 'superseded'] },
    },
    stateMachine: {
      field: 'status',
      initial: 'proposed',
      states: {
        proposed:   'Decision is under community discussion',
        accepted:   'Decision is ratified and in effect',
        superseded: { description: 'Decision has been replaced by a newer decision', terminal: true },
      },
      transitions: [
        { from: 'proposed',              to: 'accepted',   trigger: 'accept' },
        { from: ['proposed', 'accepted'], to: 'superseded', trigger: 'supersede' },
      ],
    },
    behaviors: {
      accept: {
        description: 'Ratify this decision after community review',
        rules: ['Community vote must reach quorum'],
        auth: { roles: ['maintainer'] },
      },
      supersede: {
        description: 'Mark this decision as replaced by a newer one',
        rules: ['A replacement decision must be accepted first'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  OnePersistentWorld: defineEntity({
    tags: ['decision'],
    description: 'A single persistent official world server. All players on the official server share one continuous world; no shards.',
    goal: 'Ensure the social fabric of a shared world rather than isolated parallel instances',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      status: { type: 'enum', values: ['proposed', 'accepted', 'superseded'] },
    },
    stateMachine: {
      field: 'status',
      initial: 'proposed',
      states: {
        proposed:   'Decision is under community discussion',
        accepted:   'Decision is ratified and in effect',
        superseded: { description: 'Decision has been replaced by a newer decision', terminal: true },
      },
      transitions: [
        { from: 'proposed',              to: 'accepted',   trigger: 'accept' },
        { from: ['proposed', 'accepted'], to: 'superseded', trigger: 'supersede' },
      ],
    },
    behaviors: {
      accept: {
        description: 'Ratify this decision after community review',
        rules: ['Community vote must reach quorum'],
        auth: { roles: ['maintainer'] },
      },
      supersede: {
        description: 'Mark this decision as replaced by a newer one',
        rules: ['A replacement decision must be accepted first'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  OfflinePlayerNpcs: defineEntity({
    tags: ['decision'],
    description: 'Offline players may be represented in the world as configurable service NPCs, keeping shops and services running in their absence.',
    goal: 'Sustain a living world even when individual players are offline',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      status: { type: 'enum', values: ['proposed', 'accepted', 'superseded'] },
    },
    stateMachine: {
      field: 'status',
      initial: 'proposed',
      states: {
        proposed:   'Decision is under community discussion',
        accepted:   'Decision is ratified and in effect',
        superseded: { description: 'Decision has been replaced by a newer decision', terminal: true },
      },
      transitions: [
        { from: 'proposed',              to: 'accepted',   trigger: 'accept' },
        { from: ['proposed', 'accepted'], to: 'superseded', trigger: 'supersede' },
      ],
    },
    behaviors: {
      accept: {
        description: 'Ratify this decision after community review',
        rules: ['Community vote must reach quorum'],
        auth: { roles: ['maintainer'] },
      },
      supersede: {
        description: 'Mark this decision as replaced by a newer one',
        rules: ['A replacement decision must be accepted first'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  NoTeleportation: defineEntity({
    tags: ['decision'],
    description: 'No teleportation; infrastructure replaces fast travel. Players build roads, trains, and airships to enable movement between regions.',
    goal: 'Make geography and logistics meaningful — travel cost drives player economy and politics',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      status: { type: 'enum', values: ['proposed', 'accepted', 'superseded'] },
    },
    stateMachine: {
      field: 'status',
      initial: 'proposed',
      states: {
        proposed:   'Decision is under community discussion',
        accepted:   'Decision is ratified and in effect',
        superseded: { description: 'Decision has been replaced by a newer decision', terminal: true },
      },
      transitions: [
        { from: 'proposed',              to: 'accepted',   trigger: 'accept' },
        { from: ['proposed', 'accepted'], to: 'superseded', trigger: 'supersede' },
      ],
    },
    behaviors: {
      accept: {
        description: 'Ratify this decision after community review',
        rules: ['Community vote must reach quorum'],
        auth: { roles: ['maintainer'] },
      },
      supersede: {
        description: 'Mark this decision as replaced by a newer one',
        rules: ['A replacement decision must be accepted first'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  WaystonesAmendNoTeleportation: defineEntity({
    tags: ['decision'],
    description: 'Amends NoTeleportation: waystones are the one sanctioned fast travel. A player must build and stock a waystone network, travel only between stones they are attuned to, and pay an item cost scaled by distance, so travel remains infrastructure and a cost, never free or arbitrary teleportation. Placement policy for stations: a station whose fabric rule names a placement item (the waystone and the settlement hearth) consumes one from the placer on the host, so the network is built from crafted stones and cannot be spawned for free; workshop stations (forge, benches) are gated by skill and technology rather than an item and stay free to place.',
    goal: 'Keep a planet that takes about 90 days to walk around navigable without making geography meaningless',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      status: { type: 'enum', values: ['proposed', 'accepted', 'superseded'] },
    },
    stateMachine: {
      field: 'status',
      initial: 'proposed',
      states: {
        proposed:   'Decision is under community discussion',
        accepted:   'Decision is ratified and in effect',
        superseded: { description: 'Decision has been replaced by a newer decision', terminal: true },
      },
      transitions: [
        { from: 'proposed',              to: 'accepted',   trigger: 'accept' },
        { from: ['proposed', 'accepted'], to: 'superseded', trigger: 'supersede' },
      ],
    },
    behaviors: {
      accept: {
        description: 'Ratify this amendment after community review',
        rules: ['Community vote must reach quorum', 'Stones consume the Waystone item to place and an item cost to travel (WaystoneTravel)'],
        auth: { roles: ['maintainer'] },
      },
      supersede: {
        description: 'Mark this decision as replaced by a newer one',
        rules: ['A replacement decision must be accepted first'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  SettlementClaimAndDecay: defineEntity({
    tags: ['decision'],
    description: 'Settlements claim land around a Hearth, with a radius that only grows with tier. A claim never covers another settlement\'s land (hearths are at least minSeparation apart), and an abandoned settlement\'s claim decays until the land is free. Claim and role rules change only through GovernanceSystem proposals. Superseded 2026-10-31 by ClansAndOwnedStructures: there is no claim area (Phase 203).',
    goal: 'Let players hold land together without letting an inactive claim lock the world forever (TheWorldIsPersistent, CivilizationIsPlayerMade)',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      status: { type: 'enum', values: ['proposed', 'accepted', 'superseded'], defaultValue: 'superseded' },
    },
    relations: {
      settlement: { name: 'settlement', kind: 'hasOne', target: 'Settlement' },
    },
    stateMachine: {
      field: 'status',
      initial: 'proposed',
      states: {
        proposed:   'Decision is under community discussion',
        accepted:   'Decision is ratified and in effect',
        superseded: { description: 'Decision has been replaced by a newer decision', terminal: true },
      },
      transitions: [
        { from: 'proposed',              to: 'accepted',   trigger: 'accept' },
        { from: ['proposed', 'accepted'], to: 'superseded', trigger: 'supersede' },
      ],
    },
    behaviors: {
      accept: {
        description: 'Ratify the claim and decay rules after community review',
        rules: ['Community vote must reach quorum', 'Claim radius, decay and separation values live in Settlement rules'],
        auth: { roles: ['maintainer'] },
      },
      supersede: {
        description: 'Mark this decision as replaced by a newer one',
        rules: ['A replacement decision must be accepted first'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  SettlementRaidsAndUpkeep: defineEntity({
    tags: ['decision'],
    description: 'Superseded 2026-10-31 by SkillsGrowFromWork: raids are deferred and upkeep is removed (Phase 203). It read: raids on a settlement are fair: every raid is warned (SettlementRaids.warningSeconds > 0), none starts unless a member is online inside the claim (offlineProtection), and a lost raid takes at most a capped share of the stockpile and of unfinished project labour, never the claim or finished structures. Raids come from creatures only. Upkeep is a per-tier cost from the stockpile that never falls as the tier rises; unpaid upkeep suspends project effects and never shrinks the claim, which follows only the activity-based abandonment rule (SettlementClaimAndDecay).',
    goal: 'Give a village something to defend and to keep paying for without punishing players for logging off (TheWorldIsPersistent, EverythingHasTradeoffs, Phase 197)',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      status: { type: 'enum', values: ['proposed', 'accepted', 'superseded'], defaultValue: 'superseded' },
    },
    relations: {
      replacedBy: { name: 'replacedBy', kind: 'hasOne', target: 'SkillsGrowFromWork' },
    },
    stateMachine: {
      field: 'status',
      initial: 'proposed',
      states: {
        proposed:   'Decision is under community discussion',
        accepted:   'Decision is ratified and in effect',
        superseded: { description: 'Decision has been replaced by a newer decision', terminal: true },
      },
      transitions: [
        { from: 'proposed',              to: 'accepted',   trigger: 'accept' },
        { from: ['proposed', 'accepted'], to: 'superseded', trigger: 'supersede' },
      ],
    },
    behaviors: {
      accept: {
        description: 'Ratify the raid fairness and upkeep rules after community review',
        rules: ['Community vote must reach quorum', 'Warning, offline protection, loss caps and upkeep costs live in the SettlementRaids and SettlementUpkeep rules'],
        auth: { roles: ['maintainer'] },
      },
      supersede: {
        description: 'Mark this decision as replaced by a newer one',
        rules: ['A replacement decision must be accepted first'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  MagicBalancedWithMartial: defineEntity({
    tags: ['decision'],
    description: 'Magic and martial combat are balanced — no archetype dominates; each has unique trade-offs and counters.',
    goal: 'Ensure combat diversity and prevent a single dominant play-style',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      status: { type: 'enum', values: ['proposed', 'accepted', 'superseded'] },
    },
    stateMachine: {
      field: 'status',
      initial: 'proposed',
      states: {
        proposed:   'Decision is under community discussion',
        accepted:   'Decision is ratified and in effect',
        superseded: { description: 'Decision has been replaced by a newer decision', terminal: true },
      },
      transitions: [
        { from: 'proposed',              to: 'accepted',   trigger: 'accept' },
        { from: ['proposed', 'accepted'], to: 'superseded', trigger: 'supersede' },
      ],
    },
    behaviors: {
      accept: {
        description: 'Ratify this decision after community review',
        rules: ['Community vote must reach quorum'],
        auth: { roles: ['maintainer'] },
      },
      supersede: {
        description: 'Mark this decision as replaced by a newer one',
        rules: ['A replacement decision must be accepted first'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  DestructibleBuildings: defineEntity({
    tags: ['decision'],
    description: 'Buildings are destructible through game systems (fire, siege, structural failure) — not by arbitrary designer flags.',
    goal: 'Make construction meaningful with real risk, driving defensive design and political consequences',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      status: { type: 'enum', values: ['proposed', 'accepted', 'superseded'] },
    },
    stateMachine: {
      field: 'status',
      initial: 'proposed',
      states: {
        proposed:   'Decision is under community discussion',
        accepted:   'Decision is ratified and in effect',
        superseded: { description: 'Decision has been replaced by a newer decision', terminal: true },
      },
      transitions: [
        { from: 'proposed',              to: 'accepted',   trigger: 'accept' },
        { from: ['proposed', 'accepted'], to: 'superseded', trigger: 'supersede' },
      ],
    },
    behaviors: {
      accept: {
        description: 'Ratify this decision after community review',
        rules: ['Community vote must reach quorum'],
        auth: { roles: ['maintainer'] },
      },
      supersede: {
        description: 'Mark this decision as replaced by a newer one',
        rules: ['A replacement decision must be accepted first'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  KnowledgeByExperimentation: defineEntity({
    tags: ['decision'],
    description: 'Knowledge is discovered through experimentation — recipes, materials, and world secrets are not handed to players via tooltips or vendors.',
    goal: 'Make the act of discovery a core progression mechanic, not a reward after grinding',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      status: { type: 'enum', values: ['proposed', 'accepted', 'superseded'] },
    },
    stateMachine: {
      field: 'status',
      initial: 'proposed',
      states: {
        proposed:   'Decision is under community discussion',
        accepted:   'Decision is ratified and in effect',
        superseded: { description: 'Decision has been replaced by a newer decision', terminal: true },
      },
      transitions: [
        { from: 'proposed',              to: 'accepted',   trigger: 'accept' },
        { from: ['proposed', 'accepted'], to: 'superseded', trigger: 'supersede' },
      ],
    },
    behaviors: {
      accept: {
        description: 'Ratify this decision after community review',
        rules: ['Community vote must reach quorum'],
        auth: { roles: ['maintainer'] },
      },
      supersede: {
        description: 'Mark this decision as replaced by a newer one',
        rules: ['A replacement decision must be accepted first'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  PlayerIdentityModel: defineEntity({
    tags: ['decision'],
    description: 'A player identity is a server-issued local UUID (player_id), not an account. The server mints the id on first join, persists it next to the player record, and sends it to the client so a reconnect re-binds to the same record. The client may present a cached id at join, and the server honours it only when it already owns that record and no live peer holds it — a client can therefore never claim another online player\'s record.',
    goal: 'Give every player a connection-independent identity so inventory, HP, position, and appearance survive a reconnect or a server restart, without waiting for an account/auth service',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      status: { type: 'enum', values: ['proposed', 'accepted', 'superseded'] },
    },
    stateMachine: {
      field: 'status',
      initial: 'proposed',
      states: {
        proposed:   'Decision is under community discussion',
        accepted:   'Decision is ratified and in effect',
        superseded: { description: 'Decision has been replaced by a newer decision', terminal: true },
      },
      transitions: [
        { from: 'proposed',              to: 'accepted',   trigger: 'accept' },
        { from: ['proposed', 'accepted'], to: 'superseded', trigger: 'supersede' },
      ],
    },
    behaviors: {
      accept: {
        description: 'Ratify this decision after community review',
        rules: ['Community vote must reach quorum'],
        auth: { roles: ['maintainer'] },
      },
      supersede: {
        description: 'Mark this decision as replaced by a newer one',
        rules: ['A replacement decision must be accepted first'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  FictionalMaterials: defineEntity({
    tags: ['decision'],
    description: 'Fictional materials with unique properties replace real-world counterparts, giving the world consistent internal lore and design freedom.',
    goal: 'Decouple material design from real-world constraints while maintaining internal balance logic',
    fields: {
      id:     { type: 'uuid', primaryKey: true },
      status: { type: 'enum', values: ['proposed', 'accepted', 'superseded'] },
    },
    stateMachine: {
      field: 'status',
      initial: 'proposed',
      states: {
        proposed:   'Decision is under community discussion',
        accepted:   'Decision is ratified and in effect',
        superseded: { description: 'Decision has been replaced by a newer decision', terminal: true },
      },
      transitions: [
        { from: 'proposed',              to: 'accepted',   trigger: 'accept' },
        { from: ['proposed', 'accepted'], to: 'superseded', trigger: 'supersede' },
      ],
    },
    behaviors: {
      accept: {
        description: 'Ratify this decision after community review',
        rules: ['Community vote must reach quorum'],
        auth: { roles: ['maintainer'] },
      },
      supersede: {
        description: 'Mark this decision as replaced by a newer one',
        rules: ['A replacement decision must be accepted first'],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

  // ─── Phase 203 — the owner's decisions of 2026-10-31 (clans, owned buildings, Earth-scale heights) ─────
  ClansAndOwnedStructures: ownerDecision(
    'A player founds a clan by choosing its name and invites other players; a clan has any number of members, a ' +
    'player belongs to at most one, and every member sees every other member\'s skills. A clan has no hearth: its ' +
    'settlements are simply where its buildings stand. Whatever a player builds is assigned to their clan or kept ' +
    'private, and only its owner edits it, wherever it stands. A member\'s private house inside their clan\'s ' +
    'circles stays theirs to edit, but any member of that clan may enter or dismantle it. Owners of touching ' +
    'buildings keep their own blocks. There is no claim area: around each building a circle, larger for a larger ' +
    'building, where no creature spawns and where only that clan\'s members may build. Saved settlements become ' +
    'clans with the same name, members and roles.',
    'Let players hold what they build without a land claim locking the world (CivilizationIsPlayerMade, FreedomComesFirst, Phase 203)',
    {
      clan:      { name: 'clan',      kind: 'hasOne', target: 'Clan' },
      structure: { name: 'structure', kind: 'hasOne', target: 'Structure' },
      replaces:  { name: 'replaces',  kind: 'hasOne', target: 'SettlementClaimAndDecay' },
    },
  ),

  DurabilityAndDestruction: ownerDecision(
    'Every material has a durability, higher for rarer materials, that falls with weather, time and damage. Anyone ' +
    'may destroy a building, but only with effort that depends on its durability and the method, and very slowly ' +
    'while every owner is offline. A destroyer gets nothing from a building, but a destroyed chest spills its ' +
    'contents to anyone. A building stays its owner\'s until it is dismantled or destroyed. Dismantling returns ' +
    'materials by durability and building skill: all of them at full durability with a very high skill, half at ' +
    'full durability with no skill, less as durability falls. The owner repairs with part of the build materials. ' +
    'Any player may kill their own character to respawn, so no one can be trapped inside another\'s building.',
    'Make building meaningful with real risk, without letting a griefer take a house in one evening (DestructibleBuildings, TheWorldIsPersistent, Phase 203)',
    {
      durability: { name: 'durability', kind: 'hasOne', target: 'StructureDurability' },
      respawn:    { name: 'respawn',    kind: 'hasOne', target: 'SelfRespawn' },
      chests:     { name: 'chests',     kind: 'hasOne', target: 'ChestsAndDoors' },
    },
  ),

  ResearchSharedByWriting: ownerDecision(
    'Research is per player and is shared only by writing: a Book teaches one researched technology and a Blueprint ' +
    'one structure or station recipe. Only a player who knows the content can write one, at a material cost, and ' +
    'reading never consumes it, so it can be read again and lent. Research never draws from a shared stockpile.',
    'Keep knowledge a personal achievement that players trade and teach (KnowledgeIsProgression, Phase 203)',
    {
      book:      { name: 'book',      kind: 'hasOne', target: 'Book' },
      blueprint: { name: 'blueprint', kind: 'hasOne', target: 'Blueprint' },
    },
  ),

  SkillsGrowFromWork: ownerDecision(
    'Crafting, gathering, building, dismantling and repairing grow the worker\'s own skill for that kind of work ' +
    '(sewing makes you a better sewer). Nothing a member does is progress for a clan: clan projects have no labour ' +
    'and are complete once their materials are in. Clan tiers come from the buildings a clan owns and their ' +
    'material rarity, and give nothing yet. Raids are not wanted now (deferred) and upkeep is removed. Clan skills ' +
    'for top contributors and elder-only buildings come later.',
    'Make a specialty the result of how someone plays, and a clan the sum of its members (EverythingHasTradeoffs, Phase 203)',
    {
      work:     { name: 'work',     kind: 'hasOne', target: 'WorkSkills' },
      tiers:    { name: 'tiers',    kind: 'hasOne', target: 'ClanTiers' },
      replaces: { name: 'replaces', kind: 'hasOne', target: 'SettlementRaidsAndUpkeep' },
    },
  ),

  EarthScaleHeights: ownerDecision(
    'Peaks reach about 8,850 m (Everest is 8,849 m) and buildings up to 163 floors of 3 m. Every building follows ' +
    'the floor and shape limits of its weakest load-bearing material: wood 2 floors, stone 5, concrete 10, and ' +
    'higher classes up to 163. Unusual shapes (long overhangs, wide unsupported spans, slender towers) need rarer ' +
    'materials. Builds that exist when the rules land are never collapsed.',
    'Let players build as tall as Earth, as far as their materials allow (BelievableNotRealistic, Phase 203)',
    {
      world:     { name: 'world',     kind: 'hasOne', target: 'WorldSystem' },
      structure: { name: 'structure', kind: 'hasOne', target: 'Structure' },
    },
  ),
}
