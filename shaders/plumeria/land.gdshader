// The land: the beach (dry sand rippled by the wind, peach where the low sun catches it and lilac in the
// lee; wet sand by the water that mirrors the sky and the sun; the wash running up it in a thin sheet with
// lace at its edge, then sliding back), the grass behind it, and the green fluted mountains inland
// catching the last pink light. COLOR: r grass, g mountainside.
shader_type spatial;
render_mode unshaded, fog_disabled;

#include "res://shaders/plumeria/common.gdshaderinc"

varying vec3 world_pos;
varying vec3 world_normal;
varying vec4 tint;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	tint = COLOR;
}

void fragment() {
	vec2 p = world_pos.xz;
	vec3 n = normalize(world_normal);
	float d = p.y - shore_z(p.x); // metres up the beach from the still water
	float dist = length(world_pos - CAMERA_POSITION_WORLD);
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - world_pos);
	float t = TIME - wave_t0;
	// --- dry sand ---
	float ripple = sin(p.x * 0.4 + p.y * 3.2 + vnoise(p * 0.7) * 5.0) * 0.5 + 0.5;
	float grain = vnoise(p * 9.0) * 0.5 + vnoise(p * 0.6) * 0.5;
	vec3 sand = vec3(0.95, 0.8, 0.62) * (0.92 + grain * 0.12);
	// ripple faces towards the sun catch it, the others lie in lilac shadow
	float catch_sun = clamp(n.z * -1.0 * 0.5 + 0.5, 0.0, 1.0);
	float lit = 0.32 + 0.4 * ripple * smoothstep(80.0, 10.0, dist) + 0.25 * catch_sun;
	vec3 col = mix(sand * SHADE * 1.25, sand * SUN_COL * 1.05, clamp(lit, 0.0, 1.0));
	// --- the wet sand and the wash ---
	float reach;
	float age;
	float edge = swash(t, reach, age);
	float near = 1.0 - smoothstep(150.0, 260.0, abs(p.x));
	float wet = (1.0 - smoothstep(reach * 0.85, reach + 0.6, d)) * near;
	wet = max(wet, smoothstep(1.0, -0.5, d));
	vec3 r = reflect(-to_cam, vec3(0.0, 1.0, 0.0) + vec3(vnoise(p * 3.0) - 0.5, 0.0, vnoise(p * 3.0 + 9.0) - 0.5) * 0.06);
	float fres = 0.25 + 0.75 * pow(1.0 - clamp(to_cam.y, 0.0, 1.0), 5.0);
	vec3 wet_col = mix(sand * vec3(0.5, 0.42, 0.42), sky_color(r) * 0.85, fres * 0.85);
	wet_col += SUN_COL * pow(max(dot(r, SUN), 0.0), 40.0) * 0.9;
	col = mix(col, wet_col, wet);
	// the sheet of water running up and sliding back, with its lace edge
	float under = smoothstep(edge + 0.05, edge - 0.25, d) * near;
	vec3 sheet = mix(vec3(0.2, 0.36, 0.36), sky_color(r), fres);
	sheet += SUN_COL * pow(max(dot(r, SUN), 0.0), 60.0) * 1.5;
	col = mix(col, sheet, under * 0.85);
	float lace_n = vnoise(vec2(p.x * 1.4, d * 2.0) + vec2(0.0, -t * 0.5)) * 0.6 + vnoise(p * 6.0) * 0.4;
	float lace = smoothstep(0.45, 0.0, abs(d - edge + 0.12)) * smoothstep(0.3, 0.7, lace_n);
	// foam left behind as it draws back, breaking up
	float left = under * smoothstep(0.55, 0.85, lace_n) * smoothstep(0.9, 0.3, age);
	col = mix(col, vec3(1.0, 0.9, 0.82), clamp(lace * (1.0 - age * 0.6) + left * 0.6, 0.0, 1.0) * near);
	// --- grass behind the beach, and the mountains ---
	vec3 grass = vec3(0.28, 0.42, 0.2) * (0.8 + vnoise(p * 0.3) * 0.4);
	float gl = clamp(dot(n, SUN) * 2.0 + 0.45, 0.0, 1.0);
	vec3 grass_col = mix(grass * SHADE * 1.1, grass * SUN_COL * 1.2, gl);
	col = mix(col, grass_col, tint.r);
	// the mountains: deep green fluted cliffs, pink-gold where they face the setting sun
	float around = atan(p.x, p.y);
	float wob = vnoise(vec2(around * 40.0, world_pos.y * 0.02)) * 3.0;
	float flute = vnoise(vec2(around * 300.0 + wob, world_pos.y * 0.05)) * 0.55 + vnoise(vec2(around * 70.0, world_pos.y * 0.015)) * 0.45;
	vec3 green = mix(vec3(0.12, 0.26, 0.15), vec3(0.32, 0.46, 0.22), flute);
	float ml = clamp(dot(n, SUN) * 1.4 + 0.35 + (flute - 0.5) * 0.55, 0.0, 1.0);
	vec3 mount = mix(green * vec3(0.5, 0.5, 0.78), green * vec3(1.5, 1.05, 0.85) + vec3(0.22, 0.07, 0.05), smoothstep(0.3, 0.75, ml));
	// bare red earth showing on the steepest walls
	mount = mix(mount, vec3(0.55, 0.32, 0.25) * (0.6 + ml * 0.6), smoothstep(0.55, 0.3, n.y) * 0.35 * flute);
	col = mix(col, mount, tint.g);
	col = haze(col, world_pos, CAMERA_POSITION_WORLD, 0.0027);
	ALBEDO = col;
}
