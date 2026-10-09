const { defineEntity } = require('@newel/core')

module.exports = {

  WorldSystem: defineEntity({
    tags: ['world-system'],
    description:
      'The planet as a fact of the fabric. The world takes globe semantics on a flat chunk grid: ' +
      'X wraps around the circumference, Z is latitude, and walking over a pole comes back down the far ' +
      'meridian, so every direction leads round the planet. Players ' +
      'locate each other by latitude, longitude and altitude. Terrain is seed-deterministic, so only ' +
      'player edits are ever stored.',
    goal: 'Make one persistent, Earth-sized world whose size is a design fact rather than a code constant',
    fields: {
      id:              { type: 'uuid', primaryKey: true },
      circumferenceKm: { type: 'decimal', description: 'Length of the equator in km; X wraps after this distance (Phase 50)', defaultValue: 40000 },
      polarLatitude:   { type: 'decimal', description: 'Degrees of latitude at which the flat, walkable polar ice sheet begins (north and south); the world spans pole to pole at 90 (Phase 50)', defaultValue: 85 },
      seaLevel:        { type: 'decimal', description: 'World Y in metres of the ocean surface (Phase 51)', defaultValue: 0 },
      minHeight:       { type: 'decimal', description: 'Lowest terrain surface, in metres: the deepest ocean floor (Phase 51)', defaultValue: -64 },
      maxHeight:       { type: 'decimal', description: 'Highest terrain surface, in metres: the tallest peak (Phase 51)', defaultValue: 512 },
      oceanShare:      { type: 'decimal', description: 'Target fraction of the planet below sea level, 0–1 (Phase 51)', defaultValue: 0.65 },
      heightSpline:    { type: 'json', description: 'Continentalness (0–1) to base height in metres: ocean basin, shelf, coast, inland. Points are [continentalness, height], ascending (Phase 51)', defaultValue: [[0, -64], [0.35, -52], [0.55, -24], [0.64, -2], [0.68, 3], [0.75, 30], [0.88, 90], [1, 140]] },
      ridgeAmplitude:  { type: 'decimal', description: 'Metres a mountain ridge adds on rugged inland ground (Phase 51)', defaultValue: 400 },
      spawnHabitableBiomes:     { type: 'json', description: 'Biomes a new player may spawn in; ocean, ice and VoidRift are left out on purpose (Phase 53)', defaultValue: ['TemperateForest', 'TemperateGrassland', 'Savanna', 'Taiga', 'Desert', 'Tundra'] },
      spawnMinColonizedDistance: { type: 'decimal', description: 'Minimum distance in metres from any colonized region for a new player spawn (Phase 53)', defaultValue: 2000 },
      colonizedScore:           { type: 'decimal', description: 'Colonization score (edited chunks + homes x 10 + recent presence) at which a region counts as colonized (Phase 53)', defaultValue: 1 },
      dayLengthMinutes: { type: 'decimal', description: 'Real minutes one in-game day lasts: the world clock advances 1/dayLengthMinutes of a day per real minute (Phase 54)', defaultValue: 24 },
      yearLengthDays:   { type: 'decimal', description: 'In-game days in one year; the seasons cycle once per year (Phase 54)', defaultValue: 32 },
      axialTilt:        { type: 'decimal', description: 'Degrees the planet\'s axis leans from its orbit: the sun\'s declination swings ±axialTilt over a year, which sets day length and season strength by latitude (Phase 54)', defaultValue: 23.5 },
      friendSpawnRadius:        { type: 'decimal', description: 'Metres around a friend within which a friend-code spawn lands (Phase 53)', defaultValue: 200 },
    },
  }),

}
