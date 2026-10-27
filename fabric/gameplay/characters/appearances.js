const { defineEntity } = require('./shared')

// ─────────────────────────────────────────────────────────────────────────────
// Appearance recipes (characters.md §30)
//
// A character is persisted as a recipe — a set of identifiers and parameters
// sufficient to reconstruct its visual state — never as a custom mesh or
// texture. These entities are example recipes used to spawn demo characters;
// real characters are assembled from persisted recipes at runtime.
//
// `equipment` maps a slot (Chest, MainHand, …) to an equipment instance:
// { item, state, primaryColor, secondaryColor, accentColor, durability }.
// `state` is the attachment state (§7: equipped / sheathed / stored / hidden);
// the item definition (in GameData.ITEMS) carries the sockets and masks.
// ─────────────────────────────────────────────────────────────────────────────

// Phase 180 — the chibi art style: a big head (about a third of the height), short limbs, big hands
// and boots. Both creation gender presets use these proportions. headScale, legLength, armLength and
// height reach past the pre-180 §8 bounds; characters.md §8 records the widened bounds.
const CHIBI_PROPORTIONS = { height: 0.8, bodyMass: 1.1, shoulderWidth: 1.0, armLength: 0.7, legLength: 0.55, headScale: 2.6 }
// The head-to-height ratio a chibi rig must keep (head height / total height, placeholder landmarks).
const CHIBI_RANGE = { min: 0.28, max: 0.4 }

// A creation gender preset (Phase 180): body, head, eyes, skin and proportions are fixed by the gender;
// hair and hair colour come from the player's creation. `hair` here is the default for the preset.
function novicePreset({ gender, body, head, eyes, hair, proportions }) {
  return defineEntity({
    tags: ['appearance'],
    description:
      `The ${gender} character-creation preset: a chibi body in the plain novice tunic. ` +
      'The player picks hair and hair colour on top of it (CharacterCreation); everything else is fixed.',
    goal: 'Give every new character the same readable chibi silhouette, told apart by hair and name',
    fields: {
      skeleton: { type: 'string', description: 'Skeleton key in GameData.SKELETONS', defaultValue: 'HumanoidSkeleton' },
      body: { type: 'string', description: 'Body mesh identifier: models/characters/bodies/<id>.glb.raw', defaultValue: body },
      proportionPreset: { type: 'string', description: 'Named proportion preset these proportions come from', defaultValue: 'chibi' },
      proportions: { type: 'json', description: 'Body proportion multipliers (§8, chibi preset)', defaultValue: proportions },
      skinColor: { type: 'integer', description: 'Palette index for skin', defaultValue: 6 },
      head: { type: 'string', description: 'Head mesh identifier: models/characters/heads/<id>.glb.raw', defaultValue: head },
      eyes: { type: 'string', description: 'Eyes texture identifier: textures/characters/eyes/<id>.png.raw', defaultValue: eyes },
      eyeColor: { type: 'integer', description: 'Palette index for eyes', defaultValue: 225 },
      hair: { type: 'string', description: 'Default hair style (CharacterCreation.hairStyles)', defaultValue: hair },
      hairColor: { type: 'integer', description: 'Default hair colour (CharacterCreation.hairColors)', defaultValue: 41 },
      beard: { type: 'string', description: 'Beard component identifier', defaultValue: 'none' },
      beardColor: { type: 'integer', description: 'Palette index for beard', defaultValue: 0 },
      equipment: {
        type: 'json',
        description: 'Equipment instances by slot: the starting kit worn',
        defaultValue: { Chest: { item: 'NoviceTunic', state: 'equipped', primaryColor: 96, secondaryColor: 100, accentColor: 140, durability: 1.0 } },
      },
    },
  })
}

module.exports = {

  NoviceMasculine: novicePreset({
    gender: 'masculine', body: 'chibi_body_m', head: 'chibi_head_m', eyes: 'chibi_eyes_m', hair: 'hair_m_crop',
    proportions: CHIBI_PROPORTIONS,
  }),

  NoviceFeminine: novicePreset({
    gender: 'feminine', body: 'chibi_body_f', head: 'chibi_head_f', eyes: 'chibi_eyes_f', hair: 'hair_f_bob',
    proportions: { ...CHIBI_PROPORTIONS, height: 0.75, bodyMass: 1.05, shoulderWidth: 0.95 },
  }),

  TravellerHuman: defineEntity({
    tags: ['appearance'],
    description:
      'The default humanoid traveller: veilsteel chestplate, a sheathed veilsteel ' +
      'longsword, and a stored ferrite shield. Demonstrates the full composition ' +
      'stack — body proportions, face, hair, beard, and multi-slot equipment.',
    goal: 'Provide a representative humanoid appearance for demo and testing',
    fields: {
      skeleton: { type: 'string', description: 'Skeleton key in GameData.SKELETONS', defaultValue: 'HumanoidSkeleton' },
      body: { type: 'string', description: 'Body mesh identifier', defaultValue: 'human_body_02' },
      proportions: {
        type: 'json',
        description: 'Body proportion multipliers (§8); clamped to artistic bounds',
        defaultValue: { height: 0.96, bodyMass: 1.04, shoulderWidth: 1.03, armLength: 1.0, legLength: 1.0, headScale: 1.0 },
      },
      skinColor: { type: 'integer', description: 'Palette index for skin', defaultValue: 12 },
      head: { type: 'string', description: 'Head mesh identifier', defaultValue: 'head_03' },
      eyes: { type: 'string', description: 'Eyes component identifier', defaultValue: 'eyes_07' },
      eyeColor: { type: 'integer', description: 'Palette index for eyes', defaultValue: 225 },
      hair: { type: 'string', description: 'Hair component identifier', defaultValue: 'hair_long_04' },
      hairColor: { type: 'integer', description: 'Palette index for hair', defaultValue: 40 },
      beard: { type: 'string', description: 'Beard component identifier', defaultValue: 'beard_short_02' },
      beardColor: { type: 'integer', description: 'Palette index for beard', defaultValue: 40 },
      equipment: {
        type: 'json',
        description: 'Equipment instances by slot',
        defaultValue: {
          Chest: { item: 'VeilsteelChestplate', state: 'equipped', primaryColor: 70, secondaryColor: 100, accentColor: 130, durability: 1.0 },
          MainHand: { item: 'VeilsteelLongsword', state: 'sheathed', primaryColor: 0, secondaryColor: 0, accentColor: 130, durability: 0.7 },
          OffHand: { item: 'FerriteShield', state: 'stored', primaryColor: 70, secondaryColor: 0, accentColor: 130, durability: 0.5 },
        },
      },
    },
  }),

  BoarRider: defineEntity({
    tags: ['appearance'],
    description:
      'A quadruped boar — the same character system driving a non-humanoid ' +
      'skeleton. Demonstrates that Character is not synonymous with humanoid (§3).',
    goal: 'Provide a representative non-humanoid appearance for demo and testing',
    fields: {
      skeleton: { type: 'string', description: 'Skeleton key in GameData.SKELETONS', defaultValue: 'QuadrupedSkeleton' },
      body: { type: 'string', description: 'Body mesh identifier', defaultValue: 'boar_body_01' },
      proportions: {
        type: 'json',
        description: 'Body proportion multipliers (§8)',
        defaultValue: { height: 0.9, bodyMass: 1.15, shoulderWidth: 1.0, armLength: 1.0, legLength: 1.0, headScale: 1.0 },
      },
      skinColor: { type: 'integer', description: 'Palette index for skin/fur', defaultValue: 20 },
      head: { type: 'string', description: 'Head mesh identifier', defaultValue: 'boar_head_01' },
      eyes: { type: 'string', description: 'Eyes component identifier', defaultValue: 'eyes_01' },
      eyeColor: { type: 'integer', description: 'Palette index for eyes', defaultValue: 225 },
      hair: { type: 'string', description: 'Hair component identifier', defaultValue: 'none' },
      hairColor: { type: 'integer', description: 'Palette index for hair', defaultValue: 0 },
      beard: { type: 'string', description: 'Beard component identifier', defaultValue: 'none' },
      beardColor: { type: 'integer', description: 'Palette index for beard', defaultValue: 0 },
      equipment: { type: 'json', description: 'Equipment instances by slot', defaultValue: {} },
    },
  }),

}

module.exports.CHIBI_PROPORTIONS = CHIBI_PROPORTIONS
module.exports.CHIBI_RANGE = CHIBI_RANGE
