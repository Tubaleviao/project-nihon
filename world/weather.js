const { defineEntity } = require('@newel/core')

module.exports = {

  WeatherSystem: defineEntity({
    role: 'system',
    description:
      'Simulates weather across biomes as an emergent world system. ' +
      'Weather is not authored — it emerges from biome parameters, seasonal cycles, ' +
      'and player-built infrastructure (logging, irrigation, chimneys). ' +
      'Effects are gameplay-significant: rain douses fires, storms disable airships, ' +
      'blizzards slow movement and starve uninsulated settlements.',
    goal: 'Make weather a real logistical variable that drives construction, trade, and seasonal planning',
    behaviors: {
      evaluateWeather: {
        description: 'Calculate the current weather state for a biome tile each in-game hour',
        rules: [
          'Base weather probability is derived from biome avgTemperature and avgRainfall',
          'Player deforestation in temperate biomes increases drought probability by 5% per 100 felled tiles',
          'Player-built irrigation canals reduce drought probability by 3% per 50 canal segments',
          'Volcanic biomes always have ash-fall risk on eruption days regardless of other factors',
          'Twilight groves cycle through calm/fog/electrical-storm patterns tied to their day-night speed',
          'Void rifts generate local weather anomalies (void-storms) independent of global weather simulation',
        ],
        auth: { roles: ['maintainer'] },
      },
      applyWeatherEffects: {
        description: 'Apply the current weather state to gameplay mechanics in the affected tile',
        rules: [
          'Rain: open fire structures extinguished; wood rot rate doubled; crop growth +20%',
          'Storm: airship travel disabled in affected tiles; player movement speed –30% outdoors',
          'Blizzard: player heat-loss rate tripled; uninsulated structures lose integrity at 1% per hour',
          'Ash-fall: visibility –50%; all outdoor forges temporarily disabled',
          'Fog: trade route visibility markers hidden; ambush risk elevated for caravans',
          'Electrical-storm: player and creature movement speed –20%; metal armour wearers struck periodically for minor lightning damage',
          'Void-storm: void corruption accumulates 3× faster; all ley-line structures overcharge',
        ],
        auth: { roles: ['maintainer'] },
      },
      overrideWeather: {
        description: 'Allow maintainers to manually trigger a weather event for testing or world events',
        rules: [
          'Overrides must specify duration in in-game hours',
          'Override is logged and visible in the world-event feed',
          'Override cannot contradict biome physics permanently — effects revert after duration',
        ],
        auth: { roles: ['maintainer'] },
      },
    },
  }),

}
