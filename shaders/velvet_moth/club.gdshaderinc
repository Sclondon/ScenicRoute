// The Velvet Moth's shared parts: the one beat everything moves to (set every frame from the music's own
// clock, in beats), the dance floor's colours, the light the room is painted by, and the mirror ball's specks.

uniform float beat = 0.0;

// keep these in step with velvet_moth.gd
const vec3 BALL = vec3(-1.6, 6.4, -8.0);
const vec4 FLOOR_RECT = vec4(-6.0, -14.0, 6.0, -3.0); // x0, z0, x1, z1: 1 m tiles
const vec3 BAR_LAMP = vec3(0.0, 4.4, 9.4);

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float h11(float n) { return fract(sin(n * 91.3458) * 47453.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

// magenta, violet, amber, cyan, pink
vec3 palette(float k) {
	float i = mod(floor(k), 5.0);
	if (i < 0.5) return vec3(1.0, 0.1, 0.55);
	if (i < 1.5) return vec3(0.5, 0.14, 1.0);
	if (i < 2.5) return vec3(1.0, 0.45, 0.1);
	if (i < 3.5) return vec3(0.1, 0.55, 1.0);
	return vec3(1.0, 0.3, 0.8);
}

// 1 on the beat, falling away before the next
float kick() { return exp(-fract(beat) * 3.2); }

// the floor changes what it does every four bars, on the downbeat
float section() { return mod(floor(beat / 16.0), 4.0); }

// The colour of one dance floor tile now (ij counts tiles from the floor's corner)
vec3 tile_color(vec2 ij) {
	float b = floor(beat);
	float s = section();
	float pulse = 0.3 + 0.7 * kick();
	vec2 c = ij - vec2(5.5, 5.0);
	vec3 dim = vec3(0.2, 0.05, 0.28);
	if (s < 0.5) {
		// checker, swapping on every beat
		float on = mod(ij.x + ij.y + b, 2.0);
		vec3 a = palette(floor(beat / 4.0) * 2.0);
		return mix(dim, a, on * pulse) + palette(1.0) * 0.12 * (1.0 - on);
	} else if (s < 1.5) {
		// rings going out from the middle, one a beat
		float r = fract(beat) * 9.0;
		float d = length(c * vec2(1.0, 1.1));
		float band = exp(-pow(d - r, 2.0) * 0.5) + exp(-pow(d - r - 9.0, 2.0) * 0.5) * 0.0;
		return dim + palette(b) * band * 1.1 + palette(b + 1.0) * 0.15 * kick();
	} else if (s < 2.5) {
		// tiles lighting at random on the beat
		float h = h21(ij + b * 13.1);
		float on = step(0.55, h);
		return dim + palette(floor(h * 23.0)) * on * pulse;
	}
	// stripes sweeping across
	float k = (ij.x + ij.y * 0.6) * 0.33 - beat * 0.5;
	float f = fract(k);
	return dim + palette(floor(k)) * smoothstep(0.0, 0.25, f) * smoothstep(1.0, 0.55, f) * (0.55 + 0.45 * kick());
}

// About what the whole floor gives off now, for the light it throws on the room
vec3 floor_glow() {
	float s = section();
	vec3 c;
	if (s < 0.5) c = mix(palette(floor(beat / 4.0) * 2.0), vec3(0.4, 0.1, 0.6), 0.5) * 0.7;
	else if (s < 1.5) c = palette(floor(beat)) * 0.45 + vec3(0.12, 0.03, 0.18);
	else if (s < 2.5) c = vec3(0.6, 0.25, 0.55) * 0.6;
	else c = mix(palette(floor(-beat * 0.5)), palette(floor(-beat * 0.5) + 1.0), 0.5) * 0.6;
	return c * (0.55 + 0.45 * kick());
}

// The light a surface is painted by: a deep violet dark, the dance floor's glow thrown up on everything
// near it, a magenta wash from stage left and a teal one from stage right, and the warm bar.
vec3 club_light(vec3 p, vec3 n) {
	vec3 L = vec3(0.1, 0.05, 0.16) * (0.75 + 0.25 * n.y);
	// the floor, as one big glowing panel: from its nearest point
	vec3 fp = vec3(clamp(p.x, FLOOR_RECT.x, FLOOR_RECT.z), 0.0, clamp(p.z, FLOOR_RECT.y, FLOOR_RECT.w));
	vec3 d = fp - p;
	float dist = length(d) + 0.6;
	float face = clamp(dot(n, d / dist) * 0.6 + 0.4, 0.0, 1.0);
	L += floor_glow() * face * 3.0 / (1.0 + dist * dist * 0.06);
	// the washes from the stage's sides
	L += vec3(0.5, 0.07, 0.4) * clamp(dot(n, normalize(vec3(-0.8, 0.3, -0.5))) * 0.7 + 0.3, 0.0, 1.0) * 0.5;
	L += vec3(0.05, 0.25, 0.45) * clamp(dot(n, normalize(vec3(0.8, 0.35, -0.3))) * 0.7 + 0.3, 0.0, 1.0) * 0.45;
	// the bar's lamps, warm
	vec3 bd = BAR_LAMP - p;
	float bl = length(bd);
	L += vec3(1.0, 0.55, 0.25) * clamp(dot(n, bd / bl) * 0.6 + 0.4, 0.0, 1.0) * 3.0 / (1.0 + bl * bl * 0.12);
	return L;
}

// The mirror ball's specks on whatever this is: little spots of light in rings round the ball, turning
// slowly, on what faces it. 0..1.
float specks(vec3 p, vec3 n) {
	vec3 d = p - BALL;
	float dist = length(d);
	d /= dist;
	// how much angle a pixel spans here (not fwidth of the cell distance: that jumps at the cell edges)
	float px = length(fwidth(d));
	float a = beat * 6.2831853 / 64.0;
	float ca = cos(a), sa = sin(a);
	d.xz = vec2(ca * d.x - sa * d.z, sa * d.x + ca * d.z);
	float rows = 58.0;
	float lat = asin(clamp(d.y, -1.0, 1.0));
	float r = lat / 3.14159265 * rows;
	float ri = floor(r);
	float latc = (ri + 0.5) / rows * 3.14159265;
	float cols = max(floor(2.0 * rows * cos(latc)), 3.0);
	float lon = atan(d.z, d.x) / 6.2831853 + 0.5;
	float c = lon * cols;
	float ci = floor(c);
	vec2 off = vec2((fract(c) - 0.5) * 6.2831853 / cols * cos(lat), (fract(r) - 0.5) * 3.14159265 / rows);
	float ang = length(off);
	float h = h21(vec2(ri, ci));
	float size = 0.0055;
	float w = px * 0.7 + 0.0005;
	float spot = smoothstep(size + w, size - w, ang) * size / (size + w * 2.0);
	float facing = clamp(dot(n, -d) * 1.6, 0.0, 1.0);
	return spot * step(0.3, h) * (0.5 + 0.5 * h) * facing * 9.0 / (5.0 + dist);
}
