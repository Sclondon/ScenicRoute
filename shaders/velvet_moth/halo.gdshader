// A soft glow round a lamp, a lens or a neon sign: a round card added over the scene, always facing the
// camera, nudged towards it so it is not cut by the wall it sits on. COLOR is its colour; INSTANCE_CUSTOM.x
// how much it throbs with the beat.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

#include "res://shaders/velvet_moth/club.gdshaderinc"

uniform float strength = 1.0;

varying vec4 custom;

void vertex() {
	vec3 centre = MODEL_MATRIX[3].xyz;
	float size = length(MODEL_MATRIX[0].xyz);
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - centre);
	vec3 c = centre + to_cam * size * 0.45;
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	vec3 world = c + (right * VERTEX.x + up * VERTEX.y) * size;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
	custom = INSTANCE_CUSTOM;
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r2 = dot(p, p);
	float g = exp(-r2 * 4.0) * 0.7 + exp(-r2 * 18.0) * 0.6;
	g *= smoothstep(1.0, 0.8, r2);
	float throb = mix(1.0, 0.45 + 0.75 * kick(), custom.x);
	ALBEDO = COLOR.rgb * g * strength * throb;
}
