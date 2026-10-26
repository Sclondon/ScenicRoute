// The crowd: dark figures with coloured rims, lit from under by the tile each stands on, dancing in the
// vertex shader, each in its own way to the one beat. The figure's parts are in COLOR.r (0 legs, 0.25 body,
// 0.5 head, 0.75 left arm, 1 right arm) and COLOR.g is how far down the arm (past 0.5 is the forearm).
// INSTANCE_CUSTOM: x its phase against the beat (in beats), y its style (low: bounce with arms bent,
// middle: one fist pumping, high: hands in the air), z how hard it dances, w a seed.
shader_type spatial;
render_mode unshaded, cull_disabled;

#include "res://shaders/velvet_moth/club.gdshaderinc"

// sat down (booths): only the top half moves, and gently
uniform float seated = 0.0;
uniform float shoulder_y = 1.42;
uniform float hip_y = 0.88;

varying vec3 wp;
varying vec3 wn;
varying vec3 origin;
varying float seed;

vec3 rot_x(vec3 p, float a) { float c = cos(a), s = sin(a); return vec3(p.x, c * p.y - s * p.z, s * p.y + c * p.z); }
vec3 rot_y(vec3 p, float a) { float c = cos(a), s = sin(a); return vec3(c * p.x + s * p.z, p.y, -s * p.x + c * p.z); }
vec3 rot_z(vec3 p, float a) { float c = cos(a), s = sin(a); return vec3(c * p.x - s * p.y, s * p.x + c * p.y, p.z); }

void vertex() {
	vec4 cu = INSTANCE_CUSTOM;
	float part = COLOR.r;
	float t = beat + cu.x;
	float e = cu.z * (1.0 - seated * 0.7);
	// down on the beat, up between
	float dip = pow(0.5 + 0.5 * cos(6.2831853 * t), 2.0);
	// side to side over two beats
	float sway = sin(3.14159265 * t + cu.w * 6.2831853);
	// more hands go up as the night swells, slowly
	float hype = 0.5 + 0.5 * sin(beat * 6.2831853 / 96.0 + cu.w * 2.0);
	float style = cu.y + hype * 0.3 * (1.0 - seated) * smoothstep(0.45, 0.6, cu.z);
	vec3 p = VERTEX;
	vec3 n = NORMAL;
	bool arm = part > 0.6;
	if (arm) {
		float side = part > 0.9 ? 1.0 : -1.0;
		vec3 sh = vec3(side * 0.2, shoulder_y, 0.0);
		vec3 el = sh + vec3(side * 0.015, -0.29, 0.0);
		// how the arm is held: bent and swinging, pumping, or up
		float up = smoothstep(0.74, 0.88, style);
		float pump = smoothstep(0.45, 0.56, style) * (1.0 - up) * step(0.0, side);
		float lift = mix(0.25 + 0.25 * sway * side, 0.15, up);   // sideways, radians
		float fwd = mix(0.5 + 0.35 * dip * e, 0.2, up);          // forwards
		float bend = mix(1.3 + 0.3 * dip, 0.35, up);              // at the elbow
		lift = mix(lift, 2.6 + 0.25 * dip, up);
		lift = mix(lift, 2.3 + 0.35 * dip, pump);
		fwd = mix(fwd, 0.3, pump);
		bend = mix(bend, 0.6 - 0.4 * dip, pump);
		if (seated > 0.5) {
			lift = 0.15;
			fwd = 0.6 + 0.15 * sin(beat * 0.7 + cu.w * 9.0);
			bend = 1.2 + 0.3 * sin(beat * 0.45 + cu.w * 5.0);
		}
		if (COLOR.g > 0.5) {
			p = el + rot_x(p - el, bend);
			n = rot_x(n, bend);
		}
		p = sh + rot_x(p - sh, fwd);
		n = rot_x(n, fwd);
		p = sh + rot_z(p - sh, side * lift);
		n = rot_z(n, side * lift);
	}
	if (part > 0.4 && part < 0.6) {
		// the head nods on the beat
		vec3 neck = vec3(0.0, shoulder_y + 0.04, 0.0);
		p = neck + rot_x(p - neck, -dip * 0.25 * e);
	}
	float above = smoothstep(hip_y - 0.15, hip_y + 0.1, VERTEX.y);
	if (part > 0.1 || seated > 0.5) {
		// the top half: down with the knees, leaning and turning into the sway
		p = rot_y(p, sway * 0.22 * e * above);
		n = rot_y(n, sway * 0.22 * e * above);
		p.x += sway * 0.06 * e * max(p.y - hip_y, 0.0);
	}
	if (seated < 0.5) {
		// knees: the legs squash, the rest drops with them
		float drop = dip * 0.07 * e;
		if (part < 0.1) p.y -= drop * clamp(p.y / hip_y, 0.0, 1.0);
		else p.y -= drop;
		p.x += sway * 0.03 * e;
	}
	VERTEX = p;
	NORMAL = n;
	wp = (MODEL_MATRIX * vec4(p, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(n, 0.0)).xyz);
	origin = MODEL_MATRIX[3].xyz;
	seed = cu.w;
}

void fragment() {
	vec3 n = normalize(wn);
	vec3 v = normalize(CAMERA_POSITION_WORLD - wp);
	float ndv = abs(dot(n, v));
	// clothes: near black, a little colour in some
	// clothes: most near black; some wine, teal or sequins, a few white shirts that catch the light
	float pick = h11(seed * 7.0);
	vec3 base = mix(vec3(0.04, 0.025, 0.06), vec3(0.1, 0.05, 0.1), h11(seed * 13.0));
	if (pick > 0.93) base = vec3(0.32, 0.28, 0.36);
	else if (pick > 0.8) base = vec3(0.3, 0.04, 0.1);
	else if (pick > 0.72) base = vec3(0.05, 0.18, 0.2);
	// skin and hair stay dark, a silhouette
	if (COLOR.r > 0.4 && COLOR.r < 0.6) base = vec3(0.06, 0.03, 0.05);
	vec3 col = base * club_light(wp, n) * 0.35;
	// lit from under by the tile they stand on
	vec2 q = origin.xz - FLOOR_RECT.xy;
	vec2 size = FLOOR_RECT.zw - FLOOR_RECT.xy;
	if (q.x > 0.0 && q.y > 0.0 && q.x < size.x && q.y < size.y && origin.y < 0.5) {
		vec3 tc = tile_color(floor(q));
		float low = exp(-max(wp.y - origin.y, 0.0) * 2.6);
		col += tc * (0.15 + 0.6 * clamp(-n.y + 0.3, 0.0, 1.0)) * low * 0.5;
	}
	// rims: magenta from stage left, teal from stage right, the floor's colour from below
	float rim = pow(1.0 - ndv, 3.0);
	vec3 rim_col = mix(vec3(1.0, 0.2, 0.7), vec3(0.2, 0.75, 1.0), smoothstep(-0.4, 0.4, n.x));
	rim_col = mix(rim_col, floor_glow() * 1.6, 0.35);
	col += rim_col * rim * 1.1;
	col += vec3(1.0, 0.92, 0.98) * specks(wp, n) * 0.7;
	ALBEDO = col;
}
