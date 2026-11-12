// Phase 242 — the low-end terrain shader (`nihon/graphics/terrain_quality` low; the default on the
// Compatibility renderer). The same CUSTOM0/CUSTOM1 weights as terrain_material.gdshader, but only the
// two heaviest layers are drawn, albedo only, from the two strongest planar projections (biplanar), with
// no loops or arrays: on a software rasteriser (llvmpipe in CI) the full shader starved the chunk workers.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2DArray albedo_maps : source_color, filter_linear_mipmap, repeat_enable;
// Unused here; declared so both shaders take the same parameters.
uniform sampler2DArray normal_maps : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2DArray roughness_maps : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float layer_scale[8];
uniform vec4 tint : source_color = vec4(1.0);
uniform bool biplanar = true;
uniform bool detail = false;
uniform bool surface_maps = false;
uniform float plane_cut = 0.12;

varying vec3 world_pos;
varying vec3 world_nrm;
varying vec4 w_lo;
varying vec4 w_hi;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	w_lo = CUSTOM0;
	w_hi = CUSTOM1;
}

vec3 sample_layer(vec3 p, vec3 b, float layer) {
	vec3 c = vec3(0.0);
	if (b.x > 0.0) c += texture(albedo_maps, vec3(p.zy, layer)).rgb * b.x;
	if (b.y > 0.0) c += texture(albedo_maps, vec3(p.xz, layer)).rgb * b.y;
	if (b.z > 0.0) c += texture(albedo_maps, vec3(p.xy, layer)).rgb * b.z;
	return c;
}

void fragment() {
	float total = dot(w_lo, vec4(1.0)) + dot(w_hi, vec4(1.0));
	if (total < 0.01) {
		ALBEDO = COLOR.rgb * tint.rgb;   // a placed block keeps the season tint, as before Phase 242
	} else {
		// The two heaviest layers, unrolled.
		float wa = w_lo.x; float ia = 0.0;
		float wb = 0.0; float ib = 0.0;
		if (w_lo.y > wa) { wb = wa; ib = ia; wa = w_lo.y; ia = 1.0; } else if (w_lo.y > wb) { wb = w_lo.y; ib = 1.0; }
		if (w_lo.z > wa) { wb = wa; ib = ia; wa = w_lo.z; ia = 2.0; } else if (w_lo.z > wb) { wb = w_lo.z; ib = 2.0; }
		if (w_lo.w > wa) { wb = wa; ib = ia; wa = w_lo.w; ia = 3.0; } else if (w_lo.w > wb) { wb = w_lo.w; ib = 3.0; }
		if (w_hi.x > wa) { wb = wa; ib = ia; wa = w_hi.x; ia = 4.0; } else if (w_hi.x > wb) { wb = w_hi.x; ib = 4.0; }
		if (w_hi.y > wa) { wb = wa; ib = ia; wa = w_hi.y; ia = 5.0; } else if (w_hi.y > wb) { wb = w_hi.y; ib = 5.0; }
		if (w_hi.z > wa) { wb = wa; ib = ia; wa = w_hi.z; ia = 6.0; } else if (w_hi.z > wb) { wb = w_hi.z; ib = 6.0; }
		if (w_hi.w > wa) { wb = wa; ib = ia; wa = w_hi.w; ia = 7.0; } else if (w_hi.w > wb) { wb = w_hi.w; ib = 7.0; }
		vec3 n = abs(normalize(world_nrm));
		vec3 b = n * n;
		b /= b.x + b.y + b.z;
		float lo = min(b.x, min(b.y, b.z));
		b = max(b - vec3(lo + plane_cut), vec3(0.0));
		b /= max(b.x + b.y + b.z, 1e-5);
		vec3 c = sample_layer(world_pos / layer_scale[int(ia)], b, ia);
		float share = wb / max(wa + wb, 1e-5);
		if (share > 0.05) {
			c = mix(c, sample_layer(world_pos / layer_scale[int(ib)], b, ib), share);
		}
		ALBEDO = c * tint.rgb;
	}
	ROUGHNESS = 0.9;
}
