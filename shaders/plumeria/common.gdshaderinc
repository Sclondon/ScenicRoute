// The Plumeria Beach Club: what every one of its shaders shares. The sun going down over the sea (it must
// match Plumeria.SUN_DIR), the sky's colour in any direction (so the haze on far things, the sea's
// reflections and the sky itself all agree), the line of the shore, and the surf's clock.

const vec3 SUN = vec3(-0.0995, 0.0448, -0.9940); // normalize(-0.1, 0.045, -1.0)
const vec3 SUN_COL = vec3(1.0, 0.74, 0.42);
// the shadow side of things: the sky's violet, warmed a little by the sand
const vec3 SHADE = vec3(0.42, 0.36, 0.52);
const float SEA_Y = -0.45;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

// The sky's colour looking along `d` (without the sun's disc, clouds or stars): gold and orange low
// towards the sun, peach and rose along the horizon round the sides, lavender behind with the pink band
// over the earth's shadow, deepening to blue overhead.
vec3 sky_color(vec3 d) {
	d = normalize(d);
	float up = clamp(d.y, 0.0, 1.0);
	vec2 h = normalize(d.xz + vec2(0.0001));
	float a = dot(h, normalize(SUN.xz)) * 0.5 + 0.5; // 1 towards the sun, 0 behind
	vec3 hor_back = vec3(0.62, 0.55, 0.72);
	vec3 hor_side = vec3(0.98, 0.66, 0.58);
	vec3 hor_sun = vec3(1.0, 0.72, 0.36);
	vec3 hor = mix(hor_back, hor_side, smoothstep(0.1, 0.7, a));
	hor = mix(hor, hor_sun, pow(a, 5.0));
	vec3 mid = mix(vec3(0.46, 0.44, 0.7), vec3(0.86, 0.52, 0.55), pow(a, 1.6));
	vec3 zenith = vec3(0.2, 0.25, 0.5);
	vec3 col = mix(hor, mid, smoothstep(0.0, 0.22, up));
	col = mix(col, zenith, smoothstep(0.18, 0.95, up));
	// the belt of Venus: a pink band over the dusk behind
	float belt = smoothstep(0.03, 0.1, up) * smoothstep(0.32, 0.12, up) * pow(1.0 - a, 1.5);
	col = mix(col, vec3(0.9, 0.62, 0.7), belt * 0.45);
	// the earth's shadow, a slate band right on the horizon behind
	col = mix(col, vec3(0.45, 0.45, 0.62), smoothstep(0.05, 0.0, up) * pow(1.0 - a, 2.0) * 0.5);
	// the glow round the low sun
	float towards = max(dot(d, SUN), 0.0);
	col += vec3(1.0, 0.62, 0.3) * (pow(towards, 6.0) * 0.16 + pow(towards, 80.0) * 0.28);
	return col;
}

// Far things fade into the sky behind them: the colour of the sky just over the horizon that way, more
// the further off (and more down low, where the air is thick with sea spray).
vec3 haze(vec3 col, vec3 world_pos, vec3 cam, float density) {
	vec3 to = world_pos - cam;
	float dist = length(to);
	vec3 d = to / max(dist, 0.001);
	vec3 sky = sky_color(vec3(d.x, max(d.y, 0.0) * 0.35 + 0.01, d.z));
	float low = exp(-max(world_pos.y, 0.0) * 0.01);
	float f = 1.0 - exp(-dist * density * (0.6 + 0.6 * low));
	return mix(col, sky, clamp(f, 0.0, 1.0));
}

// The line of the still water on the sand, as z for an x (Plumeria.shore_z must match).
float shore_z(float x) {
	return -19.0 - 0.0005 * x * x - 3.0 * sin(x * 0.015 + 0.5);
}

// --- the surf ---
// A wave reaches the sand every PERIOD seconds, in threes of different sizes (the surf's sound is baked
// to the same 24 s round). `wave_t0` is when the sound started, so the crashes are heard as they are seen.
const float PERIOD = 8.0;
const float SPEED = 4.5; // metres a second shoreward
const float BREAK_AT = 13.0; // metres out, for a wave of size 1
uniform float wave_t0 = 0.0;

float wave_size(float k) {
	float m = mod(k, 3.0);
	return m < 0.5 ? 1.0 : (m < 1.5 ? 0.72 : 0.86);
}

// How tall the surf is at `d` metres out from the still waterline; `foam` the white water there and
// `face` how much of it is the steep face of a wave about to break (lit through from behind).
float surf(float d, float t, out float foam, out float face) {
	foam = 0.0;
	face = 0.0;
	float h = 0.0;
	float k0 = floor(t / PERIOD);
	for (int j = 0; j < 4; j++) {
		float k = k0 + float(j);
		float arrive = k * PERIOD + 0.45 * PERIOD;
		float tau = arrive - t; // seconds till it reaches the sand
		if (tau < 0.0) continue;
		float size = wave_size(k);
		float c = SPEED * tau; // where its crest is
		float brk = BREAK_AT * size;
		float x = d - c; // + behind it, out to sea
		float grow = 0.35 + 0.65 * smoothstep(90.0, brk, c);
		float broken = smoothstep(brk, brk * 0.55, c);
		float amp = size * 0.75 * grow * mix(1.0, 0.28 * smoothstep(0.0, brk, c), broken);
		float prof = x < 0.0 ? exp(-(x * x) / (0.8 * 0.8)) : exp(-(x * x) / (4.5 * 4.5));
		h += amp * prof;
		face += (1.0 - broken) * smoothstep(brk * 2.4, brk, c) * smoothstep(-0.3, 0.2, -x) * smoothstep(-1.4, -0.2, x) * size;
		// white water: a band at the crest once it has broken, with a trail of foam left behind
		float trail = (brk - c) * 0.7 + 1.5;
		foam += broken * (smoothstep(-1.2, 0.0, x) * smoothstep(trail, 0.5, x));
	}
	return h * smoothstep(0.0, 5.0, d);
}

// How far up the sand the wash has run, in metres from the still waterline, and how far the last
// one reached (`reach`, for the wet sand it leaves) and how old the wash is (`age` 0..1).
float swash(float t, out float reach, out float age) {
	float k = floor((t - 0.45 * PERIOD) / PERIOD);
	float s = (t - (k * PERIOD + 0.45 * PERIOD)) / PERIOD; // 0..1 since this one reached the sand
	float size = wave_size(k);
	float run = 6.0 * size;
	float up = 1.0 - pow(1.0 - clamp(s / 0.32, 0.0, 1.0), 2.0);
	float down = smoothstep(0.32, 1.0, s);
	float e = run * up * (1.0 - down * 0.92) - 0.4;
	reach = max(run, 6.0 * wave_size(k - 1.0) * (1.0 - s));
	age = s;
	return e;
}
