# Character System — Project Nihon

## 1. Objective

The character system must support a high degree of visual customization while
maintaining a consistent artistic identity based on:

- low-poly 3D models;
- low-resolution textures;
- pixel art aesthetic;
- controlled color palettes;
- modern, stylized 3D lighting;
- modular character composition.

The architecture must be appropriate for a sandbox MMORPG and must account for:

- large numbers of simultaneous characters;
- persistence;
- multiplayer synchronization;
- asset reuse;
- continuous content expansion;
- CPU and GPU performance;
- different creature types;
- equipment and cosmetics;
- animations;
- LOD;
- future system evolution.

The pixel art aesthetic is **not** achieved through post-processing or artificial
resolution reduction. It is a direct consequence of the assets and materials
themselves.

---

## 2. Core Principles

Visual customization is divided into three independent dimensions.

### Shape

Defines the geometry and proportions of the character.

Examples: height, body mass, shoulder width, arm length, leg length, head scale,
head shape.

### Composition

Defines which visual components make up the character.

Examples: body, hair, beard, clothing, armor, cape, backpack, weapon, shield,
accessories.

### Appearance

Defines the visual properties of those components.

Examples: skin color, hair color, Primary Color, Secondary Color, Accent Color,
metal type, emission, wear.

These three dimensions must remain independent wherever possible.

---

## 3. Character is Not Humanoid

`Character` must not be synonymous with humanoid character. The system must
support different character types.

```
Character
├── SkeletonDefinition
├── Body
├── Appearance
├── Attachments
├── Equipment
└── AnimationSet
```

Supported skeleton families:

```
SkeletonDefinition
├── Humanoid
├── Quadruped
├── Bird
├── Serpent
└── Custom
```

Characters sharing a `SkeletonDefinition` can potentially share animations,
equipment, poses, emotes, combat systems, and interactions. This significantly
reduces content production cost.

The same architecture applies to humans, other humanoid races, animals,
monsters, mounts, domesticated creatures, and transformations.

---

## 4. SkeletonDefinition

`SkeletonDefinition` describes the bone structure used by a character type.

Example humanoid skeleton:

```
Root
└── Hips
    ├── Spine
    │   └── Chest
    │       ├── Neck
    │       │   └── Head
    │       ├── Shoulder_L → Arm_L → Forearm_L → Hand_L
    │       └── Shoulder_R → Arm_R → Forearm_R → Hand_R
    ├── Leg_L → Foot_L
    └── Leg_R → Foot_R
```

---

## 5. Bones vs. Sockets

**Bones** exist primarily for animation and mesh deformation.

**Sockets** exist for attachment. A weapon must not declare `attachTo = Hand_R`;
it must declare `attachTo = socket_weapon_r`.

Example sockets on a humanoid skeleton:

```
socket_head
socket_face
socket_back
socket_cape
socket_weapon_r
socket_weapon_l
socket_shield
socket_hip_r
socket_hip_l
socket_mount
```

Sockets are positioned relative to bones but represent semantic attachment
points, not deformation joints.

---

## 6. Equipment Slot vs. Socket

**Equipment Slot** answers: *What is equipped?*

Examples: `Head`, `Chest`, `Hands`, `Legs`, `Feet`, `Cape`, `Back`,
`MainHand`, `OffHand`.

**Socket** answers: *Where is this object visually attached?*

A katana may occupy `slot = MainHand` but have:

```
equippedSocket: socket_weapon_r
storedSocket:   socket_hip_l
```

This separation allows the visual representation to change independently of
the logical equipment state.

---

## 7. Attachment States

Equipment can have multiple visual states:

```
Equipped
Stored
Sheathed
Hidden
Dropped
```

Example declaration:

```
slot: MainHand
attachments:
  equipped:  socket_weapon_r
  sheathed:  socket_hip_l
```

This enables left-handed characters, dual-wield, two-handed weapons, back-stored
weapons, scabbards, and special equipment — all without modifying inventory state.

---

## 8. Base Body

Each character family may have one or more body meshes compatible with its
`SkeletonDefinition`. For humanoids, supported parameters include:

| Parameter      | Min  | Default | Max  |
|---------------|------|---------|------|
| height         | 0.85 | 1.00    | 1.15 |
| bodyMass       | 0.80 | 1.00    | 1.20 |
| shoulderWidth  | 0.90 | 1.00    | 1.10 |
| armLength      | 0.90 | 1.00    | 1.10 |
| legLength      | 0.90 | 1.00    | 1.10 |
| headScale      | 0.90 | 1.00    | 1.10 |

These bounds are **artistically defined**, not engine defaults. Each combination
must be validated against animations, clothing, armor, attachments, clipping, and
silhouette readability before the bounds are finalized.

---

## 9. Visual Proportion Does Not Determine Hitbox

Visual customization must not create involuntary competitive advantages.

A visually shorter character must not automatically have a meaningfully smaller
hitbox. The physics layer uses standardized hitbox categories, not derived values
from visual proportion parameters.

---

## 10. Equipment Deformation Modes

Equipment declares how it responds to body proportion changes:

| Mode     | Behavior                              | Suited for                                       |
|----------|---------------------------------------|--------------------------------------------------|
| SKINNED  | Follows body deformation              | Clothing, light fabric, soft armor               |
| RIGID    | Maintains its own geometry            | Helmets, weapons, shields, metal accessories     |
| HYBRID   | Combines deformable and rigid parts   | Plate armor, boots, pauldrons, composite gear    |

This prevents a metal plate from stretching like cloth when body proportions
change.

---

## 11. Silhouette

Character identity must rely heavily on silhouette. A character must remain
recognizable even when their texture is not clearly visible.

Key silhouette contributors: height, body shape, hair, hat, helmet, pauldrons,
cape, backpack, weapon, shield.

This matters especially in an MMORPG where many characters appear simultaneously.

---

## 12. Head and Face

The head follows the same modular principles.

Properties that may be part of the Body/Head Mesh: head shape, nose, jaw, ears.

Properties that may use independent components: eyes, eyebrows, mouth, beard,
hair.

The goal is not facial realism. Identity must emerge from a combination of few
stylized, visually strong elements.

---

## 13. Hair

Hair assets are independent components. Examples: `Hair_Short_01`,
`Hair_Long_01`, `Hair_Ponytail_01`, `Hair_Mohawk_01`.

Color is controlled through the palette system. A single `Hair_Long` mesh uses
`colorIndex = 14` — there is no separate `Hair_Long_Black`, `Hair_Long_Blonde`,
etc.

Long styles may include additional bones for physics.

---

## 14. Beards

Beards follow the same principle. Examples: `Beard_None`, `Beard_Short`,
`Beard_Long`, `Beard_Goatee`, `Beard_Braided`.

Hair and beard remain independent of each other.

---

## 15. Modular Equipment

Equipment components are independent. Initial humanoid slots:

`Head`, `Chest`, `Hands`, `Legs`, `Feet`, `Cape`, `Back`, `MainHand`, `OffHand`

A visual set does not need to exist as a single mesh. Players combine components
freely.

---

## 16. Mesh Hiding

Equipment declares which visual regions it hides. Examples:

```
ClosedHelmet:    hide: [Hair, Ears]
OpenFaceHelmet:  hide: [HairTop]
PlateChest:      hide: [BodyChest, BodyShoulders]
```

This reduces clipping without requiring a custom version of each hair asset for
each helmet.

---

## 17. Material System

Materials are shared and parameterized. Main visual inputs:

```
Base Color
Primary Color Mask
Secondary Color Mask
Accent Color Mask
Metal Mask
Emission Mask
Wear Mask
```

There is no Pattern Mask and no free pixel editing by players. Artists define all
drawings, details, symbols, borders, and ornaments. Players modify only the
parameters explicitly exposed by the asset.

---

## 18. Primary, Secondary, and Accent Colors

Equipment may have up to three customizable color regions:

```
Primary   = Blue
Secondary = White
Accent    = Gold
```

Colors apply only to artist-defined mask regions, preserving the asset's visual
identity.

---

## 19. Palette System

Rather than arbitrary RGB values, the system uses controlled palettes. A Palette
Texture represents a collection of allowed colors.

Characters store color indices:

```
hairColor    = 17
skinColor    = 8
primaryColor = 21
```

The shader uses these indices to sample the Palette Texture.

**Palette size** must be defined explicitly — a recommended starting point is
**256 entries**, fitting a single-channel 16×16 or 256×1 texture. This
determines the network encoding (1 byte per color index), the shader sampler
size, and the persistence cost per character. The exact palette size should be
confirmed before building shader and serialization code.

### Why palettes

- **Artistic consistency** — players cannot create combinations outside the
  art direction.
- **Network efficiency** — one byte per color index instead of a full RGB tuple.
- **Persistence** — no complex values or textures stored per character.
- **GPU efficiency** — one Palette Texture shared across many characters.
- **Artistic evolution** — a color can be adjusted globally without modifying
  saved characters.

---

## 20. Per-Instance Material Data

Color customization must not require creating a new Material per character.
A shared material receives per-instance color index data:

```
SharedCharacterMaterial

Player A: primary=12, secondary=4,  accent=7
Player B: primary=3,  secondary=18, accent=1
Player C: primary=8,  secondary=2,  accent=14
```

Engine mechanisms: Unity `MaterialPropertyBlock`, Unreal Per-Instance Custom
Data / Primitive Data, or equivalent. The conceptual architecture must not depend
on a specific engine.

---

## 21. Metal Mask

The Metal Mask identifies regions that receive metallic visual treatment.

Example — Leather Armor: leather regions are standard; buckles and rivets use
the metal mask.

Stylized metal definitions (Iron, Steel, Bronze, Gold) alter tone, lighting
response, reflection, and highlight intensity. Results must remain stylized, not
photorealistic.

---

## 22. Emission Mask

The Emission Mask identifies emissive regions: runes, crystals, magic eyes,
enchanted weapons, artifacts.

The same mesh can use different emissions:

```
Sword_Arcane / emissionColor = Blue
Sword_Arcane / emissionColor = Red
```

---

## 23. Wear Mask

The Wear Mask defines where wear appears. Wear is derived from gameplay state,
not stored independently:

```
durability 100% → New
durability  70% → Used
durability  40% → Worn
durability  10% → Heavily Damaged
```

Wear may represent scratches, discoloration, stylized cracks, dirt, or surface
damage. This visually communicates item state to other players.

---

## 24. Pixel Art Textures

Textures use deliberately low resolution. Representative starting values:

| Asset type | Resolution       |
|-----------|-----------------|
| Face       | 32 × 32         |
| Hair       | 32 × 32         |
| Body       | 64 × 64         |
| Armor      | 64 × 64         |
| Weapon     | 32 × 32 – 64 × 64 |

These are not absolute rules. The key principle is **consistent texel density**
across assets. A significantly larger object may justify a larger texture.

---

## 25. Texture Filtering

Pixel art textures must use **Nearest / Point filtering**. Standard bilinear
interpolation must be avoided for assets that form this aesthetic. Pixels must
remain visually discrete.

---

## 26. UV Mapping

UVs must be produced with the pixel grid in mind:

- avoid distortion;
- maintain consistent texel density;
- align important regions to the grid;
- avoid heavily stretched pixels;
- keep regions semantically readable.

An artist must be able to look at a 32×32 or 64×64 texture and clearly identify
the regions corresponding to the model.

---

## 27. Texture Arrays and Atlases

Many assets using small independent textures can increase texture swaps and draw
calls. The pipeline must be prepared for grouping strategies.

Preferred initial approach — **Texture Arrays**:

```
BodyTextureArray
HairTextureArray
ArmorTextureArray
WeaponTextureArray
```

An asset references its texture array and layer index:

```
mesh:         IronChest01
textureArray: ArmorTextureArray
textureLayer: 17
```

This allows many characters to share the same GPU resources.

---

## 28. Dynamic Texture Atlasing

Dynamic per-character atlas generation must not be a first-implementation
requirement. It introduces runtime texture generation, extra GPU memory, CPU→GPU
uploads, cache management, and cache invalidation on equipment changes.

Preferred order:

1. Shared resources
2. Texture Arrays
3. Static atlases
4. Profiling
5. Additional optimizations if measurements justify them

---

## 29. Lighting

The game does not use fullscreen pixelization as a foundational technique.
Scenes are rendered at the device's native resolution, preserving UI, text,
particles, shadows, effects, and distant elements.

The pixel art aesthetic emerges from: low-poly geometry, low-resolution textures,
Point filtering, pixel-aligned UVs, controlled palettes, and stylized materials.

Modern lighting techniques (dynamic lighting, shadows, ambient occlusion, fog,
rim lighting, emissive materials, ambient lighting) are compatible with this
aesthetic. Materials must avoid photorealistic PBR behavior.

Target rendering identity:

> Pixel-Art Assets × Modern 3D Lighting × Stylized Rendering

Not:

> Pixel-Art Assets × Photorealistic PBR

---

## 30. Persistence as a Recipe

A character must be saved as a recipe — a set of identifiers and parameters
sufficient to reconstruct the visual state — not as a custom mesh or texture.

```
CharacterAppearance
  skeleton:      humanoid_01
  body:          human_body_02
  height:        0.96
  bodyMass:      1.04
  shoulderWidth: 1.03
  skinColor:     12
  head:          head_03
  eyes:          eyes_07
  eyeColor:      22
  hair:          hair_long_04
  hairColor:     8
  beard:         beard_short_02
  beardColor:    8
```

---

## 31. Equipment Persistence

Equipment follows the same recipe principle. The server transmits identifiers
and parameters; the client holds the assets.

```
EquipmentInstance
  item:          iron_chestplate_04
  primaryColor:  8
  secondaryColor: 12
  accentColor:   3
  metal:         iron
  wear:          0.23
```

---

## 32. Multiplayer Visual State

When a character enters another player's relevant area, the server transmits the
character's visual state. The client assembles the character locally.

```
CharacterVisualState
  Identity:    skeleton, body
  Body:        proportions, skinColor
  Face:        head, eyes, beard
  Hair:        asset, color
  Equipment:   head, chest, hands, legs, feet, cape, back, mainHand, offHand
  Parameters:  colors, metal, wear, emission
```

---

## 33. Persistent vs. Derived Visual State

Not all visual information needs to be persisted directly.

`durability = 0.23` derives `wear = HEAVILY_WORN`.

The same principle applies to: broken items, wet items, burning items, poisoned
characters, frozen characters, enchantments, and temporary effects.

---

## 34. Permanent vs. Transient State

**Permanent:** body, face, hair, color, equipment, materials.

**Transient:** weapon drawn, wet, burning, poison effect, temporary glow, blood,
dirt, snow, magic status.

Transient states do not need to be part of the persisted character recipe.

---

## 35. LOD — Level of Detail

Characters must support multiple LOD levels:

| LOD  | Context          | Description                          |
|------|-----------------|--------------------------------------|
| LOD0 | Close range      | Maximum detail                       |
| LOD1 | Medium distance  | Reduced geometry                     |
| LOD2 | Long distance    | Significantly simplified geometry    |
| LOD3 | Extreme distance | Minimal representation               |

LOD transitions must preserve silhouette, dominant color, and primary equipment.
Fine details may progressively disappear.

---

## 36. LOD Composition Simplification

LOD is not only polygon reduction. At large distances the system may stop
rendering: small beard, tiny accessories, facial details, minor attachments,
discrete emissions, internal armor details.

Each attachment should declare a `minLodLevel` field to indicate at which LOD
level it stops rendering. This must be defined in the asset data — not as
engine-specific logic.

---

## 37. Animation System (to be specified)

The `AnimationSet` is referenced in the character hierarchy but requires its own
dedicated specification covering:

- animation state machines;
- blend trees;
- locomotion and combat transitions;
- sheathing and draw animations;
- dual-wield and two-handed weapon handling;
- quadruped vs. humanoid animation differences;
- socket-driven attachment state changes;
- emotes and social animations.

This section is a placeholder. The animation system specification must be
produced before any animation production begins.

---

## 38. Data-Driven Content

Adding new equipment must not require modifying core code. Example item
definition:

```
IronChestplate
  slot:           Chest
  mesh:           iron_chestplate
  material:       armor_pixel
  textureArray:   armor
  textureLayer:   17
  deformationMode: HYBRID
  masks:
    primary:  true
    secondary: true
    accent:   true
    metal:    true
    emission: false
    wear:     true
  hide: [BodyChest, BodyShoulders]
```

---

## 39. Asset Compatibility

Assets must declare their requirements.

```
SamuraiHelmet
  compatibleSkeletons: [humanoid_01]

OrcAxe
  compatibleTags: [humanoid, has_hands, can_wield_weapon]
```

This matters because not all characters will share the same anatomy. A humanoid
boot is not compatible with a horse; a sword may be compatible with multiple
creature types.

---

## 40. Semantic Tags

To avoid hard coupling to specific skeleton IDs, the system uses tags:

```
humanoid          quadruped        has_hands
has_head          can_wield_weapon can_wear_helmet
has_back_socket
```

Future content can be added without coupling equipment to specific character
classes.

---

## 41. Asset Pipeline

Production steps for each new equipment asset:

1. Create low-poly mesh
2. Define skeleton compatibility
3. Rig where necessary
4. Create pixel-grid-aligned UV mapping
5. Create low-resolution texture
6. Define Primary, Secondary, Accent masks
7. Define Metal mask
8. Define Emission mask
9. Define Wear mask
10. Define `deformationMode`
11. Define Mesh Hiding regions
12. Define Equipment Slot
13. Define Attachment States
14. Define Sockets
15. Set `minLodLevel` per attachment
16. Define compatibility / tags
17. Register asset in the content system

From this point, adding content is predominantly asset production and data
configuration — no core code changes.

---

## 42. Optimization Principles

The architecture must allow optimizations but must not depend on speculative ones.

Decision order:

```
Correctness
    ↓
Visual Consistency
    ↓
Modularity
    ↓
Profiling
    ↓
Optimization
```

GPU Instancing, Texture Arrays, static atlases, mesh merging, LOD, material
batching, and dynamic atlasing are **architectural possibilities**. Concrete
implementation choices must be driven by real profiling data, not assumptions.

---

## 43. Expected Result

The system must allow characters to share most technical infrastructure —
skeletons, shaders, materials, texture arrays, animations, body systems,
equipment and attachment systems — while presenting enormous visual diversity
through composition.

```
Character
├── Skeleton
├── Body
│   └── Proportions
├── Face
│   ├── Head
│   ├── Eyes
│   └── Beard
├── Hair
├── Equipment
│   ├── Head / Chest / Hands / Legs / Feet
│   ├── Cape / Back
│   └── MainHand / OffHand
├── Appearance
│   ├── Palette
│   ├── Primary / Secondary / Accent
│   ├── Metal / Emission / Wear
└── Attachments
    └── Socket States
```

Two players can share a skeleton, body mesh, shader, material, texture arrays,
and animations — and still look completely different.

Diversity emerges from the combination of:

**Shape × Composition × Equipment × Palettes × Materials × Visual States**

The pixel art aesthetic must be an intrinsic property of the world of Project
Nihon, not a filter applied over it. It is born from:

**low-poly geometry + low-resolution textures + Point Filtering + pixel-aligned
UVs + controlled palettes + stylized materials + modern lighting**

This foundation allows Project Nihon to maintain a strong, coherent visual
identity while its architecture remains prepared for the scale, diversity, and
evolution expected of a sandbox MMORPG.
