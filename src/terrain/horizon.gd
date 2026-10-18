extends RefCounted
## Phase 164 — the planet's curvature, pure and static. The world is a sphere of circumference
## `circumference_m` (the fabric's, via `TerrainSlice.circumference_chunks`), so the ground drops away
## from a viewer by d² / 2R at horizontal distance d, and the horizon of an eye `h` above the ground
## lies √(2Rh + h²) away. Used by the distant ring (its outer radius and its curvature shader), the
## camera's far plane, the suite and Phase 165's far bands.

const TerrainSliceScript := preload("res://src/terrain/terrain_slice.gd")

## The ring's vertex shader: each vertex drops by `curvature_drop` of its horizontal distance to the
## camera, so the ring bends with the planet without a rebuild when the camera moves. `planet_radius`
## is set from `planet_radius()` (see `curvature_material`); the shader holds no radius of its own.
const CURVATURE_SHADER := """shader_type spatial;
render_mode cull_disabled;

uniform float planet_radius = 1.0;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 d = world.xz - CAMERA_POSITION_WORLD.xz;
	VERTEX.y -= dot(d, d) / (2.0 * planet_radius);
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
}
"""

static var _shader: Shader = null

## The world's circumference in metres (the fabric's).
static func default_circumference() -> float:
	return float(TerrainSliceScript.circumference_chunks()) * TerrainSliceScript.CHUNK_METERS

## R = C / 2π (about 6,366 km for the default 40,000 km).
static func planet_radius(circumference_m: float = -1.0) -> float:
	var c := circumference_m if circumference_m > 0.0 else default_circumference()
	return c / TAU

## How far the ground at horizontal distance `d` lies below a viewer's tangent plane: d² / 2R.
static func curvature_drop(d: float, circumference_m: float = -1.0) -> float:
	return d * d / (2.0 * planet_radius(circumference_m))

## Distance to the horizon for an eye `eye_h` metres above the ground: √(2R·h + h²).
static func horizon_distance(eye_h: float, circumference_m: float = -1.0) -> float:
	var h := maxf(eye_h, 0.0)
	return sqrt(2.0 * planet_radius(circumference_m) * h + h * h)

## A target `target_h` tall at distance `d` is in view from an eye `eye_h` high while it clears the
## horizon: d < horizon_distance(eye_h) + horizon_distance(target_h).
static func visible_over_horizon(eye_h: float, target_h: float, d: float, circumference_m: float = -1.0) -> bool:
	return d < horizon_distance(eye_h, circumference_m) + horizon_distance(target_h, circumference_m)

## A material running `CURVATURE_SHADER` for a planet of `circumference_m` (vertex colours as albedo).
static func curvature_material(circumference_m: float = -1.0) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = CURVATURE_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("planet_radius", planet_radius(circumference_m))
	return mat
