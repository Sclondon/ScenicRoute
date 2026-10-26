// Still water and running water, painted: dark peaty depths, the warm sky in it where it is seen low,
// ripples drifting (and rings now and then where something touches the pond), and the low sun glittering
// on it. `flow` 1 for the stream: its ripples run down it (UV.y is metres along it, UV.x across) and it
// is paler where it runs over stones at its edges. UV for the pond is world x, z.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 sun_dir = vec3(0.0, 0.35, -1.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.86, 0.55);
uniform vec3 deep : source_color = vec3(0.03, 0.035, 0.03);
uniform vec3 shallow : source_color = vec3(0.28, 0.24, 0.14);
uniform vec3 sky : source_color = vec3(0.76, 0.66, 0.48);
uniform vec3 sky_low : source_color = vec3(0.2, 0.17, 0.1);
uniform float flow = 0.0;
uniform vec2 pond = vec2(0.0);
uniform vec2 pond_size = vec2(5.0);

varying vec3 world_pos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float waves(vec2 p) {
	if (flow > 0.5) {
		vec2 q = vec2(p.x * 3.0, p.y * 1.4 - TIME * 1.6);
		return vnoise(q) * 0.6 + vnoise(q * 2.3 + vec2(0.0, -TIME * 1.2)) * 0.4;
	}
	vec2 d = vec2(TIME * 0.05, TIME * 0.03);
	float w = vnoise(p * 1.3 + d) * 0.6 + vnoise(p * 3.1 - d * 2.0) * 0.4;
	// rings spreading where a frog or a leaf touched it
	for (int i = 0; i < 3; i++) {
		float period = 5.0 + float(i) * 2.3;
		float cycle = floor(TIME / period + float(i) * 0.37);
		float age = fract(TIME / period + float(i) * 0.37) * period;
		vec2 c = vec2(hash(vec2(cycle, float(i))) - 0.5, hash(vec2(float(i), cycle)) - 0.5) * pond_size * 1.4 + pond;
		float r = distance(p, c);
		w += sin((r - age * 0.6) * 18.0) * smoothstep(0.25, 0.0, abs(r - age * 0.6)) * exp(-age * 0.7) * 0.6;
	}
	return w;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = UV;
	float e = 0.05;
	float h = waves(p);
	vec3 n = normalize(vec3((h - waves(p + vec2(e, 0.0))) * 3.0, 1.0, (h - waves(p + vec2(0.0, e))) * 3.0));
	if (flow > 0.5) {
		// the stream's UV runs along it: turn the ripple's slope into the world roughly
		n = normalize(vec3(n.x * 0.5, 1.0, n.z * 0.5));
	}
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - world_pos);
	float fresnel = pow(1.0 - clamp(dot(to_cam, n), 0.0, 1.0), 3.0);
	vec3 r = reflect(-to_cam, n);
	vec3 reflected = mix(sky_low, sky, smoothstep(-0.05, 0.4, r.y));
	vec3 col = mix(mix(deep, shallow, flow * 0.6), reflected, 0.1 + 0.45 * fresnel);
	// the sun glittering
	float glint = pow(max(dot(r, normalize(sun_dir)), 0.0), 80.0);
	col += sun_color * glint * 2.2;
	if (flow > 0.5) {
		float edge = smoothstep(0.25, 0.0, min(UV.x, 1.0 - UV.x));
		col = mix(col, shallow * 1.4, edge * 0.5 + smoothstep(0.7, 0.9, h) * 0.25);
	}
	ALBEDO = col;
}
