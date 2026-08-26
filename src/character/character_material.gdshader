shader_type spatial;
// Character material — pixel-art palette pipeline (characters.md §17–§25, ROADMAP Phase 22).
//
// Replaces the per-part StandardMaterial3D albedo tint with a shared,
// parameterised ShaderMaterial: every character part samples ONE shared
// 256×1 palette texture (§19) and carries only per-instance colour indices
// (§20), so a palette swap changes appearance without creating a new texture
// asset and two characters with different palettes share the same GPU texture
// and shader.
//
// Mask channels (artist-authored, §17/§18):
//   color_mask_tex  R = Primary, G = Secondary, B = Accent
//   channel_tex     R = Metal, G = Emission, B = Wear   (§21/§22/§23)
//
// The placeholder build authors no mask textures yet, so both default to black
// (colour falls back to `base_index`, channels fall back to the scalar
// uniforms below). A real mask texture's channel is max()'d with the scalar so
// either drives the result — scalars now, authored masks later, one shader.

// Shared 256-entry palette (§19): nearest-filtered, no mipmaps, no tiling.
uniform sampler2D palette_tex : filter_nearest, repeat_disable;

// Per-instance palette indices (§20) — one byte each.
uniform int base_index = 0;
uniform int primary_index = 0;
uniform int secondary_index = 0;
uniform int accent_index = 0;

// Colour-region masks (§17/§18): R=Primary, G=Secondary, B=Accent.
uniform sampler2D color_mask_tex : hint_default_black, filter_nearest, repeat_disable;

// Material channels (§21/§22/§23): R=Metal, G=Emission, B=Wear.
uniform sampler2D channel_tex : hint_default_black, filter_nearest, repeat_disable;

// Per-instance channel scalars — the placeholder path; a real texture channel
// is max()'d in so either source drives the result.
uniform float metalness : hint_range(0.0, 1.0) = 0.0;
uniform float emission_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec3 emission_color = vec3(0.0);
uniform float wear : hint_range(0.0, 1.0) = 0.0;

// Low-res detail/albedo texture (§24/§25), nearest-filtered like the palette.
uniform sampler2D detail_tex : hint_default_white, filter_nearest, repeat_disable;

vec3 palette_sample(int idx) {
	float u = (float(clamp(idx, 0, 255)) + 0.5) / 256.0;
	return texture(palette_tex, vec2(u, 0.5)).rgb;
}

void fragment() {
	vec4 cmask = texture(color_mask_tex, UV);
	vec4 ch = texture(channel_tex, UV);

	vec3 col = palette_sample(base_index);
	col = mix(col, palette_sample(primary_index), cmask.r);
	col = mix(col, palette_sample(secondary_index), cmask.g);
	col = mix(col, palette_sample(accent_index), cmask.b);
	col *= texture(detail_tex, UV).rgb;

	float m = max(ch.r, metalness);
	float e = max(ch.g, emission_strength);
	float w = max(ch.b, wear);

	// Wear desaturates and darkens toward a grimy tone (§23).
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(lum) * 0.4, w);

	ALBEDO = col;
	METALLIC = m;
	ROUGHNESS = 0.55;
	EMISSION = emission_color * e;
}
