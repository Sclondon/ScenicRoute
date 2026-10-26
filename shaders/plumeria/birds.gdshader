// Frigatebirds riding the evening air high over the beach: long crooked wings, a forked tail, dark against
// the sky, gliding and now and then giving a few slow beats. UV2.x how far out along a wing a point is
// (0 at the body), COLOR.a the bird's own phase. Its node is moved round its circle by the place.
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

#include "res://shaders/plumeria/common.gdshaderinc"

varying vec3 world_pos;

void vertex() {
	float ph = COLOR.a * 40.0;
	// mostly gliding; a burst of beats every so often
	float burst = smoothstep(0.6, 0.9, sin(TIME * 0.21 + ph));
	float beat = sin(TIME * 4.0 + ph) * burst;
	VERTEX.y += beat * UV2.x * 0.45 + UV2.x * UV2.x * 0.08 * sin(TIME * 0.7 + ph);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - world_pos);
	vec3 col = vec3(0.12, 0.08, 0.12);
	// the edge of a wing against the sun goes gold
	col += SUN_COL * pow(clamp(dot(-to_cam, SUN), 0.0, 1.0), 8.0) * 0.25;
	col = haze(col, world_pos, CAMERA_POSITION_WORLD, 0.0034);
	ALBEDO = col;
}
