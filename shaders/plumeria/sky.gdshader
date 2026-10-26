// The sky over the Plumeria Beach Club as the sun goes down: the sun itself, big and soft, just over the
// sea; long bars of cloud lit gold and rose from underneath; puffs of trade-wind cloud drifting; the
// first stars coming out high up behind, over the mountains.
shader_type sky;

#include "res://shaders/plumeria/common.gdshaderinc"

float fbm(vec2 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.1 + 3.1) * 0.28 + vnoise(p * 4.3 - 1.7) * 0.17;
}

void sky() {
	vec3 d = EYEDIR;
	vec3 col = sky_color(vec3(d.x, max(d.y, 0.0), d.z));
	float towards = max(dot(d, SUN), 0.0);
	vec2 h = normalize(d.xz + vec2(0.0001));
	float a = dot(h, normalize(SUN.xz)) * 0.5 + 0.5;
	// the sun: a disc with a soft hot edge, a little squashed low down
	vec3 sd = d - SUN;
	sd.y *= 1.25;
	float r = length(sd);
	float disc = smoothstep(0.03, 0.027, r);
	vec3 sun_face = mix(vec3(1.5, 1.25, 0.8), vec3(1.4, 0.75, 0.32), smoothstep(0.0, 0.03, r) * 0.6 + smoothstep(0.02, -0.03, sd.y) * 0.4);
	col += vec3(1.0, 0.6, 0.3) * smoothstep(0.09, 0.03, r) * 0.22;
	col = mix(col, sun_face, disc);
	// clouds: long bars low down, puffs higher; lit underneath on the sun's side, violet on the other
	float up = max(d.y, 0.0);
	vec2 q = d.xz / (up + 0.06);
	float bars = fbm(q * vec2(0.9, 5.0) + vec2(TIME * 0.006, 0.0));
	float bar = smoothstep(0.55, 0.75, bars) * smoothstep(0.005, 0.04, up) * smoothstep(0.3, 0.08, up);
	float puffs = fbm(q * 1.4 + vec2(TIME * 0.01, TIME * 0.004));
	float puff = smoothstep(0.58, 0.78, puffs) * smoothstep(0.06, 0.2, up) * smoothstep(0.75, 0.3, up);
	float cloud = max(bar, puff * 0.9);
	// the edge of a cloud by the sun shines; its body is rose and gold towards the sun, dusky away
	vec3 lit = mix(vec3(0.95, 0.55, 0.55), vec3(1.0, 0.72, 0.4), pow(a, 3.0));
	vec3 dark = mix(vec3(0.42, 0.36, 0.55), vec3(0.62, 0.4, 0.45), pow(a, 2.0));
	float under = smoothstep(0.85, 0.55, max(bars, puffs));
	vec3 ccol = mix(dark, lit, 0.45 + 0.55 * under * (0.4 + 0.6 * a));
	ccol += vec3(1.0, 0.8, 0.5) * pow(towards, 20.0) * 0.8;
	col = mix(col, ccol, cloud * 0.85);
	// stars, faint, high behind
	vec2 g = d.xz / (d.y + 0.4) * 60.0;
	vec2 sp = floor(g);
	vec2 at = vec2(hash(sp + 3.1), hash(sp + 7.7)) * 0.8 + 0.1;
	float pt = smoothstep(0.06, 0.0, length(fract(g) - at));
	float star = step(0.97, hash(sp)) * pt * smoothstep(0.25, 0.7, up) * pow(1.0 - a, 2.0) * (1.0 - cloud);
	col += vec3(0.9, 0.9, 1.0) * star * (0.6 + 0.4 * sin(TIME * 2.0 + hash(sp + 7.0) * 30.0)) * 0.7;
	// below the horizon (only ever seen past the sea's far edge): the horizon's own colour
	if (d.y < 0.0) {
		col = sky_color(vec3(d.x, 0.0, d.z));
	}
	COLOR = col;
}
