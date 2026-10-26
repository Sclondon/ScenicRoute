// Steam off the espresso: a few soft wisps, each a card facing you, rising, swelling and fading, then
// starting again. All of a wisp's corners sit at its foot; UV is the corner, UV2.x its own time.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform float rise = 0.16;
uniform float size = 0.035;

varying float life;
varying vec2 corner;

void vertex() {
	life = fract(TIME * 0.22 + UV2.x);
	corner = UV - 0.5;
	vec3 foot = VERTEX;
	foot.y += life * rise;
	foot.x += sin(TIME * 1.3 + UV2.x * 9.0 + life * 5.0) * 0.012 * life;
	foot.z += cos(TIME * 1.1 + UV2.x * 7.0) * 0.008 * life;
	vec4 view = MODELVIEW_MATRIX * vec4(foot, 1.0);
	float s = size * (0.6 + life * 1.6);
	view.xy += corner * vec2(s, s * 1.6);
	POSITION = PROJECTION_MATRIX * view;
}

void fragment() {
	float r = length(corner * vec2(1.0, 0.8)) * 2.0;
	float a = (1.0 - smoothstep(0.3, 1.0, r)) * smoothstep(0.0, 0.15, life) * (1.0 - smoothstep(0.45, 1.0, life));
	ALBEDO = vec3(1.0, 0.99, 0.96);
	ALPHA = a * 0.18;
}
