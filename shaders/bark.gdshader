// Trunks and branches, painted: dark bark with long vertical streaks, a warm edge on the side to the sun,
// darker at the foot. `birch` gives pale bark with dark bands and scars. Lit by hand, like the leaves.
// UV.x runs round the trunk, UV.y up it in metres; COLOR.r is how far out on the tree (0 trunk foot .. 1 twig).
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 sun_dir = vec3(0.0, 0.35, -1.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.82, 0.5);
uniform vec3 bark : source_color = vec3(0.24, 0.17, 0.12);
uniform vec3 bark_dark : source_color = vec3(0.07, 0.05, 0.04);
uniform float birch = 0.0;
uniform float moss = 0.0;

varying vec3 world_normal;
varying vec3 world_pos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec3 sun = normalize(sun_dir);
	float u = UV.x;
	float h = UV.y;
	// streaks: stretched noise round the trunk
	float streak = vnoise(vec2(u * 18.0, h * 0.9)) * 0.6 + vnoise(vec2(u * 46.0, h * 2.5)) * 0.4;
	vec3 col = mix(bark_dark, bark, smoothstep(0.25, 0.8, streak));
	if (birch > 0.5) {
		vec3 pale = vec3(0.78, 0.72, 0.6);
		float band = step(0.78, vnoise(vec2(u * 3.0, h * 2.2))) * step(0.3, vnoise(vec2(u * 9.0, h * 0.7)));
		float scar = step(0.86, vnoise(vec2(u * 20.0, h * 6.0)));
		col = mix(pale * (0.75 + 0.25 * streak), bark_dark * 1.3, max(band, scar * 0.8));
	}
	// moss on the side away from the sun and low down
	float mossy = moss * smoothstep(0.1, 0.6, -dot(n, sun) + 0.2) * smoothstep(4.0, 0.5, h) * step(0.45, vnoise(vec2(u * 10.0, h * 3.0)));
	col = mix(col, vec3(0.32, 0.33, 0.12), mossy * 0.8);
	// light: a soft wrap, a bright rim on the sun side, the foot in shadow
	float wrap = clamp(dot(n, sun) * 0.6 + 0.4, 0.0, 1.0);
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - world_pos);
	float rim = pow(1.0 - clamp(dot(n, to_cam), 0.0, 1.0), 3.0) * clamp(dot(n, sun) + 0.5, 0.0, 1.0);
	float foot = mix(0.55, 1.0, smoothstep(0.0, 2.5, h));
	vec3 lit = col * (0.42 + 0.75 * wrap * sun_color) * foot;
	lit += sun_color * rim * 0.5 * (0.6 + streak * 0.4);
	ALBEDO = lit;
}
