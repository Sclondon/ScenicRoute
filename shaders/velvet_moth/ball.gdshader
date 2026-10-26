// The mirror ball: little square mirrors in rings, turning with the specks it throws, each catching the
// pin spot and the floor in its own way, a few flashing white as they come round.
shader_type spatial;
render_mode unshaded;

#include "res://shaders/velvet_moth/club.gdshaderinc"

varying vec3 ln;

void vertex() {
	ln = NORMAL;
}

void fragment() {
	vec3 d = normalize(ln);
	float a = beat * 6.2831853 / 64.0;
	float ca = cos(a), sa = sin(a);
	vec3 r = vec3(ca * d.x - sa * d.z, d.y, sa * d.x + ca * d.z);
	float rows = 18.0;
	float lat = asin(clamp(r.y, -1.0, 1.0)) / 3.14159265 * rows;
	float cols = max(floor(2.0 * rows * cos((floor(lat) + 0.5) / rows * 3.14159265)), 3.0);
	float lon = (atan(r.z, r.x) / 6.2831853 + 0.5) * cols;
	vec2 cell = vec2(floor(lat), floor(lon));
	vec2 f = vec2(fract(lat), fract(lon));
	float grout = smoothstep(0.38, 0.5, max(abs(f.x - 0.5), abs(f.y - 0.5)));
	float h = h21(cell);
	// each mirror reflects something: the dark, the floor, the pin spot
	vec3 world_n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 col = vec3(0.12, 0.1, 0.16) + floor_glow() * clamp(-world_n.y + 0.3, 0.0, 1.0) * 1.2 * h;
	col += vec3(0.5, 0.45, 0.55) * pow(h, 3.0);
	float glint = pow(h21(cell + floor(beat * 2.0) * 0.37), 30.0);
	col += vec3(1.5, 1.4, 1.5) * glint;
	ALBEDO = mix(col, vec3(0.03), grout);
}
