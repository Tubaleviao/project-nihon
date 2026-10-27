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

// Phase 180 — the two creation body presets: a chibi figure (head about a third of the height, short limbs), used by
// both genders. Parts are public placeholders at the keys the private pack fills.
const chibiPreset = (gender, description) => defineEntity({
  tags: ['appearance', 'creation'],
  description,
  goal: `The fixed chibi body a ${gender} character is created with`,
  fields: {
    skeleton: { type: 'string', description: 'Skeleton key in GameData.SKELETONS', defaultValue: 'HumanoidSkeleton' },
    body: { type: 'string', description: 'Body mesh identifier', defaultValue: `chibi_body_${gender[0]}_01` },
    proportions: {
      type: 'json',
      description: 'Chibi proportions (§8): a large head and short limbs; the bounds were widened for them',
      defaultValue: { height: 0.85, bodyMass: 1.1, shoulderWidth: 1.0, armLength: 0.7, legLength: 0.65, headScale: 1.8 },
    },
    skinColor: { type: 'integer', description: 'Palette index for skin', defaultValue: gender === 'masculine' ? 10 : 6 },
    head: { type: 'string', description: 'Head mesh identifier', defaultValue: `chibi_head_${gender[0]}_01` },
    eyes: { type: 'string', description: 'Eyes component identifier (large and expressive)', defaultValue: 'eyes_chibi_01' },
    eyeColor: { type: 'integer', description: 'Palette index for eyes', defaultValue: 225 },
    hair: { type: 'string', description: 'Hair component identifier (the creation default)', defaultValue: `hair_chibi_${gender[0]}_01` },
    hairColor: { type: 'integer', description: 'Palette index for hair', defaultValue: 40 },
    beard: { type: 'string', description: 'Beard component identifier', defaultValue: 'none' },
    beardColor: { type: 'integer', description: 'Palette index for beard', defaultValue: 40 },
    equipment: { type: 'json', description: 'Equipment instances by slot', defaultValue: {} },
  },
})

module.exports = {

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

  CreationMasculine: chibiPreset('masculine', 'The masculine creation body: a chunky chibi figure with a big head, large eyes, short limbs and big hands and boots.'),
  CreationFeminine: chibiPreset('feminine', 'The feminine creation body: a chunky chibi figure with a big head, large eyes, short limbs and big hands and boots.'),

}
