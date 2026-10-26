// The houses stacked up the cliffs: washed walls in their own colour (vertex COLOR), windows with green
// shutters open or shut, little balconies and pots, and terracotta roofs, all painted from the face's UV
// (metres across and up it). UV2.x is the kind of face, UV2.y the face's width (whole tenths) plus a
// number of the house's own (the fraction). Kinds:
//  0 a wall with windows     1 roof tiles (UV.y up the slope)    2 a plain wall
//  3 a flat roof             4 a wall with doors and arches along the ground, windows above
shader_type spatial;
render_mode cull_back;

#include "res://shaders/caffe_del_porto/light.gdshaderinc"

varying vec3 world_pos;
varying flat int kind;
varying flat float width;
varying flat float seed;

void vertex() {
	kind = int(UV2.x + 0.5);
	width = floor(UV2.y) / 10.0;
	seed = fract(UV2.y);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float box(vec2 p, vec2 lo, vec2 hi, float aa) {
	vec2 a = smoothstep(lo - aa, lo + aa, p) * (1.0 - smoothstep(hi - aa, hi + aa, p));
	return a.x * a.y;
}

void fragment() {
	vec3 wall = COLOR.rgb;
	vec2 uv = UV;
	float fw = max(length(fwidth(uv)), 0.002);
	float detail = 1.0 - smoothstep(0.12, 0.4, fw);
	float aa = fw * 0.7;
	v_brush = (vnoise(world_pos.xy * 3.0 + world_pos.z * 2.0) - 0.5) * 0.16;
	v_gloss = 0.0;
	vec3 col = wall;
	// washed plaster: patches where it has faded or been patched
	float patchy = fbm(uv * 0.35 + seed * 31.0);
	col *= 0.9 + patchy * 0.16;
	if (kind == 0 || kind == 4) {
		float n = max(1.0, floor(width / 2.6 + 0.5));
		float pitch = width / n;
		float cx = floor(uv.x / pitch);
		vec2 p = vec2(fract(uv.x / pitch) * pitch - pitch * 0.5, mod(uv.y, 3.0));
		float row = floor(uv.y / 3.0);
		float h = hash(vec2(cx, row) + seed * 17.0);
		float h2 = hash(vec2(row, cx) + seed * 5.0 + 3.0);
		vec3 shutter = mix(vec3(0.14, 0.36, 0.25), vec3(0.24, 0.46, 0.32), hash(vec2(seed, 1.0)));
		if (hash(vec2(seed, 7.0)) > 0.8) {
			shutter = vec3(0.32, 0.22, 0.14);
		}
		vec3 glass = vec3(0.08, 0.07, 0.09);
		// a stain running down under each window
		col *= 1.0 - 0.06 * box(p, vec2(-0.45, 0.0), vec2(0.45, 0.9), 0.3) * detail;
		bool ground = kind == 4 && row < 0.5;
		if (ground) {
			// arched doorways and shop fronts on the quay
			float d = box(p, vec2(-0.75, 0.0), vec2(0.75, 2.2), aa);
			float arch = 1.0 - smoothstep(0.75 - aa, 0.75 + aa, length(vec2(p.x, max(p.y - 2.2, 0.0)) * vec2(1.0, 1.3)));
			float door = max(d, arch * step(2.2, p.y) * step(p.y, 2.9));
			vec3 inside = h < 0.4 ? vec3(0.3, 0.18, 0.1) : glass * 1.4;
			col = mix(col, inside, door * detail);
			// a frame round it
			col = mix(col, col * 0.75, (box(p, vec2(-0.85, 0.0), vec2(0.85, 2.95), aa) - door) * detail * 0.6);
		} else if (h > 0.08) {
			vec2 lo = vec2(-0.42, 0.85);
			vec2 hi = vec2(0.42, 2.3);
			float win = box(p, lo, hi, aa);
			float open = step(0.35, h);
			// the reveal: shadow along the top and one side
			col = mix(col, col * 0.62, (box(p, lo - vec2(0.08, 0.06), hi + vec2(0.08, 0.1), aa) - win) * detail);
			vec3 w = glass;
			// curtains glimpsed in some
			w = mix(w, vec3(0.75, 0.7, 0.6) * 0.5, step(0.7, h2) * box(p, vec2(-0.4, 1.6), vec2(0.4, 2.3), aa));
			if (open < 0.5) {
				// shut: louvred shutters over the window
				float slat = 0.75 + 0.25 * smoothstep(0.3, 0.7, abs(fract(p.y * 9.0) - 0.5) * 2.0);
				w = shutter * mix(1.0, slat, detail);
				w = mix(w, shutter * 0.5, smoothstep(0.03, 0.0, abs(p.x)) * detail);
			} else {
				// open: a shutter folded back each side
				float l = box(p, vec2(-0.86, 0.85), vec2(-0.44, 2.3), aa) + box(p, vec2(0.44, 0.85), vec2(0.86, 2.3), aa);
				float slat = 0.8 + 0.2 * smoothstep(0.3, 0.7, abs(fract(p.y * 9.0) - 0.5) * 2.0);
				col = mix(col, shutter * mix(1.0, slat, detail), l * detail);
			}
			col = mix(col, w, win * detail);
			// a little balcony now and then: a slab and railings, or pots of geraniums on the sill
			if (h2 < 0.25 && row > 0.5) {
				float slab = box(p, vec2(-0.75, 0.72), vec2(0.75, 0.85), aa);
				float rails = box(p, vec2(-0.75, 0.85), vec2(0.75, 1.55), aa) * (step(0.6, fract(p.x * 7.0)) + box(p, vec2(-0.75, 1.48), vec2(0.75, 1.55), aa));
				col = mix(col, col * 0.55, box(p, vec2(-0.75, 0.55), vec2(0.75, 0.72), aa) * detail);
				col = mix(col, wall * 1.05, slab * detail);
				col = mix(col, vec3(0.08, 0.1, 0.09), clamp(rails, 0.0, 1.0) * detail);
			} else if (h2 > 0.82) {
				float pots = box(p, vec2(-0.4, 0.78), vec2(0.4, 1.0), aa);
				float flowers = pots * step(0.4, vnoise(p * 24.0));
				col = mix(col, vec3(0.62, 0.3, 0.18), box(p, vec2(-0.38, 0.78), vec2(0.38, 0.92), aa) * detail);
				col = mix(col, mix(vec3(0.85, 0.12, 0.15), vec3(0.95, 0.4, 0.55), h2 * 5.0 - 4.1), box(p, vec2(-0.42, 0.92), vec2(0.42, 1.1), aa) * step(0.35, vnoise(p * 30.0)) * detail);
			}
		}
		// far off, the windows blur into the wall as a darker speckle
		col = mix(col, col * 0.86, (1.0 - detail) * 0.6);
	} else if (kind == 1) {
		// tiles: rows up the slope, round ribs across, each tile a little different
		vec2 t = vec2(uv.x / 0.24, uv.y / 0.32);
		t.x += floor(t.y) * 0.5;
		vec2 c = floor(t);
		vec2 f = fract(t);
		float rib = 0.72 + 0.4 * sin(f.x * PI);
		float lap = mix(0.7, 1.0, smoothstep(0.0, 0.25, f.y));
		float tone = 0.85 + hash(c + seed) * 0.3;
		col = wall * mix(1.0, rib * lap * tone, detail);
		col *= 0.92 + fbm(uv * 0.5 + seed * 9.0) * 0.18;
		v_brush += (rib - 0.9) * 0.3 * detail;
	} else if (kind == 3) {
		col = wall * (0.9 + fbm(uv * 0.8) * 0.12);
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
