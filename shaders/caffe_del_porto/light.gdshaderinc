// Shared by the Caffè del Porto's lit shaders: noise, and the light painted in two tones (the engine's sun,
// with its shadows, cut to a soft step; the shade side is the environment's cool ambient), plus a glint
// for glossy things. `v_brush` shifts the step a little per stroke; `v_gloss` 0..1.

varying float v_brush;
varying float v_gloss;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.1 + 3.7) * 0.3 + vnoise(p * 4.3 + 7.1) * 0.15;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float d = smoothstep(-0.04 + v_brush, 0.3 + v_brush, ndl);
	float lit = d * smoothstep(0.15, 0.85, ATTENUATION);
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * lit;
	if (v_gloss > 0.0) {
		vec3 h = normalize(LIGHT + VIEW);
		SPECULAR_LIGHT += LIGHT_COLOR / PI * smoothstep(0.55, 0.8, pow(max(dot(NORMAL, h), 0.0), 40.0)) * v_gloss * lit * 1.5;
	}
}
