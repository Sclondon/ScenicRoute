// Things turned upside down under the sea, seen through it as their reflections: their colours, lit as
// they are above (sun side or shade side), broken into wavering bands that come apart further down.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;

uniform vec3 sun_dir = vec3(0.4, 0.75, -0.55);
uniform vec3 shade : source_color = vec3(0.55, 0.62, 0.78);
uniform float sea_level = -1.0;
uniform float reach = 8.0;
uniform vec3 tint : source_color = vec3(1.0);

varying vec3 world_pos;
varying vec3 world_normal;
varying vec3 v_custom;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_custom = INSTANCE_CUSTOM.rgb;
}

void fragment() {
	float below = sea_level - world_pos.y;
	if (below < 0.0) {
		discard;
	}
	float k = clamp(below / reach, 0.0, 1.0);
	// wavering bands: the further under, the more broken
	float wob = sin(world_pos.x * 1.7 + TIME * 1.3) * 0.08 + sin(world_pos.z * 1.1 - TIME * 0.9) * 0.08;
	float band = vnoise(vec2(world_pos.x * 0.6 + world_pos.z * 0.6 + sin(TIME * 0.7 + world_pos.y * 3.0) * 0.4, (world_pos.y + wob) * 4.0 - TIME * 0.4));
	if (band < k * 0.85 - 0.05) {
		discard;
	}
	vec3 base = COLOR.rgb * tint;
	int kind = int(UV2.x + 0.5);
	if (COLOR.a < 0.5) {
		base = v_custom;
	}
	if (kind == 10) {
		base *= 0.35;
	}
	vec3 n = normalize(world_normal) * vec3(1.0, -1.0, 1.0);
	float lit = smoothstep(-0.05, 0.3, dot(n, normalize(sun_dir)));
	vec3 col = base * mix(shade * 0.7, vec3(1.05, 1.0, 0.92), lit);
	col *= 0.78 + 0.22 * band;
	ALBEDO = col;
}
