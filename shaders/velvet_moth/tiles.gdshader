// The dance floor: frosted glass tiles lit from under, a metre square, in patterns that change on the
// beat and every four bars (tile_color), with dark grout and the mirror ball's specks.
shader_type spatial;
render_mode unshaded;

#include "res://shaders/velvet_moth/club.gdshaderinc"

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 q = wp.xz - FLOOR_RECT.xy;
	vec2 ij = floor(q);
	vec2 f = fract(q) - 0.5;
	vec3 c = tile_color(ij);
	float edge = max(abs(f.x), abs(f.y));
	float w = fwidth(edge) + 0.002;
	float grout = smoothstep(0.455 - w, 0.455 + w, edge);
	// brighter in the middle of each tile, frosted
	float glow = 1.15 - edge * 0.9 + (vnoise(q * 9.0) - 0.5) * 0.12;
	vec3 col = c * glow * 1.6;
	col = mix(col, vec3(0.03, 0.01, 0.05) + c * 0.15, grout);
	col += vec3(1.0, 0.92, 0.98) * specks(wp, vec3(0, 1, 0)) * 0.6;
	ALBEDO = col;
}
