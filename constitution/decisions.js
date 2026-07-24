const { defineEntity } = require('@newel/core')

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
}
