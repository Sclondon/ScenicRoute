// Glowing panels, drawn on a card by UV: the back bar's lit wall (mode 0), the DJ booth's level meters
// (mode 1), and a speaker's face with its cones kicking (mode 2).
shader_type spatial;
render_mode unshaded;

#include "res://shaders/velvet_moth/club.gdshaderinc"

uniform int mode = 0;
uniform vec2 cells = vec2(16.0, 6.0);

void fragment() {
	vec2 uv = UV;
	vec3 col;
	if (mode == 0) {
		// warm light behind frosted glass, brightest in the middle, with soft upright streaks
		float mid = 1.0 - pow(abs(uv.x - 0.5) * 2.0, 2.0) * 0.6;
		float v = 1.0 - pow(abs(uv.y - 0.55) * 2.0, 2.0) * 0.5;
		float streak = 0.85 + 0.15 * sin(uv.x * 90.0 + vnoise(uv * vec2(20.0, 2.0)) * 3.0);
		col = mix(vec3(0.9, 0.35, 0.12), vec3(1.0, 0.72, 0.4), v * mid) * mid * v * streak * 0.95;
	} else if (mode == 1) {
		// level meters jumping with the music
		vec2 q = uv * cells;
		vec2 c = floor(q);
		vec2 f = fract(q);
		float level = 0.25 + 0.55 * kick() * (0.6 + 0.4 * h21(vec2(c.x, floor(beat * 2.0))))
			+ 0.2 * sin(beat * 1.5 + c.x * 0.7);
		float lit = step((cells.y - 1.0 - c.y) / cells.y, level);
		vec3 tone = mix(vec3(0.2, 0.6, 1.0), vec3(1.0, 0.15, 0.6), (cells.y - 1.0 - c.y) / cells.y);
		float cellmask = step(0.12, f.x) * step(f.x, 0.88) * step(0.15, f.y) * step(f.y, 0.85);
		col = vec3(0.04, 0.01, 0.06) + tone * lit * cellmask * 1.1 + tone * 0.06 * cellmask;
	} else {
		// a speaker: a big cone and a small one, rings throbbing with the kick
		vec2 p = (uv - vec2(0.5, 0.6)) * vec2(1.0, 1.15);
		vec2 p2 = (uv - vec2(0.5, 0.15)) * vec2(1.0, 1.15);
		float r = length(p) / 0.4;
		float r2 = length(p2) / 0.09;
		float k = kick();
		col = vec3(0.03, 0.02, 0.04);
		col += vec3(0.25, 0.08, 0.3) * smoothstep(1.0, 0.95, r) * (0.3 + 0.7 * smoothstep(0.6, 1.0, r)) * (0.6 + 0.6 * k);
		col += vec3(0.6, 0.15, 0.6) * smoothstep(0.04, 0.0, abs(r - 1.0 + k * 0.04)) * (0.4 + k);
		col += vec3(0.08) * smoothstep(0.3, 0.2, r) * (1.0 + k);
		col += vec3(0.4, 0.15, 0.5) * smoothstep(0.1, 0.0, abs(r2 - 1.0)) * 0.6;
		vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
		col += vec3(1.0, 0.92, 0.98) * specks(world, normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz));
	}
	ALBEDO = col;
}
