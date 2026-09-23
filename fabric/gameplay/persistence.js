const { defineEntity } = require('@newel/core')

// Server-side persistence system (Phase 33). Every number and path the save
// lifecycle needs lives here rather than as a bare GDScript constant, so the
// autosave cadence and the on-disk layout are a single-source design edit that
// regenerates GameData. The runtime reads them from GameData.WORLD_SYSTEMS.

module.exports = {

  // ─── PersistenceSystem ─────────────────────────────────────────────────────
  PersistenceSystem: defineEntity({
    tags: ['world-system'],
    description:
      'Defines the authoritative save lifecycle: which directory the world and ' +
      'per-player records live in, how often the server autosaves, how a ' +
      'headless server is asked to shut down cleanly, and how a record is ' +
      'written so a kill mid-write cannot truncate it. The world record holds ' +
      'chunk manifests, stations, and creature state; one record per player ' +
      'holds position, HP, inventory, and technology.',
    goal: 'Ground TheWorldIsPersistent — the world and its players survive a restart, a reconnect, and a kill -TERM',
    fields: {
      id: { type: 'uuid', primaryKey: true },
      serverSaveDir: {
        type: 'string',
        description: 'Directory holding the server world record and one file per player record.',
        defaultValue: 'user://saves/server/',
      },
      worldFileName: {
        type: 'string',
        description: 'File name (inside serverSaveDir) of the authoritative world record.',
        defaultValue: 'world.json',
      },
      playerFilePrefix: {
        type: 'string',
        description: 'Prefix for per-player record files; the player id is appended before the extension.',
        defaultValue: 'player_',
      },
      autosaveIntervalSeconds: {
        type: 'integer',
        description: 'Seconds between authoritative autosaves. Bounds how much world state a hard kill can lose, since a headless server cannot intercept SIGTERM.',
        defaultValue: 300,
      },
      shutdownRequestPath: {
        type: 'string',
        description: 'Path polled on the autosave tick; when it exists the server saves and quits cleanly. The headless substitute for a window-close or SIGTERM hook.',
        defaultValue: 'user://shutdown_requested',
      },
      atomicWrites: {
        type: 'boolean',
        description: 'Write records through a temp file + rename so a kill during a save cannot leave a truncated record.',
        defaultValue: true,
      },
    },
    behaviors: {
      saveWorld: {
        description: 'Write the authoritative world record: chunk manifests, stations, creature state, and the local player id',
        rules: [
          'An incremental save merges only the dirty chunk manifests into the existing record',
          'A full save rewrites every loaded chunk manifest',
          'The write goes through a temp file and a rename when atomicWrites is set',
        ],
        auth: { roles: ['maintainer'] },
      },
      savePlayer: {
        description: 'Write one player record: position, HP, inventory with per-instance durability, and technology',
        rules: [
          'Records are keyed by the server-issued player_id, never by peer_id',
          'Each record is written whole; a partial write is never visible',
        ],
        auth: { roles: ['maintainer'] },
      },
      loadOnBoot: {
        description: 'Load the world and every player record when the authoritative boot starts',
        rules: [
          'Only the authoritative half loads — a client receives state from the host',
          'A missing world record is not an error; the server boots a fresh world',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),
}
