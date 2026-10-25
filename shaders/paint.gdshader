// Over the whole picture: a warm grade, a heavy dark vignette like the corners of a painted plate,
// and a little paper grain, so the 3D sits like a painting.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float vignette = 0.75;
uniform float grain = 0.035;
uniform float fade = 0.0;
uniform vec3 fade_color : source_color = vec3(0.05, 0.035, 0.02);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	// warm the shadows, keep the highlights creamy
	float l = dot(c, vec3(0.3, 0.55, 0.15));
	c = mix(c, c * vec3(1.06, 0.97, 0.82), 1.0 - l);
	c = mix(vec3(l), c, 1.08);
	vec2 v = (SCREEN_UV - 0.5) * vec2(1.0, 1.1);
	float vig = smoothstep(0.85, 0.2, length(v) * (0.7 + vignette * 0.5));
	c *= mix(1.0, vig, vignette);
	// paper: fixed grain, so it reads as the surface and not as noise
	vec2 px = floor(FRAGCOORD.xy / 2.0);
	c += (hash(px) - 0.5) * grain;
	c = mix(c, fade_color, fade);
	COLOR = vec4(c, 1.0);
}
