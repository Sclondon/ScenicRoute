// A Mediterranean morning sky: deep blue overhead fading to a pale milky haze at the sea's edge, a glow
// round the sun, and a few soft clouds sitting low over the hills.
shader_type sky;

uniform vec3 sun_dir = vec3(0.4, 0.75, -0.55);
uniform vec3 horizon : source_color = vec3(0.86, 0.9, 0.92);
uniform vec3 zenith : source_color = vec3(0.16, 0.4, 0.76);
uniform vec3 glow : source_color = vec3(1.0, 0.96, 0.85);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void sky() {
	vec3 d = EYEDIR;
	vec3 sun = normalize(sun_dir);
	float up = clamp(d.y, 0.0, 1.0);
	float towards = clamp(dot(d, sun), 0.0, 1.0);
	vec3 col = mix(horizon, zenith, smoothstep(0.0, 0.55, pow(up, 0.75)));
	col = mix(col, glow, pow(towards, 6.0) * 0.45);
	col += glow * pow(towards, 120.0) * 2.0;
	// soft clouds, low, piled up
	vec2 q = d.xz / max(d.y + 0.08, 0.04);
	float c = vnoise(q * 0.9 + vec2(TIME * 0.003, 0.0)) * 0.6 + vnoise(q * 2.3 + 1.7) * 0.3 + vnoise(q * 5.0) * 0.1;
	float cloud = smoothstep(0.58, 0.8, c) * smoothstep(0.0, 0.06, d.y) * (1.0 - smoothstep(0.12, 0.35, d.y));
	vec3 cloud_col = mix(vec3(0.82, 0.85, 0.9), vec3(1.0, 0.98, 0.94), smoothstep(0.6, 0.8, c));
	col = mix(col, cloud_col, cloud * 0.85);
	// below the horizon (past the far sea), the haze
	col = mix(col, horizon * 0.95, smoothstep(0.0, -0.05, d.y));
	COLOR = col;
}
