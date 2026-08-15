## Character system — static content definitions.
##
## Pure data module: no logic, no state. CharacterSlice (character_slice.gd)
## consumes these dictionaries as the single source of truth for skeleton
## families, body-proportion bounds, equipment, palettes, and sample
## appearances. See characters.md for the design spec these realize.
##
## Why here and not the generated godot/ content dir: character content is
## deeply nested (sockets, mask maps, hide regions, tag lists) and does not map
## cleanly onto the flat .tres Resource property pattern used by the generated
## godot/ data. Keeping it as a const-dictionary module mirrors the existing
## inline data tables (CreatureSlice.SPAWN_MANIFEST, InventorySlice.RAW_DROP_WEIGHTS)
## and avoids hand-editing the generated GameData.gd autoload.

# ---------------------------------------------------------------------------
# Palette (characters.md §19)
# ---------------------------------------------------------------------------

## Single shared palette size. One byte per color index — this is the network
## encoding size, the shader sampler size, and the per-character persistence
## cost. Recommended starting point per §19.
const PALETTE_SIZE := 256

## Regions used to build the default 256-entry palette. Each region expands its
## anchor colors into `count` entries via piecewise-linear RGB interpolation.
## Region layout (index ranges):
##   0-31    skin tones
##   32-63   hair / fur
##   64-95   primary cloth / armor
##   96-127  secondary cloth / armor
##   128-159 accent / trim
##   160-191 metals
##   192-223 emission / glow
##   224-255 eyes / misc
const PALETTE_REGIONS: Array = [
	{ "count": 32, "anchors": [Color(1.0, 0.92, 0.84), Color(0.86, 0.66, 0.52), Color(0.52, 0.32, 0.20)] },
	{ "count": 32, "anchors": [Color(0.05, 0.04, 0.05), Color(0.36, 0.23, 0.13), Color(0.62, 0.46, 0.22), Color(0.86, 0.86, 0.86)] },
	{ "count": 32, "anchors": [Color(0.16, 0.30, 0.52), Color(0.28, 0.45, 0.32), Color(0.62, 0.18, 0.18), Color(0.92, 0.78, 0.30)] },
	{ "count": 32, "anchors": [Color(0.90, 0.90, 0.90), Color(0.72, 0.72, 0.74), Color(0.30, 0.30, 0.34), Color(0.12, 0.10, 0.10)] },
	{ "count": 32, "anchors": [Color(0.90, 0.62, 0.16), Color(0.80, 0.28, 0.22), Color(0.24, 0.52, 0.62), Color(0.42, 0.28, 0.62)] },
	{ "count": 32, "anchors": [Color(0.30, 0.30, 0.32), Color(0.55, 0.50, 0.44), Color(0.72, 0.60, 0.42), Color(0.90, 0.88, 0.80)] },
	{ "count": 32, "anchors": [Color(0.16, 0.60, 0.92), Color(0.20, 0.92, 0.52), Color(0.92, 0.28, 0.28), Color(0.62, 0.30, 0.92)] },
	{ "count": 32, "anchors": [Color(0.08, 0.35, 0.70), Color(0.20, 0.65, 0.45), Color(0.55, 0.35, 0.20), Color(0.70, 0.70, 0.70)] },
]

# ---------------------------------------------------------------------------
# Skeletons (characters.md §3, §4, §5)
# ---------------------------------------------------------------------------

## Skeleton families supported by the system. A SkeletonDefinition describes the
## bone structure; characters sharing a family can share animations, equipment,
## poses, emotes, and combat systems.
const SKELETON_FAMILIES: Array = ["humanoid", "quadruped", "bird", "serpent", "custom"]

## Bone = { "name": String, "parent": String } ("Root" for the chain top).
## Sockets = semantic attachment points mapped to a bone (§5 — a weapon declares
## `socket_weapon_r`, never a raw bone name).
const SKELETONS: Dictionary = {
	"humanoid_01": {
		"family": "humanoid",
		"bones": [
			{ "name": "Root", "parent": "" },
			{ "name": "Hips", "parent": "Root" },
			{ "name": "Spine", "parent": "Hips" },
			{ "name": "Chest", "parent": "Spine" },
			{ "name": "Neck", "parent": "Chest" },
			{ "name": "Head", "parent": "Neck" },
			{ "name": "Shoulder_L", "parent": "Chest" },
			{ "name": "Arm_L", "parent": "Shoulder_L" },
			{ "name": "Forearm_L", "parent": "Arm_L" },
			{ "name": "Hand_L", "parent": "Forearm_L" },
			{ "name": "Shoulder_R", "parent": "Chest" },
			{ "name": "Arm_R", "parent": "Shoulder_R" },
			{ "name": "Forearm_R", "parent": "Arm_R" },
			{ "name": "Hand_R", "parent": "Forearm_R" },
			{ "name": "Leg_L", "parent": "Hips" },
			{ "name": "Foot_L", "parent": "Leg_L" },
			{ "name": "Leg_R", "parent": "Hips" },
			{ "name": "Foot_R", "parent": "Leg_R" },
		],
		"sockets": {
			"socket_head": "Head",
			"socket_face": "Head",
			"socket_back": "Chest",
			"socket_cape": "Chest",
			"socket_chest": "Chest",
			"socket_weapon_r": "Hand_R",
			"socket_weapon_l": "Hand_L",
			"socket_shield": "Hand_L",
			"socket_hip_r": "Hips",
			"socket_hip_l": "Hips",
			"socket_mount": "Hips",
		},
		"tags": ["humanoid", "has_head", "has_hands", "has_back_socket", "can_wield_weapon", "can_wear_helmet"],
	},
	"quadruped_01": {
		"family": "quadruped",
		"bones": [
			{ "name": "Root", "parent": "" },
			{ "name": "Hips", "parent": "Root" },
			{ "name": "Spine", "parent": "Hips" },
			{ "name": "Chest", "parent": "Spine" },
			{ "name": "Neck", "parent": "Chest" },
			{ "name": "Head", "parent": "Neck" },
			{ "name": "Leg_FL", "parent": "Chest" },
			{ "name": "Leg_FR", "parent": "Chest" },
			{ "name": "Leg_BL", "parent": "Hips" },
			{ "name": "Leg_BR", "parent": "Hips" },
			{ "name": "Tail", "parent": "Hips" },
		],
		"sockets": {
			"socket_head": "Head",
			"socket_face": "Head",
			"socket_back": "Spine",
			"socket_mount": "Spine",
		},
		"tags": ["quadruped", "has_head", "has_back_socket"],
	},
	"bird_01": {
		"family": "bird",
		"bones": [
			{ "name": "Root", "parent": "" },
			{ "name": "Spine", "parent": "Root" },
			{ "name": "Neck", "parent": "Spine" },
			{ "name": "Head", "parent": "Neck" },
			{ "name": "Wing_L", "parent": "Spine" },
			{ "name": "Wing_R", "parent": "Spine" },
			{ "name": "Leg_L", "parent": "Root" },
			{ "name": "Leg_R", "parent": "Root" },
		],
		"sockets": {
			"socket_head": "Head",
			"socket_face": "Head",
			"socket_back": "Spine",
			"socket_mount": "Spine",
		},
		"tags": ["bird", "has_head", "has_back_socket"],
	},
	"serpent_01": {
		"family": "serpent",
		"bones": [
			{ "name": "Root", "parent": "" },
			{ "name": "Spine_1", "parent": "Root" },
			{ "name": "Spine_2", "parent": "Spine_1" },
			{ "name": "Spine_3", "parent": "Spine_2" },
			{ "name": "Neck", "parent": "Spine_3" },
			{ "name": "Head", "parent": "Neck" },
		],
		"sockets": {
			"socket_head": "Head",
			"socket_face": "Head",
		},
		"tags": ["serpent", "has_head"],
	},
}

# ---------------------------------------------------------------------------
# Body proportions (characters.md §8)
# ---------------------------------------------------------------------------

## Artistically-defined bounds for humanoid body proportions. Not engine
## defaults — each value must survive validation against animations, clothing,
## clipping, and silhouette readability before being finalized.
const BODY_PROP_BOUNDS: Dictionary = {
	"height":        { "min": 0.85, "default": 1.00, "max": 1.15 },
	"bodyMass":      { "min": 0.80, "default": 1.00, "max": 1.20 },
	"shoulderWidth": { "min": 0.90, "default": 1.00, "max": 1.10 },
	"armLength":     { "min": 0.90, "default": 1.00, "max": 1.10 },
	"legLength":     { "min": 0.90, "default": 1.00, "max": 1.10 },
	"headScale":     { "min": 0.90, "default": 1.00, "max": 1.10 },
}

# ---------------------------------------------------------------------------
# Equipment slots, attachment states, deformation modes (§6, §7, §10, §15)
# ---------------------------------------------------------------------------

## Logical equipment slots — "what is equipped?" (not where it is visually).
const EQUIPMENT_SLOTS: Array = ["Head", "Chest", "Hands", "Legs", "Feet", "Cape", "Back", "MainHand", "OffHand"]

## Visual attachment states for equipment (§7). Enables left-handed, dual-wield,
## two-handed, back-stored, and scabbard variations without touching inventory.
const ATTACHMENT_STATES: Array = ["Equipped", "Stored", "Sheathed", "Hidden", "Dropped"]

## How equipment responds to body-proportion changes (§10).
const DEFORMATION_MODES: Array = ["SKINNED", "RIGID", "HYBRID"]

## Semantic compatibility tags (§40) — avoid hard coupling to skeleton IDs.
const SEMANTIC_TAGS: Array = [
	"humanoid", "quadruped", "has_hands", "has_head",
	"can_wield_weapon", "can_wear_helmet", "has_back_socket",
]

# ---------------------------------------------------------------------------
# LOD levels (characters.md §35)
# ---------------------------------------------------------------------------

## LOD0 = close range (max detail) … LOD3 = extreme distance (minimal).
const LOD_LEVELS: Dictionary = {
	0: "Close range — maximum detail",
	1: "Medium distance — reduced geometry",
	2: "Long distance — significantly simplified geometry",
	3: "Extreme distance — minimal representation",
}

# ---------------------------------------------------------------------------
# Equipment definitions (characters.md §38 — data-driven content)
# ---------------------------------------------------------------------------

## A visual equipment definition. `minLodLevel` is the coarsest LOD at which the
## part still renders (a part is visible while current_lod <= minLodLevel); the
## body/head always render at 3. `masks` mirror §17; `hide` mirrors §16.
const EQUIPMENT: Dictionary = {
	"FerriteHelmet": {
		"slot": "Head",
		"deformationMode": "RIGID",
		"masks": { "primary": true, "secondary": true, "accent": true, "metal": true, "emission": false, "wear": true },
		"hide": ["Hair"],
		"attachments": { "equipped": "socket_head", "stored": "socket_back" },
		"minLodLevel": 3,
		"compatibleTags": ["humanoid", "can_wear_helmet"],
		"size": [0.34, 0.34, 0.34],
		"metal": "ferrite",
	},
	"VeilsteelChestplate": {
		"slot": "Chest",
		"deformationMode": "HYBRID",
		"masks": { "primary": true, "secondary": true, "accent": true, "metal": true, "emission": false, "wear": true },
		"hide": ["BodyChest", "BodyShoulders"],
		"attachments": { "equipped": "socket_chest", "stored": "socket_back" },
		"minLodLevel": 3,
		"compatibleTags": ["humanoid", "has_hands"],
		"size": [0.70, 0.55, 0.42],
		"metal": "veilsteel",
	},
	"DuskfiberCloak": {
		"slot": "Cape",
		"deformationMode": "SKINNED",
		"masks": { "primary": true, "secondary": false, "accent": false, "metal": false, "emission": false, "wear": true },
		"hide": [],
		"attachments": { "equipped": "socket_cape", "stored": "socket_back" },
		"minLodLevel": 2,
		"compatibleTags": ["has_back_socket"],
		"size": [0.70, 0.90, 0.14],
		"metal": "none",
	},
	"VeilsteelLongsword": {
		"slot": "MainHand",
		"deformationMode": "RIGID",
		"masks": { "primary": false, "secondary": false, "accent": true, "metal": true, "emission": false, "wear": true },
		"hide": [],
		"attachments": { "equipped": "socket_weapon_r", "sheathed": "socket_hip_l", "stored": "socket_back" },
		"minLodLevel": 2,
		"compatibleTags": ["has_hands", "can_wield_weapon"],
		"size": [0.10, 0.10, 1.10],
		"metal": "veilsteel",
	},
	"FerriteShield": {
		"slot": "OffHand",
		"deformationMode": "RIGID",
		"masks": { "primary": true, "secondary": false, "accent": true, "metal": true, "emission": false, "wear": true },
		"hide": [],
		"attachments": { "equipped": "socket_shield", "stored": "socket_back" },
		"minLodLevel": 2,
		"compatibleTags": ["has_hands", "can_wield_weapon"],
		"size": [0.55, 0.75, 0.08],
		"metal": "ferrite",
	},
}

# ---------------------------------------------------------------------------
# Sample appearance recipes (characters.md §30 — persistence as a recipe)
# ---------------------------------------------------------------------------

## A character is saved as a recipe of identifiers + parameters, never as a
## custom mesh or texture. These are example recipes used to spawn demo
## characters; real characters are assembled from persisted recipes.
const SAMPLE_APPEARANCES: Dictionary = {
	"traveller_human": {
		"skeleton": "humanoid_01",
		"body": "human_body_02",
		"proportions": { "height": 0.96, "bodyMass": 1.04, "shoulderWidth": 1.03, "armLength": 1.0, "legLength": 1.0, "headScale": 1.0 },
		"skinColor": 12,
		"head": "head_03",
		"eyes": "eyes_07",
		"eyeColor": 225,
		"hair": "hair_long_04",
		"hairColor": 40,
		"beard": "beard_short_02",
		"beardColor": 40,
		"equipment": {
			"Chest": { "item": "VeilsteelChestplate", "state": "equipped", "primaryColor": 70, "secondaryColor": 100, "accentColor": 130, "metal": "veilsteel", "durability": 1.0 },
			"MainHand": { "item": "VeilsteelLongsword", "state": "sheathed", "primaryColor": 0, "secondaryColor": 0, "accentColor": 130, "metal": "veilsteel", "durability": 0.7 },
			"OffHand": { "item": "FerriteShield", "state": "stored", "primaryColor": 70, "secondaryColor": 0, "accentColor": 130, "metal": "ferrite", "durability": 0.5 },
		},
	},
	"boar_rider": {
		"skeleton": "quadruped_01",
		"body": "boar_body_01",
		"proportions": { "height": 0.9, "bodyMass": 1.15, "shoulderWidth": 1.0, "armLength": 1.0, "legLength": 1.0, "headScale": 1.0 },
		"skinColor": 20,
		"head": "boar_head_01",
		"eyes": "eyes_01",
		"eyeColor": 225,
		"hair": "none",
		"hairColor": 0,
		"beard": "none",
		"beardColor": 0,
		"equipment": {},
	},
}
