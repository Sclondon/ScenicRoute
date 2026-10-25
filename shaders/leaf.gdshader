// Single leaves, cut from a card: an oak's lobes, a maple's points or a plain ellipse, with a midrib.
// `falling` makes them drift down from the canopy, swinging and tumbling, and start again at the top
// (each instance's origin is the top of its fall). Otherwise they lie where they were put.
// INSTANCE_CUSTOM: x shape (0 oak, .5 maple, 1 plain), y hue, z brightness, w seed.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 sun_dir = vec3(0.0, 0.35, -1.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.86, 0.55);
uniform vec3 gold : source_color = vec3(0.95, 0.7, 0.25);
uniform vec3 orange : source_color = vec3(0.86, 0.42, 0.12);
uniform vec3 rust : source_color = vec3(0.5, 0.2, 0.08);
uniform vec3 brown : source_color = vec3(0.36, 0.24, 0.13);
uniform float falling = 0.0;
uniform float fall_height = 11.0;

varying vec4 custom;
varying vec3 world_pos;
varying float facing;

mat3 rot(vec3 axis, float a) {
	axis = normalize(axis);
	float s = sin(a);
	float c = cos(a);
	float oc = 1.0 - c;
	return mat3(
		vec3(oc * axis.x * axis.x + c, oc * axis.x * axis.y + axis.z * s, oc * axis.z * axis.x - axis.y * s),
		vec3(oc * axis.x * axis.y - axis.z * s, oc * axis.y * axis.y + c, oc * axis.y * axis.z + axis.x * s),
		vec3(oc * axis.z * axis.x + axis.y * s, oc * axis.y * axis.z - axis.x * s, oc * axis.z * axis.z + c));
}

void vertex() {
	custom = INSTANCE_CUSTOM;
	if (falling > 0.5) {
		float seed = custom.w;
		float period = 9.0 + seed * 9.0;
		float t = fract(TIME / period + seed * 7.13);
		float sw = TIME * (0.9 + seed * 0.8) + seed * 30.0;
		// swing side to side like a falling leaf, rocking with each swing
		vec3 offset = vec3(sin(sw) * 0.9 + t * 2.5, -t * fall_height, cos(sw * 0.7) * 0.6 - t * 1.0);
		mat3 r = rot(vec3(0.3, 1.0, 0.2), sw * 0.5 + seed * 6.0) * rot(vec3(1.0, 0.0, 0.3), sin(sw) * 1.1 + 0.7);
		float grow = smoothstep(0.0, 0.06, t) * smoothstep(1.0, 0.9, t);
		VERTEX = r * vec3(VERTEX.x, VERTEX.z, VERTEX.y) * grow + offset;
		NORMAL = r * vec3(0.0, 1.0, 0.0);
	}
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	facing = dot(wn, normalize(sun_dir));
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	p.y = -p.y;
	float shape = custom.x;
	float a = atan(p.x, p.y);
	float r = length(p * vec2(1.0, 0.8));
	float edge;
	if (shape < 0.33) {
		// oak: a long leaf with rounded lobes, narrow at the stalk
		float len = length(p * vec2(1.7, 0.95));
		float lobes = 0.82 + 0.16 * cos(a * 9.0);
		edge = step(len, lobes) * step(-0.95, p.y);
		r = len;
	} else if (shape < 0.66) {
		// maple: five points
		float pts = 0.55 + 0.4 * pow(abs(cos(a * 2.5)), 3.0);
		edge = step(r, pts) * step(-0.9, p.y + abs(p.x) * 0.2);
	} else {
		float len = length(p * vec2(2.0, 1.0));
		edge = step(len, 0.95 - 0.25 * max(-p.y, 0.0));
		r = len;
	}
	// stalk
	edge = max(edge, step(abs(p.x), 0.04) * step(p.y, -0.6) * step(-1.0, p.y));
	if (edge < 0.5) {
		discard;
	}
	float hue = custom.y;
	vec3 col = hue < 0.33 ? mix(gold, orange, hue * 3.0) : (hue < 0.66 ? mix(orange, rust, (hue - 0.33) * 3.0) : mix(rust, brown, (hue - 0.66) * 3.0));
	// midrib and veins a little darker, the edge a little browner
	float rib = smoothstep(0.05, 0.0, abs(p.x)) * step(p.y, 0.8);
	col = mix(col, col * 0.7, rib);
	col = mix(col, brown, smoothstep(0.5, 1.0, r) * 0.35);
	float light = custom.z;
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - world_pos);
	float back = pow(clamp(dot(-to_cam, normalize(sun_dir)), 0.0, 1.0), 4.0);
	vec3 lit = col * (0.45 + 0.55 * light) * mix(vec3(1.0), sun_color, 0.5);
	lit += col * sun_color * (abs(facing) * 0.35 * light + back * 0.7) * falling;
	ALBEDO = lit;
}
