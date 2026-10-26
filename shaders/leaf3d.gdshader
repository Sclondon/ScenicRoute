// A real leaf on a bush (bush_builder.gd): a card cut to the kind's `shape` (0 pointed oval, 1 broad,
// 2 a bracken frond with its leaflets, 3 a lobed oak leaf), shaded as the whole bush is round, darker in
// its middle, glowing when the sun is behind it. Stirs in the wind. Lit by hand like everything else.
// UV x across the leaf, y along it. COLOR r the leaf's shade, g how far out in the bush.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 sun_dir = vec3(0.0, 0.35, -1.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.86, 0.55);
uniform vec3 color_a : source_color = vec3(0.4, 0.35, 0.13);
uniform vec3 color_b : source_color = vec3(0.6, 0.34, 0.1);
uniform vec3 color_dark : source_color = vec3(0.12, 0.1, 0.05);
uniform float shape = 0.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	vec3 root = MODEL_MATRIX[3].xyz;
	float t = TIME * 1.3 + root.x * 0.7 + root.z * 0.5;
	float up = max(VERTEX.y, 0.0);
	VERTEX += vec3(sin(t + VERTEX.y * 2.0), 0.0, cos(t * 0.8 + VERTEX.x * 2.0)) * 0.025 * up
		+ vec3(0.0, sin(TIME * 3.1 + VERTEX.x * 9.0 + VERTEX.z * 7.0) * 0.012 * up, 0.0);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = vec2(UV.x * 2.0 - 1.0, UV.y * 2.0 - 1.0);
	float t = p.y;
	bool inside;
	float rib = smoothstep(0.08, 0.0, abs(p.x));
	if (shape < 0.5) {
		inside = abs(p.x) < 0.95 * pow(max(1.0 - t * t, 0.0), 0.8) * (1.0 - 0.15 * t);
	} else if (shape < 1.5) {
		inside = abs(p.x) < 0.98 * sqrt(max(1.0 - t * t, 0.0)) * (1.0 - 0.3 * max(t, 0.0));
	} else if (shape < 2.5) {
		// a frond: a stalk, and leaflets off it in pairs, shorter towards the tip
		float along = UV.y;
		float f = fract(along * 11.0);
		float w = 0.95 * pow(1.0 - along, 0.6) * smoothstep(0.0, 0.12, along);
		float leaflet = w * (0.25 + 0.75 * sin(f * 3.1416));
		inside = abs(p.x) < 0.07 || (abs(p.x) < leaflet && abs(f - 0.5 - abs(p.x) * 0.35) < 0.42);
		rib = smoothstep(0.1, 0.0, abs(p.x));
	} else {
		float a = atan(p.x, p.y);
		float len = length(p * vec2(1.25, 1.0));
		inside = len < 0.8 + 0.18 * cos(a * 9.0) && t > -0.95;
	}
	if (!inside) {
		discard;
	}
	vec3 base = mix(color_a, color_b, COLOR.r);
	base = mix(base, base * 0.72, rib * 0.6);
	vec3 n = normalize(world_normal);
	vec3 sun = normalize(sun_dir);
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - world_pos);
	float wrap = clamp(dot(n, sun) * 0.5 + 0.5, 0.0, 1.0);
	float top = clamp(n.y * 0.5 + 0.5, 0.0, 1.0);
	float depth = COLOR.g;
	float back = pow(clamp(dot(-to_cam, sun), 0.0, 1.0), 3.0);
	vec3 col = mix(color_dark, base, 0.25 + 0.75 * depth * depth);
	col *= 0.5 + 0.55 * wrap * sun_color + 0.15 * top;
	col += base * base * sun_color * back * 0.7 * depth;
	ALBEDO = col;
}
