// Under the sea's surface, far down: the sky as the sea reflects it (seen through the surface where you
// look across it), pale at the horizon and bluer looking down.
shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled;

uniform vec3 horizon : source_color = vec3(0.66, 0.78, 0.88);
uniform vec3 high : source_color = vec3(0.24, 0.46, 0.76);
uniform vec3 haze : source_color = vec3(0.86, 0.88, 0.88);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 v = normalize(world_pos - CAMERA_POSITION_WORLD);
	float up = clamp(-v.y, 0.0, 1.0);
	vec3 col = mix(horizon, high, smoothstep(0.0, 0.35, up));
	col = mix(col, haze, 1.0 - smoothstep(0.0, 0.03, up));
	ALBEDO = col * 0.9;
}
