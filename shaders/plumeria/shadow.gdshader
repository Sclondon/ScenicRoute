// Long evening shadows laid on the sand, away from the low sun: soft-edged, violet, darkest at the foot
// of what casts them and fading out at the far end. Quads on the ground, multiplied over it.
// UV.x across 0..1, UV.y from the foot (0) to the far tip (1); COLOR.a how dark.
shader_type spatial;
render_mode unshaded, blend_mul, depth_draw_never, cull_disabled, fog_disabled;

void fragment() {
	float x = (UV.x - 0.5) * 2.0;
	float y = UV.y;
	float w = mix(1.0, 0.55, y);
	float a = smoothstep(1.0, 0.15, abs(x) / w) * smoothstep(1.0, 0.55, y) * smoothstep(0.0, 0.06, y);
	a *= COLOR.a;
	ALBEDO = mix(vec3(1.0), vec3(0.62, 0.55, 0.75), a);
}
