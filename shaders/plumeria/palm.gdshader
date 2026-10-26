// Coconut palms, swaying in the sea breeze. `frond` 0: the trunk, grey-brown and ringed with old leaf
// scars (UV.y metres up it). `frond` 1: the fronds, each a strip down its midrib (UV.x 0..1 along it,
// UV.y -1..1 across) cut into hanging leaflets, glowing yellow-green where the sun shines through them.
// UV2.x how much a point goes with the crown's sway, UV2.y how much it flutters; COLOR.a the tree's own
// phase, COLOR.rgb a tint (brown for a dead frond).
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

#include "res://shaders/plumeria/common.gdshaderinc"

uniform float frond = 0.0;

varying vec3 world_pos;
varying vec3 world_normal;
varying float phase;

void vertex() {
	phase = COLOR.a * 40.0;
	float t = TIME;
	vec3 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// the breeze comes off the sea (+z): the crowns lean with it and rock, the fronds stream and flutter
	float gust = 0.6 + 0.4 * sin(t * 0.31 + phase * 0.1) * sin(t * 0.17 + phase * 0.3);
	vec3 crown = vec3(sin(t * 0.7 + phase) * 0.06, 0.0, (0.1 + sin(t * 1.1 + phase) * 0.08 + sin(t * 2.3 + phase * 3.0) * 0.03) * gust);
	p += crown * UV2.x;
	float f = UV2.y;
	p.y += sin(t * 3.4 + UV.x * 6.0 + phase * 7.0) * 0.1 * f * gust;
	p.z += (0.25 + sin(t * 2.1 + phase * 5.0 + UV.x * 3.0) * 0.12) * f * gust;
	p.x += sin(t * 2.7 + phase * 2.0 + UV.y * 2.0) * 0.06 * f;
	world_pos = p;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	VERTEX = (inverse(MODEL_MATRIX) * vec4(p, 1.0)).xyz;
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - world_pos);
	if (dot(n, to_cam) < 0.0) {
		n = -n;
	}
	vec3 tint = COLOR.rgb;
	vec3 col;
	float against = clamp(dot(-to_cam, SUN) * 0.5 + 0.5, 0.0, 1.0);
	if (frond < 0.5) {
		float ring = fract(UV.y / 0.11 + vnoise(vec2(UV.x * 6.0, UV.y)) * 0.3);
		float scar = smoothstep(0.0, 0.15, ring) * smoothstep(1.0, 0.75, ring);
		vec3 bark = vec3(0.5, 0.43, 0.36) * tint * (0.7 + 0.3 * scar) * (0.9 + vnoise(vec2(UV.x * 20.0, UV.y * 2.0)) * 0.2);
		float wrap = clamp(dot(n, SUN) * 0.6 + 0.5, 0.0, 1.0);
		col = mix(bark * SHADE, bark * SUN_COL * 1.3, smoothstep(0.4, 0.7, wrap));
		col += SUN_COL * pow(1.0 - clamp(dot(n, to_cam), 0.0, 1.0), 3.0) * pow(against, 3.0) * 0.5;
	} else {
		float side = abs(UV.y);
		// leaflets: strips slanting out and back from the midrib, gaps between, ragged ends
		float lf = UV.x * 34.0 - side * 1.6;
		float id = floor(lf);
		float within = fract(lf);
		float len = 0.65 + 0.35 * hash(vec2(id, sign(UV.y)));
		float width = 0.62 * (1.0 - side / len * 0.75);
		bool rib = side < 0.05;
		if (!rib && (within > width || side > len)) {
			discard;
		}
		float shade_in = 0.75 + 0.25 * sin(within / max(width, 0.01) * 3.14159);
		vec3 leaf = vec3(0.31, 0.46, 0.18) * tint * (0.85 + hash(vec2(id, 3.0)) * 0.3) * shade_in;
		if (rib) {
			leaf = vec3(0.45, 0.45, 0.22) * tint;
		}
		float wrap = clamp(dot(n, SUN) * 0.6 + 0.5, 0.0, 1.0);
		col = mix(leaf * SHADE * 1.1, leaf * SUN_COL * 1.45, smoothstep(0.35, 0.75, wrap));
		// with the sun behind it, the leaf glows
		float through = pow(clamp(dot(-to_cam, SUN), 0.0, 1.0), 4.0);
		col += vec3(0.75, 0.8, 0.25) * tint * through * 0.55;
		col += SUN_COL * pow(1.0 - abs(dot(n, to_cam)), 2.0) * pow(against, 4.0) * 0.3;
	}
	col = haze(col, world_pos, CAMERA_POSITION_WORLD, 0.0034);
	ALBEDO = col;
}
