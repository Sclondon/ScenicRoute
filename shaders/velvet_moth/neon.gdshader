// Neon tubes: the glass glowing its colour, white-hot down the middle. UV.x is the tube's group: 0 always
// lit, 1 and 2 take turns every two beats (the moth's wings beating), 3 buzzes now and then.
shader_type spatial;
render_mode unshaded, fog_disabled;

#include "res://shaders/velvet_moth/club.gdshaderinc"

uniform float power = 1.0;

void fragment() {
	float g = UV.x;
	float on = 1.0;
	float flap = mod(floor(beat / 2.0), 2.0);
	if (g > 0.5 && g < 1.5) on = 1.0 - flap;
	else if (g > 1.5 && g < 2.5) on = flap;
	else if (g > 2.5) {
		float t = TIME * 13.0;
		on = 1.0 - step(0.93, h11(floor(t))) * step(0.5, fract(t * 3.0)) * 0.8;
	}
	float face = abs(dot(NORMAL, VIEW));
	vec3 col = COLOR.rgb * power;
	col = mix(col, vec3(1.0, 0.92, 0.96), pow(face, 3.0) * 0.55);
	ALBEDO = mix(COLOR.rgb * 0.06, col, on);
}
