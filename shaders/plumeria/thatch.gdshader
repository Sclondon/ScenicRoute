// Palm thatch on the tiki roofs: courses of straw laid in steps down the slope, streaky, golden where the
// sun lies on it and silvered with age, ragged where it hangs over the eaves; warm brown underneath, lit by
// the string lights. UV.x along the roof and UV.y down the slope, in metres; UV2.x is where the eave is.
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

#include "res://shaders/plumeria/common.gdshaderinc"

uniform vec3 straw : source_color = vec3(0.78, 0.6, 0.36);
uniform vec3 old_straw : source_color = vec3(0.52, 0.45, 0.36);

varying vec3 world_pos;
varying vec3 world_normal;
varying vec2 eave;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	eave = UV2;
	// the fringe stirs in the breeze
	float hang = clamp(UV.y - UV2.x + 0.1, 0.0, 1.0);
	world_pos += vec3(0.0, 0.0, 1.0) * sin(TIME * 2.3 + UV.x * 2.0) * hang * 0.04;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world_pos, 1.0)).xyz;
}

void fragment() {
	vec2 q = UV;
	// a ragged hem: strands of different lengths
	float strand = hash(vec2(floor(q.x * 34.0), 1.0));
	float jag = eave.x + 0.05 + strand * 0.32 * (0.6 + vnoise(vec2(q.x * 2.0, 0.0)) * 0.6);
	if (q.y > jag) {
		discard;
	}
	vec3 n = normalize(world_normal);
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - world_pos);
	bool under = dot(n, to_cam) < 0.0;
	if (under) {
		n = -n;
	}
	float course = fract(q.y / 0.32);
	float streak = vnoise(vec2(q.x * 30.0, q.y * 1.2)) * 0.6 + vnoise(vec2(q.x * 90.0, q.y * 3.0)) * 0.4;
	vec3 base = mix(old_straw, straw, smoothstep(0.25, 0.75, vnoise(q * vec2(0.4, 0.9))));
	base *= 0.75 + streak * 0.4;
	// each course's lower edge shades the one under it
	base *= mix(0.6, 1.0, smoothstep(0.0, 0.35, course));
	vec3 col;
	if (under) {
		col = base * vec3(0.38, 0.26, 0.18) + vec3(0.1, 0.05, 0.02);
	} else {
		float wrap = clamp(dot(n, SUN) * 0.6 + 0.5 + (streak - 0.5) * 0.3, 0.0, 1.0);
		col = mix(base * SHADE * 1.1, base * SUN_COL * 1.35, smoothstep(0.38, 0.7, wrap));
		float against = clamp(dot(-to_cam, SUN) * 0.5 + 0.5, 0.0, 1.0);
		col += SUN_COL * pow(1.0 - abs(dot(n, to_cam)), 3.0) * pow(against, 3.0) * 0.4;
	}
	// the hem is thinner and lets the light through
	col = mix(col, col * 0.7, smoothstep(eave.x - 0.1, eave.x + 0.25, q.y));
	col = haze(col, world_pos, CAMERA_POSITION_WORLD, 0.0034);
	ALBEDO = col;
}
