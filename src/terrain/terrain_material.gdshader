// Phase 242 — natural ground: triplanar-textured terrain materials blended per vertex.
//
// CUSTOM0 / CUSTOM1 carry one weight per layer (layers 0-3 / 4-7, see TerrainWeights). A vertex whose
// weights are all zero is a placed block: it is drawn in its vertex colour, as before. Each layer is
// sampled from three planar projections (no stretching on cliffs) of three texture arrays, the layers
// are blended by weight with height-based borders (the brighter texel of two wins at the seam), and a
// detail sample of the same layer at a finer scale fades in near the camera. `biplanar` (the low-end
// fallback, `nihon/graphics/terrain_quality` low, the default on the Compatibility renderer) drops the
// weakest projection, the detail sample and the normal and roughness maps, and binds 256 px arrays. A projection weighing under `plane_cut` is skipped always.
shader_type spatial;
render_mode cull_disabled;

const int LAYERS = 8;

uniform sampler2DArray albedo_maps : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray normal_maps : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray roughness_maps : hint_default_white, filter_linear_mipmap, repeat_enable;
// Metres one tile of each layer covers (`scale` in the fabric).
uniform float layer_scale[LAYERS];
// The biome's season tint (Phase 54), multiplied over the textures.
uniform vec4 tint : source_color = vec4(1.0);
uniform bool biplanar = false;
uniform bool detail = true;
// Normal and roughness maps; off on the low path, which samples albedo only.
uniform bool surface_maps = true;
uniform float detail_distance = 24.0;
uniform float detail_repeat = 4.0;
uniform float blend_depth = 0.2;
uniform float normal_strength = 1.0;
uniform float plane_cut = 0.12;

varying vec3 world_pos;
varying vec3 world_nrm;
varying vec4 w_lo;
varying vec4 w_hi;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	w_lo = CUSTOM0;
	w_hi = CUSTOM1;
}

vec3 plane_weights(vec3 n) {
	vec3 b = pow(abs(n), vec3(4.0));
	b /= max(b.x + b.y + b.z, 1e-5);
	if (biplanar) {
		// Keep the two strongest projections.
		float lo = min(b.x, min(b.y, b.z));
		b = max(b - vec3(lo), vec3(0.0));
		b /= max(b.x + b.y + b.z, 1e-5);
	}
	// A projection under `plane_cut` of the blend is not sampled: flat ground reads one plane, not three.
	b = max(b - vec3(plane_cut), vec3(0.0));
	return b / max(b.x + b.y + b.z, 1e-5);
}

vec4 sample_albedo(vec3 p, vec3 bw, float layer) {
	vec4 c = vec4(0.0);
	if (bw.x > 0.0) c += texture(albedo_maps, vec3(p.zy, layer)) * bw.x;
	if (bw.y > 0.0) c += texture(albedo_maps, vec3(p.xz, layer)) * bw.y;
	if (bw.z > 0.0) c += texture(albedo_maps, vec3(p.xy, layer)) * bw.z;
	return c;
}

float sample_roughness(vec3 p, vec3 bw, float layer) {
	float r = 0.0;
	if (bw.x > 0.0) r += texture(roughness_maps, vec3(p.zy, layer)).r * bw.x;
	if (bw.y > 0.0) r += texture(roughness_maps, vec3(p.xz, layer)).r * bw.y;
	if (bw.z > 0.0) r += texture(roughness_maps, vec3(p.xy, layer)).r * bw.z;
	return r;
}

vec3 unpack_normal(vec3 c) {
	vec3 t = c * 2.0 - 1.0;
	t.xy *= normal_strength;
	return t;
}

// Whiteout-blended triplanar normal in world space (Golus, "Normal Mapping for a Triplanar Shader").
vec3 sample_normal(vec3 p, vec3 bw, vec3 n, float layer) {
	vec3 acc = vec3(0.0);
	if (bw.x > 0.0) {
		vec3 t = unpack_normal(texture(normal_maps, vec3(p.zy, layer)).rgb);
		t = vec3(t.xy + n.zy, abs(t.z) * n.x);
		acc += t.zyx * bw.x;
	}
	if (bw.y > 0.0) {
		vec3 t = unpack_normal(texture(normal_maps, vec3(p.xz, layer)).rgb);
		t = vec3(t.xy + n.xz, abs(t.z) * n.y);
		acc += t.xzy * bw.y;
	}
	if (bw.z > 0.0) {
		vec3 t = unpack_normal(texture(normal_maps, vec3(p.xy, layer)).rgb);
		t = vec3(t.xy + n.xy, abs(t.z) * n.z);
		acc += t.xyz * bw.z;
	}
	return normalize(acc + n * 1e-4);
}

float layer_weight(int i) {
	return i < 4 ? w_lo[i] : w_hi[i - 4];
}

void fragment() {
	float total = dot(w_lo, vec4(1.0)) + dot(w_hi, vec4(1.0));
	if (total < 0.01) {
		ALBEDO = COLOR.rgb;
		ROUGHNESS = 0.9;
	} else {
		vec3 n = normalize(world_nrm);
		vec3 bw = plane_weights(n);
		float cam_dist = length(world_pos - (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz);
		float fade = detail && !biplanar ? 1.0 - smoothstep(detail_distance * 0.5, detail_distance, cam_dist) : 0.0;
		vec3 albedo[LAYERS];
		float height[LAYERS];
		float hmax = -1.0;
		for (int i = 0; i < LAYERS; i++) {
			float w = layer_weight(i) / total;
			albedo[i] = vec3(0.0);
			height[i] = -1.0;
			if (w > 0.002) {
				vec3 p = world_pos / layer_scale[i];
				vec3 c = sample_albedo(p, bw, float(i)).rgb;
				if (fade > 0.0) {
					vec3 d = sample_albedo(p * detail_repeat, bw, float(i)).rgb;
					float dl = dot(d, vec3(0.333));
					c = mix(c, c * (0.6 + 0.8 * dl), fade * 0.5);
				}
				albedo[i] = c;
				height[i] = dot(c, vec3(0.333)) + w;
				hmax = max(hmax, height[i]);
			}
		}
		vec3 col = vec3(0.0);
		vec3 nrm = vec3(0.0);
		float rough = 0.0;
		float sum = 0.0;
		for (int i = 0; i < LAYERS; i++) {
			float b = max(height[i] - (hmax - blend_depth), 0.0);
			if (b > 0.0) {
				vec3 p = world_pos / layer_scale[i];
				col += albedo[i] * b;
				if (surface_maps) {
					nrm += sample_normal(p, bw, n, float(i)) * b;
					rough += sample_roughness(p, bw, float(i)) * b;
				}
				sum += b;
			}
		}
		ALBEDO = col / sum * tint.rgb;
		if (surface_maps) {
			ROUGHNESS = rough / sum;
			NORMAL = normalize((VIEW_MATRIX * vec4(normalize(nrm), 0.0)).xyz);
		} else {
			ROUGHNESS = 0.9;
		}
	}
}
