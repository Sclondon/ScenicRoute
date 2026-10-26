// The land round the harbour: pale limestone where it is steep, in courses and cracks; dark maquis and
// terraces of lemon and olive where it is gentler; worn paving on the quay; dark wet rock along the sea.
shader_type spatial;
render_mode cull_back;

#include "res://shaders/caffe_del_porto/light.gdshaderinc"

uniform float sea_level = -1.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 p = world_pos;
	vec3 n = normalize(world_normal);
	float fw = length(fwidth(p.xz));
	float big = fbm(p.xz * 0.03);
	float mid = fbm(p.xz * 0.15 + p.y * 0.1);
	v_gloss = 0.0;
	// rock: warm pale limestone in rough courses, cracks and dark streaks running down
	vec3 rock = mix(vec3(0.66, 0.56, 0.44), vec3(0.5, 0.45, 0.4), mid);
	float course = fbm(vec2((p.x + p.z) * 0.08, p.y * 0.9));
	rock *= 0.8 + course * 0.35;
	rock *= 1.0 - 0.25 * smoothstep(0.62, 0.7, vnoise(vec2((p.x - p.z) * 0.6, p.y * 0.12))) * (1.0 - smoothstep(0.3, 1.0, fw));
	// green: dark maquis with lighter terraces of lemon and olive following the contours
	vec3 green = mix(vec3(0.2, 0.3, 0.12), vec3(0.34, 0.42, 0.16), mid);
	float terrace = smoothstep(0.55, 0.75, abs(fract(p.y / 2.6 + big * 0.6) - 0.5) * 2.0);
	green = mix(green, vec3(0.42, 0.48, 0.2), terrace * 0.5 * smoothstep(0.4, 0.6, big));
	green *= 0.75 + vnoise(p.xz * 0.9) * 0.4;
	float steep = smoothstep(0.62, 0.8, n.y + (mid - 0.5) * 0.35);
	vec3 col = mix(rock, green, steep);
	// a dark band of wet rock, weed and barnacles just over the sea
	float wet = 1.0 - smoothstep(sea_level + 0.15, sea_level + 0.9 + mid * 0.6, p.y);
	col = mix(col, vec3(0.2, 0.2, 0.16), wet * 0.85);
	// the quay: worn grey paving
	float quay = smoothstep(0.75, 0.9, n.y) * (1.0 - smoothstep(0.08, 0.3, abs(p.y + 0.02)));
	vec2 q = p.xz / vec2(0.6, 0.4);
	q.x += floor(q.y) * 0.5;
	vec2 f = fract(q);
	float edge = min(min(f.x, 1.0 - f.x) * 0.6, min(f.y, 1.0 - f.y));
	vec3 pave = vec3(0.66, 0.62, 0.56) * (0.88 + hash(floor(q)) * 0.18);
	pave *= mix(0.7, 1.0, smoothstep(0.02, 0.08, edge) + smoothstep(0.05, 0.2, fw));
	col = mix(col, pave, quay);
	v_brush = (vnoise(p.xz * 0.7 + p.y) - 0.5) * 0.3;
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
