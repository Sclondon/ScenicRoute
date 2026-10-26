// The striped awning over the terrace: blue and cream stripes running down it (UV.x metres along the
// front), billowing a little; the valance along its edge (UV2.x 1, UV2.y 0 at its hem to 1 at the top)
// flaps in the breeze. From under it the sun comes through the cloth, so the cream glows.
shader_type spatial;
render_mode cull_disabled;

#include "res://shaders/caffe_del_porto/light.gdshaderinc"

uniform vec3 stripe_a : source_color = vec3(0.1, 0.32, 0.62);
uniform vec3 stripe_b : source_color = vec3(0.95, 0.92, 0.83);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.82);
uniform float stripe = 0.42;

varying vec3 world_pos;

void vertex() {
	float x = UV.x;
	if (UV2.x > 0.5) {
		// the hem swings out and back, a wave running along it
		float hang = 1.0 - UV.y;
		float w = sin(TIME * 2.6 + x * 1.4) * 0.6 + sin(TIME * 4.1 + x * 3.1) * 0.25;
		VERTEX.z += w * hang * 0.06;
		VERTEX.y += abs(w) * hang * 0.012;
	} else {
		float along = UV.y;
		VERTEX.y += sin(TIME * 1.1 + x * 0.6) * 0.03 * sin(along * PI);
	}
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float s = step(0.5, fract(UV.x / (stripe * 2.0)));
	float aa = fwidth(UV.x / (stripe * 2.0)) * 2.0;
	float f = fract(UV.x / (stripe * 2.0));
	s = smoothstep(0.5 - aa, 0.5 + aa, f) * (1.0 - smoothstep(1.0 - aa, 1.0, f)) + (1.0 - smoothstep(0.0, aa, f)) * 0.0;
	vec3 c = mix(stripe_a, stripe_b, s);
	c *= 0.94 + vnoise(UV * vec2(3.0, 9.0)) * 0.1;
	// a darker band where the valance's scallops are sewn on, and the scallops' cut edge
	v_brush = 0.0;
	v_gloss = 0.0;
	ALBEDO = c;
	if (!FRONT_FACING) {
		// the underside: sun through the cloth
		EMISSION = c * sun_color * mix(0.6, 0.75, s);
		ALBEDO = c * 0.5;
	}
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
