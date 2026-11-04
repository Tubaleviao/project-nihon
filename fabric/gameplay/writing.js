const { defineEntity } = require('@newel/core')

// Phase 203 — research is per player and is shared only by writing. A Book teaches one researched technology;
// a Blueprint teaches one structure or station recipe (a recipe whose output is a station, or a settlement
// project). Only a player who knows the content may write one, at `station` ('' = anywhere) for `cost`.
// Reading teaches it and never consumes it, so it can be read again and lent. Phase 209 reads this from
// GameData.WRITINGS and adds the items.
const WRITING = {
  Book:      { teaches: 'technology', station: '', cost: [{ item: 'Duskfiber', quantity: 2 }, { item: 'ThornwoodPlank', quantity: 1 }], consumedOnRead: false, writerMustKnow: true },
  Blueprint: { teaches: 'recipe', recipeKinds: ['station', 'project'], station: 'carpentry bench', cost: [{ item: 'Duskfiber', quantity: 3 }], consumedOnRead: false, writerMustKnow: true },
}

// Phase 209 — one item per thing that can be written down: `<Writing><Key>` (a project key is capitalised:
// BlueprintPalisade). The item names what it teaches, so a written book is an ordinary pack item that a chest,
// a trade or a drop carries like any other. The validator checks the list covers every technology, station
// recipe and project and nothing else.
const TECHNOLOGIES = ['TechBasicSmithing', 'TechMasterForge', 'TechBasicCarpentry', 'TechTextileWeaving', 'TechArcaneForging', 'TechAlchemy', 'TechVoidMastery', 'TechConcrete', 'TechSteel', 'TechLeyframe']
const STATION_RECIPES = ['RecipeBed', 'RecipeChest', 'RecipeDoor', 'RecipeHearth']
const PROJECTS = ['palisade', 'storehouse', 'workshop', 'watchtower']
const capital = (k) => k.charAt(0).toUpperCase() + k.slice(1)
const WRITING_ITEMS = Object.fromEntries([
  ...TECHNOLOGIES.map((t) => [`Book${t}`, { writing: 'Book', teaches: t, kind: 'technology' }]),
  ...STATION_RECIPES.map((r) => [`Blueprint${r}`, { writing: 'Blueprint', teaches: r, kind: 'station' }]),
  ...PROJECTS.map((p) => [`Blueprint${capital(p)}`, { writing: 'Blueprint', teaches: p, kind: 'project' }]),
])

const isObj = (v) => v !== null && typeof v === 'object' && !Array.isArray(v)

function writingData() { return JSON.parse(JSON.stringify(WRITING)) }

function writingRefs() {
  const tagged = (table, tag) => Object.entries(table).filter(([, e]) => e && (e.tags || []).includes(tag)).map(([k]) => k)
  const items = require('./items')
  const settlement = require('./settlement')
  const recipes = require('./recipes')
  const stationItems = new Set([...tagged(items, 'station'), 'Hearth'])
  const stationRecipes = Object.entries({ ...recipes, RecipeHearth: settlement.RecipeHearth })
    .filter(([, r]) => ((r.fields.recipe && r.fields.recipe.defaultValue.outputs) || []).some((o) => stationItems.has(o.item)))
    .map(([k]) => k)
  return {
    goods: [...tagged(items, 'item'), ...tagged(require('../world/materials'), 'material'), 'Hearth'],
    stationTypes: require('./tutorial').tutorialRefs().stationTypes,
    technologies: tagged(require('./technology'), 'technology'),
    stationRecipes,
    projects: Object.keys(settlement.PROJECTS.projects),
  }
}

/** Problems with the writing table, as strings. */
function writingProblems(w, refs) {
  const p = []
  for (const k of ['Book', 'Blueprint']) if (!isObj(w[k])) p.push(`Writing.${k} is missing`)
  for (const [k, def] of Object.entries(w)) {
    const at = `Writing.${k}`
    if (def.consumedOnRead !== false) p.push(`${at}.consumedOnRead must be false: reading never consumes it, so it can be read again and lent`)
    if (def.writerMustKnow !== true) p.push(`${at}.writerMustKnow must be true: only a player who knows the content can write it`)
    if (def.station !== '' && !refs.stationTypes.includes(def.station)) p.push(`${at}.station "${def.station}" is not a placeable station type`)
    if (!Array.isArray(def.cost) || def.cost.length === 0) p.push(`${at}.cost must list at least one { item, quantity }: writing has a material cost`)
    for (const [i, c] of (def.cost || []).entries()) {
      if (!refs.goods.includes(c.item)) p.push(`${at}.cost[${i}]: "${c.item}" is not an item or material`)
      if (!Number.isInteger(c.quantity) || c.quantity < 1) p.push(`${at}.cost[${i}].quantity must be an integer >= 1`)
    }
  }
  if (w.Book && w.Book.teaches !== 'technology') p.push('Writing.Book.teaches must be "technology"')
  if (w.Book && refs.technologies.length === 0) p.push('Writing.Book has no technology to teach')
  if (w.Blueprint) {
    if (w.Blueprint.teaches !== 'recipe') p.push('Writing.Blueprint.teaches must be "recipe"')
    if (JSON.stringify(w.Blueprint.recipeKinds) !== JSON.stringify(['station', 'project'])) p.push('Writing.Blueprint.recipeKinds must be ["station", "project"]: a blueprint teaches a structure or station')
    if (refs.stationRecipes.length + refs.projects.length === 0) p.push('Writing.Blueprint has no station recipe or project to teach')
  }
  const same = (a, b) => JSON.stringify([...a].sort()) === JSON.stringify([...b].sort())
  if (!same(TECHNOLOGIES, refs.technologies)) p.push(`Writing items must cover exactly the technologies ${refs.technologies.join(', ')}`)
  if (!same(STATION_RECIPES, refs.stationRecipes)) p.push(`Writing items must cover exactly the station recipes ${refs.stationRecipes.join(', ')}`)
  if (!same(PROJECTS, refs.projects)) p.push(`Writing items must cover exactly the projects ${refs.projects.join(', ')}`)
  return p
}

function validateWriting(w, refs) {
  const problems = writingProblems(w, refs)
  if (problems.length) throw new Error('Writing rules are invalid:\n  ' + problems.join('\n  '))
}

const writingEntity = (key, description, goal, target) => defineEntity({
  tags: ['writing'],
  description,
  goal,
  fields: {
    id:      { type: 'uuid', primaryKey: true },
    teaches: { type: 'string', description: 'The technology or recipe key it teaches, chosen when written' },
    author:  { type: 'string', description: 'Player id of the writer' },
    rules:   { type: 'json', description: 'Writing rule: { teaches, station, cost, consumedOnRead, writerMustKnow } (validated at fabric load)', defaultValue: WRITING[key] },
  },
  relations: {
    teaches:  { name: 'teaches',  kind: 'hasOne', target },
    decision: { name: 'decision', kind: 'hasOne', target: 'ResearchSharedByWriting' },
  },
  behaviors: {
    write: {
      description: `Write a ${key.toLowerCase()} about something the writer knows`,
      rules: ['Refused when the writer does not know the content', 'Consumes the cost'],
      auth: { roles: ['maintainer'] },
    },
    read: {
      description: `Read a ${key.toLowerCase()} and learn what it teaches`,
      rules: ['The reader learns it; the item is kept, so it can be read again and lent'],
      auth: { roles: ['maintainer'] },
    },
  },
})

const Book = writingEntity('Book',
  'A written account of one researched technology. Reading it teaches the technology without researching it, ' +
  'and the book is kept, so it can be read again or lent.',
  'Share knowledge by writing, never through a clan (ResearchSharedByWriting, Phase 203)',
  'TechBasicSmithing')
const Blueprint = writingEntity('Blueprint',
  'A drawing of one structure or station recipe. Reading it teaches the recipe, and the blueprint is kept.',
  'Share how to build by writing (ResearchSharedByWriting, Phase 203)',
  'RecipeHearth')

module.exports = { WRITING, WRITING_ITEMS, writingData, writingRefs, writingProblems, validateWriting, Book, Blueprint }
