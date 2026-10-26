// Bottles on the back bar, lit through from the glowing wall behind them: bright glass in the middle,
// dark at the edges, a thin highlight down one side. COLOR is the glass.
shader_type spatial;
render_mode unshaded;

#include "res://shaders/velvet_moth/club.gdshaderinc"

void fragment() {
	float face = abs(dot(normalize(NORMAL), normalize(VIEW)));
	vec3 glass = COLOR.rgb;
	vec3 col = glass * (0.15 + 1.1 * pow(face, 1.5));
	float side = smoothstep(0.25, 0.3, face) * smoothstep(0.42, 0.32, face);
	col += vec3(1.0, 0.85, 0.7) * side * 0.5;
	// the neck and cap darker
	col *= mix(1.0, 0.45, smoothstep(0.7, 0.8, UV.y));
	ALBEDO = col;
}
