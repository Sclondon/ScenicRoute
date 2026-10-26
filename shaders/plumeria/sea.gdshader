// The sea at sundown: deep violet-teal out to a horizon lost in gold haze, the sky mirrored in it, the
// sun's road of glitter coming across it to you, and long swells rolling in that rise, glow green-gold
// through their faces with the sun behind them, break into white water and run up the sand.
// The mesh is a grid laid along the shore; the surf is shaped in the vertex shader, on the same clock as
// the sand's wash and the sound (common.gdshaderinc).
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

#include "res://shaders/plumeria/common.gdshaderinc"

varying vec3 world_pos;

float ripples(vec2 p, float t) {
	return vnoise(p * vec2(0.9, 2.6) + vec2(t * 0.25, t * 0.6)) * 0.55
		+ vnoise(p * vec2(2.3, 5.5) + vec2(-t * 0.4, t * 0.9)) * 0.3
		+ vnoise(p * vec2(4.0, 7.0) + vec2(t * 0.7, -t * 0.5)) * 0.15;
}

float height(vec2 xz, float t, out float foam, out float face) {
	float d = shore_z(xz.x) - xz.y;
	float fade = 1.0 - smoothstep(140.0, 260.0, abs(xz.x));
	float h = surf(d, t, foam, face) * fade;
	foam *= fade;
	face *= fade;
	// the open sea's own long swell
	h += (sin(xz.y * 0.09 + t * 0.7) * 0.18 + sin(xz.x * 0.05 - xz.y * 0.06 + t * 0.5) * 0.12) * smoothstep(20.0, 60.0, d);
	return h;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME - wave_t0;
	float foam;
	float face;
	world_pos.y += height(world_pos.xz, t, foam, face);
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world_pos, 1.0)).xyz;
}

void fragment() {
	float t = TIME - wave_t0;
	vec2 p = world_pos.xz;
	float d = shore_z(p.x) - p.y;
	float dist = length(world_pos - CAMERA_POSITION_WORLD);
	float foam;
	float face;
	float h = height(p, t, foam, face);
	float e = 0.35;
	float f2;
	float f3;
	float hx = height(p + vec2(e, 0.0), t, f2, f3);
	float hz = height(p + vec2(0.0, e), t, f2, f3);
	vec3 n = normalize(vec3(h - hx, e, h - hz));
	// small ripples, fading out where a pixel covers more than they are across (they would only shimmer)
	float foot = length(fwidth(p));
	float rs = 1.0 - smoothstep(0.04, 0.3, foot);
	float r0 = ripples(p, t);
	vec3 rn = vec3(r0 - ripples(p + vec2(0.15, 0.0), t), 0.0, r0 - ripples(p + vec2(0.0, 0.15), t)) * 1.1;
	n = normalize(n + rn * mix(0.08, 1.0, rs));
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - world_pos);
	vec3 view = -to_cam;
	vec3 r = reflect(view, n);
	r.y = abs(r.y);
	float fresnel = 0.08 + 0.92 * pow(1.0 - clamp(dot(to_cam, n), 0.0, 1.0), 4.0);
	// the water's own colour: dusky teal in the surf, deep violet-blue out to sea
	vec3 deep = vec3(0.06, 0.07, 0.17);
	vec3 shallow = vec3(0.1, 0.26, 0.3);
	vec3 body = mix(shallow, deep, smoothstep(4.0, 60.0, d));
	// the sky in it, darkened and cooled, so the sea reads deeper than the sky and the sun's road shines
	vec3 mirrored = sky_color(r) * vec3(0.62, 0.55, 0.68);
	vec3 col = mix(body, mirrored, fresnel * 0.85);
	// the sun's road: a broad glow on the water under the sun, and glitter in it
	float toward = max(dot(r, SUN), 0.0);
	// the road, painted: a band under the sun broken into strokes across it, smaller and closer
	// together as it goes off, run together where they would be finer than a pixel
	vec3 flat_view = normalize(vec3(view.x, 0.0, view.z));
	float under_sun = pow(max(dot(flat_view, normalize(vec3(SUN.x, 0.0, SUN.z))), 0.0), 500.0);
	float strokes = smoothstep(0.5, 0.75, vnoise(p * vec2(0.35, 1.6) + vec2(t * 0.15, t * 0.5)) * 0.7 + r0 * 0.5);
	strokes = mix(strokes, 0.45, smoothstep(0.05, 0.5, foot));
	float road = pow(toward, 24.0);
	col += SUN_COL * road * 0.35;
	col += vec3(1.0, 0.82, 0.55) * under_sun * strokes * 1.3;
	float glint = pow(toward, 400.0) * rs;
	col += vec3(1.0, 0.88, 0.62) * glint * 1.5;
	// and a softer sheen the whole width of the sun's side
	col += vec3(1.0, 0.6, 0.35) * pow(max(dot(normalize(vec3(view.x, 0.0, view.z)), normalize(vec3(SUN.x, 0.0, SUN.z))), 0.0), 12.0) * 0.12;
	// the face of a wave about to break, the sun shining through its thin top
	// a swell's shoreward side is in its own shadow, dark against the bright water behind it
	float lee = smoothstep(0.04, 0.3, (h - hz) / e) * (1.0 - smoothstep(60.0, 140.0, d));
	col = mix(col, col * vec3(0.45, 0.5, 0.62), lee * 0.75);
	float through = face * smoothstep(-0.2, 0.6, dot(view, SUN));
	col = mix(col, vec3(0.35, 0.62, 0.38), through * 0.35);
	col += vec3(0.75, 0.75, 0.3) * through * smoothstep(0.15, 0.6, h) * 0.45;
	// white water: broken up into patches and lace, lit peach on top and lilac in its shadows
	float bub = vnoise(p * vec2(1.6, 3.2) + vec2(0.0, t * 0.8)) * 0.6 + vnoise(p * 5.0 - t * 0.3) * 0.4;
	float white = smoothstep(0.35, 0.65, foam * (0.55 + bub * 0.9));
	// lacy streaks left on the water between waves, in the surf zone
	float lace = smoothstep(0.66, 0.74, vnoise(p * vec2(0.8, 2.4) + vec2(t * 0.05, 0.0))) * smoothstep(30.0, 6.0, d) * 0.35;
	white = max(white, lace * smoothstep(0.3, 0.8, bub));
	vec3 foam_col = mix(vec3(0.66, 0.6, 0.75), vec3(1.0, 0.86, 0.74), clamp(n.y * 0.7 + bub * 0.5, 0.0, 1.0));
	col = mix(col, foam_col, white);
	col = haze(col, world_pos, CAMERA_POSITION_WORLD, 0.0028);
	ALBEDO = col;
}
