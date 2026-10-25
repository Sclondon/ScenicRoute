// The bright haze at the end of the path, where the wood opens into sun: a soft round glow added
// over the far fog, always facing the camera.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;

uniform vec3 color : source_color = vec3(1.0, 0.9, 0.65);
uniform float strength = 0.6;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0, 0, 0), vec4(0, length(MODEL_MATRIX[1].xyz), 0, 0), vec4(0, 0, 1, 0), vec4(0, 0, 0, 1));
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	p.y *= 1.25;
	float r = length(p);
	float g = exp(-r * r * 3.5) * 0.8 + exp(-r * r * 12.0) * 0.5;
	ALBEDO = color * g * strength;
}
