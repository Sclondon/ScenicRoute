// The forest floor: a pale dirt path wandering through leaf litter, with sun coming through the
// canopy in patches that drift as the wind moves the leaves. The path's line must match `Amberwood.path_x`.
shader_type spatial;
render_mode unshaded;

uniform vec3 sun_dir = vec3(0.0, 0.35, -1.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.84, 0.52);
uniform vec3 dirt : source_color = vec3(0.55, 0.42, 0.28);
uniform vec3 dirt_dark : source_color = vec3(0.3, 0.21, 0.13);
uniform vec3 litter_a : source_color = vec3(0.62, 0.36, 0.14);
uniform vec3 litter_b : source_color = vec3(0.42, 0.25, 0.11);
uniform vec3 litter_c : source_color = vec3(0.72, 0.52, 0.2);
uniform vec3 shadow : source_color = vec3(0.1, 0.07, 0.05);
uniform float path_width = 1.7;

varying vec3 world_pos;
varying vec3 world_normal;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.03 + 7.1) * 0.28 + vnoise(p * 4.1 + 3.3) * 0.17;
}

float path_x(float z) {
	return 2.2 * sin(z * 0.055) + 1.2 * sin(z * 0.13 + 1.0);
}

// nearest leaf dab: x its shade, y how close to its middle
vec2 dabs(vec2 p) {
	vec2 gi = floor(p);
	vec2 gf = fract(p);
	float best = 8.0;
	vec2 id = vec2(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 o = vec2(float(i), float(j));
			vec2 d = o + hash2(gi + o) - gf;
			d.x *= 1.6;
			float dd = dot(d, d);
			if (dd < best) { best = dd; id = gi + o; }
		}
	}
	return vec2(hash(id), 1.0 - sqrt(best));
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = world_pos.xz;
	float off = abs(p.x - path_x(p.y));
	float wobble = (fbm(p * 0.6) - 0.5) * 0.9;
	float on_path = 1.0 - smoothstep(path_width - 0.25, path_width + 0.35, off + wobble);
	// two ruts down the path, worn paler
	float rut = smoothstep(0.35, 0.0, abs(off - 0.55)) * on_path;

	vec2 d = dabs(p * 3.2);
	float shade_id = d.x;
	vec3 litter = shade_id < 0.4 ? litter_a : (shade_id < 0.75 ? litter_b : litter_c);
	litter *= 0.75 + 0.4 * d.y;
	litter = mix(litter, dirt_dark, smoothstep(0.55, 0.85, fbm(p * 0.35)) * 0.6);

	vec3 path = mix(dirt_dark, dirt, 0.55 + 0.45 * fbm(p * 1.7));
	path = mix(path, dirt * 1.15, rut * 0.35);
	// a few leaves lie on the path too
	float stray = step(0.8, fract(shade_id * 7.31)) * smoothstep(0.3, 0.45, d.y);
	path = mix(path, litter, stray * 0.85);

	vec3 col = mix(litter, path, on_path);

	// sun through the canopy: drifting patches, more over the path where the trees open
	vec2 drift = vec2(TIME * 0.05, TIME * 0.03);
	float dapple = fbm(p * 0.45 + drift) * 0.7 + fbm(p * 1.3 - drift * 1.7) * 0.3;
	float open = 1.0 - smoothstep(1.0, 9.0, off);
	float sunlit = smoothstep(0.58 - open * 0.12, 0.7 - open * 0.1, dapple);
	// deep shade under the wood away from the path
	float gloom = smoothstep(3.0, 14.0, off);
	vec3 n = normalize(world_normal);
	float wrap = clamp(dot(n, normalize(sun_dir)) * 0.5 + 0.5, 0.0, 1.0);
	vec3 lit = col * mix(0.42, 0.62, wrap);
	lit = mix(lit, col * sun_color * 1.25, sunlit * (1.0 - gloom * 0.8));
	lit = mix(lit, lit * shadow * 4.0, gloom * 0.55);
	ALBEDO = lit;
}
