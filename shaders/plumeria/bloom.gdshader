// The plumeria trees' leaves and the flowers (the hibiscus bushes themselves are painted-woodland's): each a card cut to its
// shape. UV2.x the kind: 0 a long plumeria leaf, 2 a plumeria flower (five creamy
// petals turning over each other, a yolk-yellow heart), 3 a hibiscus flower (five broad red petals, a
// dark eye, the long stamen). COLOR.rgb tints it. They stir a little in the breeze.
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

#include "res://shaders/plumeria/common.gdshaderinc"

varying vec3 world_pos;
varying vec3 world_normal;
varying float kind;

void vertex() {
	kind = UV2.x;
	vec3 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float ph = p.x * 1.7 + p.z * 1.3;
	p += vec3(sin(TIME * 1.9 + ph), sin(TIME * 2.6 + ph * 1.3) * 0.6, sin(TIME * 1.4 + ph * 0.7)) * 0.012;
	world_pos = p;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	VERTEX = (inverse(MODEL_MATRIX) * vec4(p, 1.0)).xyz;
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	vec3 base;
	float edge_dark = 0.0;
	if (kind < 0.5) {
		// a long leaf, pointed at both ends, along v; a pale midrib
		float w = 0.42 * pow(max(1.0 - p.y * p.y, 0.0), 0.7);
		if (abs(p.x) > w) discard;
		base = vec3(0.2, 0.38, 0.14) * (0.85 + 0.25 * smoothstep(0.0, w, abs(p.x)));
		base = mix(base, vec3(0.55, 0.62, 0.3), smoothstep(0.05, 0.0, abs(p.x)));
	} else {
		bool hib = kind > 2.5;
		float a = atan(p.y, p.x);
		float r = length(p);
		// five petals, each turned over the next (a pinwheel for the plumeria)
		float k = a * 5.0 / 6.28318 + (hib ? 0.0 : r * 0.35);
		float petal = abs(fract(k) - 0.5) * 2.0; // 0 middle of a petal .. 1 between
		float outline = hib ? 0.95 - 0.18 * pow(petal, 2.0) : 0.98 - 0.55 * pow(petal, 1.5);
		if (r > outline) discard;
		if (hib) {
			base = mix(vec3(0.5, 0.02, 0.06), vec3(0.95, 0.15, 0.18), smoothstep(0.1, 0.5, r));
			base *= 0.85 + 0.2 * vnoise(vec2(a * 6.0, r * 8.0));
		} else {
			base = mix(vec3(1.0, 0.82, 0.25), vec3(1.0, 0.97, 0.9), smoothstep(0.05, 0.45, r));
			edge_dark = smoothstep(0.75, 0.1, petal) * 0.08;
		}
		base *= COLOR.rgb;
		base *= 1.0 - edge_dark;
		if (hib && r < 0.07) base = vec3(0.95, 0.85, 0.3);
	}
	if (kind < 1.5) {
		base *= COLOR.rgb;
	}
	vec3 n = normalize(world_normal);
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - world_pos);
	if (dot(n, to_cam) < 0.0) n = -n;
	float wrap = clamp(dot(n, SUN) * 0.5 + 0.55, 0.0, 1.0);
	vec3 col = mix(base * SHADE * 1.2, base * SUN_COL * 1.35, smoothstep(0.35, 0.75, wrap));
	col += base * vec3(0.7, 0.75, 0.3) * pow(clamp(dot(-to_cam, SUN), 0.0, 1.0), 4.0) * 0.4;
	col = haze(col, world_pos, CAMERA_POSITION_WORLD, 0.0034);
	ALBEDO = col;
}
