// Most things at the Caffè del Porto: a vertex colour painted by its kind (UV2.x), lit in two tones by the
// sun (light.gdshaderinc). Kinds:
//  0 plain, brushy        1 marble              2 terracotta floor tiles   3 glossy (china, paint, chrome)
//  4 leaves (sway)        5 (spare)             6 chalkboard               7 stone blocks
//  8 flowers (sway)       9 wood                10 dark inside             11 plaster
//  12 cloth               13 leaves that do not sway  14 lit from within   15 a walker's swinging limb
// Wherever COLOR.a < 0.5 the colour is the instance's own (INSTANCE_CUSTOM: boats' trim, people's shirts).
shader_type spatial;
render_mode cull_back;

#include "res://shaders/caffe_del_porto/light.gdshaderinc"

uniform float sway = 1.0;
// 1 for GameCommon's trees (see vertex())
uniform float tree = 0.0;

varying vec3 world_pos;
varying vec3 obj_pos;
varying flat int kind;
varying vec3 v_custom;

void vertex() {
	kind = int(UV2.x + 0.5);
	v_custom = INSTANCE_CUSTOM.rgb;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (tree > 0.5) {
		// GameCommon's trees (leafy-tree, pine-tree): UV2.y is how much each corner sways; leaves where it
		// is more than the limbs'
		kind = UV2.y > 0.17 ? 16 : 0;
		vec3 org = MODEL_MATRIX[3].xyz;
		float ph = org.x * 0.37 + org.z * 0.21;
		float k = UV2.y * sway * 0.06;
		VERTEX += (inverse(MODEL_MATRIX) * vec4(sin(TIME * 1.1 + ph) * k, 0.0, cos(TIME * 0.9 + ph) * k * 0.6, 0.0)).xyz;
	} else if (kind == 4 || kind == 8) {
		// leaves and flowers stir in the breeze, each clump on its own time
		float ph = wp.x * 0.7 + wp.z * 0.43;
		float k = sway * (0.025 + 0.02 * sin(TIME * 0.31 + ph * 0.2));
		VERTEX += (inverse(MODEL_MATRIX) * vec4(sin(TIME * 1.7 + ph) * k, sin(TIME * 2.3 + ph * 1.3) * k * 0.5, cos(TIME * 1.3 + ph) * k, 0.0)).xyz;
	} else if (kind == 15) {
		// a walker's legs and arms swing from the hip or shoulder (|UV2.y|), the two sides against each
		// other (its sign); INSTANCE_CUSTOM.a is the walker's step (0: standing still)
		float pivot = abs(UV2.y);
		float walk = INSTANCE_CUSTOM.a;
		float sw = sin(TIME * 5.2 + walk * 6.283) * sign(UV2.y) * step(0.001, walk);
		VERTEX.z += sw * (pivot - VERTEX.y) * 0.42;
	}
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	obj_pos = VERTEX;
}

void fragment() {
	vec3 base = COLOR.rgb;
	if (COLOR.a < 0.5) {
		base = v_custom;
	}
	v_brush = (vnoise(world_pos.xy * 7.0 + world_pos.z * 5.0) - 0.5) * 0.18;
	v_gloss = 0.0;
	float rough = 0.06;
	if (kind == 1) {
		// white marble, grey veins wandering through it
		vec2 p = world_pos.xz * 9.0;
		float v = abs(sin(p.x * 0.7 + fbm(p * 0.6) * 5.0 + p.y * 0.3));
		base = mix(base, base * vec3(0.72, 0.74, 0.78), smoothstep(0.12, 0.0, v) * 0.7);
		base *= 0.97 + fbm(p * 0.3) * 0.06;
		v_gloss = 0.7;
	} else if (kind == 2) {
		// cotto tiles in a grid, each its own shade, pale grout between
		vec2 p = world_pos.xz / 0.32;
		vec2 c = floor(p);
		vec2 f = fract(p);
		float tone = hash(c);
		base *= 0.86 + tone * 0.22;
		base = mix(base, base * vec3(1.0, 0.85, 0.75), vnoise(p * 2.3) * 0.25);
		float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
		base = mix(base * vec3(1.05, 1.0, 0.95) * 0.82, base, smoothstep(0.008, 0.025, edge));
		rough = 0.0;
	} else if (kind == 3) {
		v_gloss = 1.0;
		rough = 0.02;
	} else if (kind == 16) {
		// a tree's leaves: broken into small cells of light and dark
		vec2 c = floor(world_pos.xz * 5.0 + world_pos.y * 3.0);
		float m = hash(c + floor(world_pos.y * 5.0));
		base *= 0.82 + m * 0.36;
		v_brush += (m - 0.5) * 0.3;
	} else if (kind == 4 || kind == 13) {
		float m = fbm(obj_pos.xz * 9.0 + obj_pos.y * 7.0);
		base *= 0.75 + m * 0.5;
		v_brush += (m - 0.5) * 0.4;
	} else if (kind == 6) {
		// slate with chalk smudged over it
		base = vec3(0.12, 0.14, 0.13) + vec3(0.12) * fbm(UV * 6.0) * 0.6;
	} else if (kind == 7) {
		// blocks of stone laid in courses
		vec2 p = vec2(world_pos.x + world_pos.z, world_pos.y) / vec2(0.9, 0.45);
		p.x += floor(p.y) * 0.5;
		vec2 c = floor(p);
		vec2 f = fract(p);
		base *= 0.85 + hash(c) * 0.25;
		float edge = min(min(f.x, 1.0 - f.x) * 0.5, min(f.y, 1.0 - f.y));
		base *= mix(0.6, 1.0, smoothstep(0.02, 0.07, edge));
	} else if (kind == 8) {
		float m = vnoise(obj_pos.xz * 30.0 + obj_pos.y * 25.0);
		base = mix(base * 0.7, base * 1.15, m);
		base = mix(base, vec3(0.2, 0.42, 0.14), smoothstep(0.82, 0.95, vnoise(obj_pos.xy * 21.0 + 4.0)) * 0.8);
	} else if (kind == 9) {
		float g = vnoise(vec2(UV.x * 1.5, UV.y * 30.0));
		base *= 0.82 + g * 0.3;
	} else if (kind == 10) {
		base *= 0.35;
	} else if (kind == 14) {
		// lit from within (a warm room through a doorway)
		EMISSION = base * (0.4 + 0.15 * fbm(UV * 2.0));
		base *= 0.4;
	} else if (kind == 11) {
		base *= 0.93 + fbm(world_pos.xy * 1.3 + world_pos.z) * 0.12;
	} else if (kind == 12) {
		base *= 0.92 + vnoise(UV * 40.0) * 0.12;
	}
	base *= 1.0 + (vnoise(world_pos.xz * 3.0 + world_pos.y * 2.0) - 0.5) * rough * 2.0;
	ALBEDO = base;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
