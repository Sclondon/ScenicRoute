// A spotlight's beam through the haze: an open cone added over the scene, bright at the lamp and fading
// down its length, soft at its sides, swinging in the vertex shader to the beat. The cone points down its
// -Y; the instance turns it to where it rests and the shader sweeps it from there.
// COLOR is its colour. INSTANCE_CUSTOM: x length, y radius at the end, z phase, w how it moves
// (0 sweeping from the truss, 1 an uplight from the stage, 2 still).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

#include "res://shaders/velvet_moth/club.gdshaderinc"

uniform float strength = 0.18;

varying float along;
varying float flash;
varying vec3 wp;

vec3 rot_x(vec3 p, float a) { float c = cos(a), s = sin(a); return vec3(p.x, c * p.y - s * p.z, s * p.y + c * p.z); }
vec3 rot_y(vec3 p, float a) { float c = cos(a), s = sin(a); return vec3(c * p.x + s * p.z, p.y, -s * p.x + c * p.z); }

void vertex() {
	vec4 cu = INSTANCE_CUSTOM;
	vec3 p = VERTEX * vec3(cu.y, cu.x, cu.y);
	vec3 n = NORMAL;
	float ph = cu.z;
	float tilt = 0.0;
	float pan = 0.0;
	float s = section();
	if (cu.w < 0.5) {
		tilt = 0.45 + 0.35 * sin(beat * 3.14159265 / 8.0 + ph * 6.2831853);
		pan = ph * 6.2831853 + beat * 3.14159265 / 16.0 * (fract(ph * 7.0) > 0.5 ? 1.0 : -1.0);
		// all together on the second section
		if (s > 0.5 && s < 1.5) {
			tilt = 0.5 + 0.3 * sin(beat * 3.14159265 / 4.0);
			pan = ph * 6.2831853 + sin(beat * 3.14159265 / 8.0) * 0.8;
		}
	} else if (cu.w < 1.5) {
		tilt = 0.25 * sin(beat * 3.14159265 / 4.0 + ph * 6.2831853);
		pan = 0.4 * sin(beat * 3.14159265 / 8.0 + ph * 3.0);
	}
	p = rot_y(rot_x(p, tilt), pan);
	n = rot_y(rot_x(n, tilt), pan);
	VERTEX = p;
	NORMAL = n;
	along = UV.y;
	wp = (MODEL_MATRIX * vec4(p, 1.0)).xyz;
	// how bright now: steady, or flashing on the beat, or taking turns
	flash = 1.0;
	if (cu.w < 1.5) {
		if (s > 0.5 && s < 1.5) flash = 0.35 + 1.0 * kick();
		else if (s > 1.5 && s < 2.5) flash = mod(floor(beat) + floor(ph * 4.0), 2.0) * (0.4 + 0.8 * kick());
		else if (s > 2.5) flash = 0.75 + 0.25 * sin(beat * 3.14159265 * 0.5 + ph * 6.0);
		else flash = 0.8;
	}
}

void fragment() {
	float fall = smoothstep(0.0, 0.06, along) * pow(1.0 - along, 1.4) * (1.4 - along);
	float edge = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 1.6);
	// fade where it meets the floor rather than cut there
	float floor_fade = smoothstep(0.0, 1.2, wp.y);
	ALBEDO = COLOR.rgb * strength * fall * edge * flash * floor_fade;
}
