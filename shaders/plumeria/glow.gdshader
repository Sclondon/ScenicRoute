// Little lights: the bulbs on the strings (a hot core in a soft halo, each its own faint waver) and the
// warm haze round each torch flame (bigger, flickering). A MultiMesh of quads turned to the camera, added
// over the picture. INSTANCE_CUSTOM: rgb its colour, a its size in metres (over 0.5: a torch's haze).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

varying vec4 custom;
varying float flick;

float hash1(float n) { return fract(sin(n) * 43758.5453); }

void vertex() {
	custom = INSTANCE_CUSTOM;
	float seed = hash1(float(INSTANCE_ID) * 1.37 + 0.5);
	float t = TIME;
	bool torch = custom.a > 0.5;
	flick = torch
		? 0.8 + 0.12 * sin(t * 7.3 + seed * 40.0) + 0.08 * sin(t * 13.1 + seed * 10.0)
		: 0.92 + 0.08 * sin(t * 1.3 + seed * 20.0);
	vec3 centre = MODEL_MATRIX[3].xyz;
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	vec3 world = centre + (right * VERTEX.x + up * VERTEX.y) * custom.a * (torch ? flick : 1.0);
	// a little towards the camera, so a bulb is not cut by the wire or a torch's haze by its pole
	world += normalize(CAMERA_POSITION_WORLD - centre) * custom.a * 0.3;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	bool torch = custom.a > 0.5;
	float g = torch
		? exp(-r * r * 3.0) * 0.35
		: exp(-r * r * 60.0) * 1.6 + exp(-r * r * 9.0) * 0.32;
	ALBEDO = custom.rgb * g * flick;
}
