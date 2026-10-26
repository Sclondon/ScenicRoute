// The sea, painted: cobalt out deep, turquoise over the rocks and the harbour floor (COLOR.r), foam where
// it breaks on the stones (COLOR.g), ripples running in before the breeze, and the sun glittering in a
// path out to the horizon (from a lower sun than the real one, so the path lies where you look). It is
// see-through where you look across it, and what shows through is the reflection under it (sea_under,
// and boats and houses turned upside down).
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_opaque;

uniform vec3 glint_dir = vec3(0.1, 0.25, -1.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.82);
uniform vec3 deep : source_color = vec3(0.03, 0.2, 0.42);
uniform vec3 mid : source_color = vec3(0.04, 0.33, 0.52);
uniform vec3 shallow : source_color = vec3(0.1, 0.55, 0.56);
uniform vec3 foam_color : source_color = vec3(0.92, 0.95, 0.95);

varying vec3 world_pos;
varying vec4 vcol;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float waves(vec2 p, float detail) {
	// long low swells coming in, ripples on them across the breeze
	float w = sin(p.y * 0.35 + p.x * 0.08 + TIME * 0.9) * 0.5;
	w += vnoise(p * vec2(0.5, 1.4) + vec2(0.0, TIME * 0.45)) * 0.8;
	w += vnoise(p * vec2(1.6, 2.6) + vec2(TIME * 0.2, TIME * 0.9)) * 0.45 * detail;
	w += vnoise(p * vec2(4.1, 3.3) - vec2(TIME * 0.5, TIME * 0.3)) * 0.22 * detail;
	return w;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vcol = COLOR;
}

void fragment() {
	vec2 p = world_pos.xz;
	vec3 cam = CAMERA_POSITION_WORLD;
	float dist = length(cam.xz - p);
	float fw = length(fwidth(p));
	float detail = 1.0 - smoothstep(0.15, 0.9, fw);
	float e = 0.12;
	float h = waves(p, detail);
	float hx = waves(p + vec2(e, 0.0), detail);
	float hz = waves(p + vec2(0.0, e), detail);
	float amp = mix(0.12, 0.45, detail);
	vec3 n = normalize(vec3((h - hx) / e * amp, 1.0, (h - hz) / e * amp));
	vec3 to_cam = normalize(cam - world_pos);
	float ndv = clamp(dot(to_cam, n), 0.0, 1.0);
	float fresnel = 0.03 + 0.97 * pow(1.0 - ndv, 5.0);
	// the water's own colour: deep blue far out, turquoise over the shallows, a little lighter on the crests
	vec3 body = mix(deep, mid, smoothstep(30.0, 120.0, dist) * 0.0 + 0.4);
	body = mix(body, deep, smoothstep(60.0, 260.0, dist) * 0.7);
	body = mix(body, shallow, vcol.r);
	body *= 0.88 + 0.28 * smoothstep(0.6, 1.5, h) * detail;
	float alpha = 1.0 - clamp(fresnel * 1.05, 0.0, 0.7);
	vec3 col = body;
	// the sun glittering: a path of flecks out to the horizon, twinkling
	vec3 v = normalize(world_pos - cam);
	vec3 vr = vec3(v.x, -v.y, v.z);
	vec3 g = normalize(glint_dir);
	float az = atan(vr.x, -vr.z) - atan(g.x, -g.z);
	float el = asin(clamp(vr.y, -1.0, 1.0)) - asin(g.y);
	// a path narrow at the horizon, widening towards you and fading as you look down
	float down = max(vr.y, 0.0);
	float path = exp(-pow(az / (0.04 + 0.6 * down), 2.0) - pow(down / 0.3, 2.0));
	path += 0.25 * exp(-pow(az / 0.4, 2.0) - pow(down / 0.2, 2.0));
	// flecks: a few pixels each wherever they are, each flashing on its own clock
	vec2 fp = p * 60.0 / (1.0 + dist * 0.25);
	fp.y *= 1.0 + dist * 0.02;
	vec2 cell = floor(fp);
	vec2 in_cell = fract(fp) - 0.5;
	float tw = fract(TIME * (0.6 + hash(cell) * 1.2) + hash(cell + 3.1));
	float spark = smoothstep(0.42, 0.1, length(in_cell)) * smoothstep(0.5, 0.0, abs(tw - 0.5)) * step(0.55, hash(cell + 7.7));
	float fleck = spark * smoothstep(0.45, 1.0, h + (vnoise(fp * 0.37) - 0.5));
	float sheen = path * (0.25 + 0.75 * smoothstep(0.7, 1.4, h));
	float glit = clamp(fleck * path * 2.4 + sheen * 0.5, 0.0, 1.6);
	col = mix(col, sun_color * 1.6, clamp(glit, 0.0, 1.0));
	col += sun_color * max(glit - 1.0, 0.0) * 1.5;
	alpha = max(alpha, clamp(glit, 0.0, 1.0));
	// foam where it breaks on the rocks and the breakwater, breathing with the swell
	float surge = 0.5 + 0.5 * sin(TIME * 0.9 + p.y * 0.35 + p.x * 0.08);
	float foam = vcol.g * smoothstep(0.35, 0.75, vnoise(p * 1.6 + TIME * 0.2) * 0.7 + surge * 0.5 + vcol.g * 0.3);
	col = mix(col, foam_color, foam);
	alpha = max(alpha, foam);
	ALBEDO = col;
	ALPHA = alpha;
}
