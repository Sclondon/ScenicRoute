// Things at the club (the deck, the bar, loungers, the canoe, people far off), painted: the vertex
// colour in two tones, warm gold where the low sun reaches it and violet in the shade, a hot rim on
// whatever stands against the sun, brush noise, then the haze. UV2.x makes it glow (bottles with the
// light behind them, a lamp); `planks` draws deck boards; `stride` swings limbs (UV2.y: +-1 legs, +-2 arms)
// so a figure walks.
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

#include "res://shaders/plumeria/common.gdshaderinc"

uniform float gloss = 0.0;
uniform float brush = 0.22;
uniform float planks = 0.0;
uniform float weave = 0.0;
uniform float stride = 0.0;
uniform float stride_phase = 0.0;
uniform float haze_density = 0.0034;

varying vec3 world_pos;
varying vec3 world_normal;
varying vec2 extra;

void vertex() {
	extra = UV2;
	if (stride > 0.0 && abs(UV2.y) > 0.5) {
		// limbs swing about the hip or shoulder, legs and arms opposite
		float side = sign(UV2.y);
		bool arm = abs(UV2.y) > 1.5;
		float pivot = arm ? 1.38 : 0.86;
		float a = sin(TIME * stride * 6.0 + stride_phase) * side * (arm ? -0.45 : 0.5);
		vec2 q = vec2(VERTEX.z, VERTEX.y - pivot);
		q = vec2(q.x * cos(a) - q.y * sin(a), q.x * sin(a) + q.y * cos(a));
		VERTEX.z = q.x;
		VERTEX.y = q.y + pivot;
		NORMAL = vec3(NORMAL.x, NORMAL.y * cos(a) + NORMAL.z * sin(a), -NORMAL.y * sin(a) + NORMAL.z * cos(a));
	}
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - world_pos);
	if (dot(n, to_cam) < 0.0) {
		n = -n;
	}
	vec3 base = COLOR.rgb;
	if (planks > 0.5) {
		// boards along x, 14 cm wide, butted every couple of metres, with grain
		float row = floor(world_pos.z / 0.14);
		float along = world_pos.x + hash(vec2(row, 3.0)) * 2.4;
		float fz = fract(world_pos.z / 0.14);
		float fa = fract(along / 2.4);
		float seam = max(smoothstep(0.08, 0.0, min(fz, 1.0 - fz)), smoothstep(0.006, 0.0, min(fa, 1.0 - fa)));
		float grain = vnoise(vec2(along * 3.0, world_pos.z * 60.0));
		base *= (0.85 + hash(vec2(row, 1.0)) * 0.25) * (0.9 + grain * 0.2);
		base *= 1.0 - seam * 0.6 * step(0.5, n.y);
	}
	if (weave > 0.5) {
		// lauhala matting: strips plaited over and under on the diagonal
		vec2 q = vec2(world_pos.x + world_pos.z, world_pos.y) / 0.05;
		vec2 d = vec2(q.x + q.y, q.x - q.y) * 0.7071;
		vec2 cell = floor(d);
		vec2 f = fract(d);
		bool over = mod(cell.x + cell.y, 2.0) < 1.0;
		float across = over ? f.y : f.x;
		base *= 0.78 + 0.3 * sin(across * 3.14159) * (over ? 1.0 : 0.85) + (hash(cell) - 0.5) * 0.1;
	}
	float strokes = vnoise(world_pos.xy * 7.0 + world_pos.z * 4.0) - 0.5;
	float wrap = clamp(dot(n, SUN) * 0.55 + 0.5 + strokes * brush, 0.0, 1.0);
	// shade: the violet sky from above, a warm bounce off the sand from below
	vec3 shade = base * mix(SHADE, vec3(0.62, 0.46, 0.4), clamp(-n.y, 0.0, 1.0) * 0.6);
	vec3 col = mix(shade, base * SUN_COL * 1.3, smoothstep(0.42, 0.72, wrap));
	col = mix(col, base * vec3(1.15, 0.95, 0.75) * 1.25, smoothstep(0.82, 0.98, wrap));
	// the rim of anything between you and the sun burns
	float against = clamp(dot(-to_cam, SUN) * 0.5 + 0.5, 0.0, 1.0);
	float rim = pow(1.0 - clamp(dot(n, to_cam), 0.0, 1.0), 3.0);
	col += SUN_COL * rim * pow(against, 3.0) * 0.55;
	vec3 r = reflect(-to_cam, n);
	col += SUN_COL * pow(clamp(dot(r, SUN), 0.0, 1.0), 30.0) * gloss;
	col += sky_color(r) * pow(1.0 - clamp(dot(n, to_cam), 0.0, 1.0), 4.0) * gloss * 0.4;
	col += base * extra.x * 1.6;
	col = haze(col, world_pos, CAMERA_POSITION_WORLD, haze_density);
	ALBEDO = col;
}
