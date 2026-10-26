// The room itself (walls, drapes, floor, ceiling, the bar, the booths, the brass): painted, not lit. Each
// surface is its vertex colour under club_light, with brushy noise; velvet glows at its grazing edges,
// brass and the bar top catch the lamps, buttoned upholstery has its tufts, and the mirror ball's specks
// go over everything.
shader_type spatial;
render_mode unshaded, cull_disabled;

#include "res://shaders/velvet_moth/club.gdshaderinc"

uniform vec3 tint : source_color = vec3(1.0);
uniform float sheen = 0.0;
uniform float gloss = 0.0;
uniform float tuft = 0.0;
uniform float speck = 1.0;
uniform float brush = 0.25;

varying vec3 wp;
varying vec3 wn;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(wn);
	vec3 v = normalize(CAMERA_POSITION_WORLD - wp);
	if (dot(n, v) < 0.0) n = -n;
	vec3 base = COLOR.rgb * tint;
	float strokes = vnoise(wp.xy * 2.3 + wp.z * 1.7) + vnoise(wp.zy * 5.0) * 0.5 - 0.75;
	float shine = 0.0;
	if (COLOR.a < 0.5 && n.y > 0.5) {
		// floorboards (vertex alpha 0): long planks running back from the rail, staggered, waxed
		float px = wp.x / 0.19;
		float pi = floor(px);
		float pz = wp.z / 2.3 + h11(pi + 3.0);
		float pid = floor(pz);
		float fx = fract(px);
		float fz = fract(pz);
		float wx = fwidth(px) + 0.01;
		float seam = max(smoothstep(wx * 1.5, 0.0, min(fx, 1.0 - fx)), smoothstep(0.015, 0.0, min(fz, 1.0 - fz)));
		base *= (0.75 + 0.45 * h21(vec2(pi, pid))) * (1.0 - 0.6 * seam) * (0.9 + 0.2 * vnoise(vec2(wp.x * 30.0, wp.z * 1.5)));
		shine = 0.35;
	}
	vec3 L = club_light(wp, n);
	if (tuft > 0.0) {
		// diamond buttoning: a grid on the slant, darker in its dimples, a button at each crossing
		vec2 q = vec2(wp.x + wp.z, wp.y) * vec2(3.2, 4.5);
		vec2 g = vec2(q.x + q.y, q.x - q.y) * 0.5;
		vec2 f = fract(g);
		float seam = smoothstep(0.1, 0.0, min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)));
		float dimple = 1.0 - length(f - 0.5) * 1.2;
		float button = smoothstep(0.1, 0.04, length(f));
		L *= mix(1.0, 0.65 + 0.5 * dimple, tuft) * (1.0 - seam * 0.3 * tuft);
		L += button * tuft * 0.12;
	}
	vec3 col = base * L * (1.0 + strokes * brush);
	float ndv = clamp(dot(n, v), 0.0, 1.0);
	// velvet: dark face on, bright at the turn
	col = mix(col, col * (0.55 + 2.2 * pow(1.0 - ndv, 2.0)), sheen);
	float gl = max(gloss, shine);
	if (gl > 0.0) {
		vec3 r = reflect(-v, n);
		col += gl * vec3(1.0, 0.65, 0.35) * pow(max(dot(r, normalize(BAR_LAMP - wp)), 0.0), 24.0) * 1.2;
		vec3 fp = vec3(clamp(wp.x, FLOOR_RECT.x, FLOOR_RECT.z), 0.0, clamp(wp.z, FLOOR_RECT.y, FLOOR_RECT.w));
		col += gl * floor_glow() * pow(max(dot(r, normalize(fp - wp)), 0.0), 6.0) * 0.8;
		col += gl * vec3(0.9, 0.3, 0.8) * pow(1.0 - ndv, 4.0) * 0.4;
	}
	col += vec3(1.0, 0.92, 0.98) * specks(wp, n) * speck;
	ALBEDO = col;
}
