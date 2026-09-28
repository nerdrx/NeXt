shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_add, shadows_disabled, fog_disabled;

uniform vec4 atmosphere_color : source_color = vec4(0.3, 0.65, 1.0, 1.0);
uniform vec3 sun_direction = vec3(-0.5, 0.47, 0.73);
uniform float light_strength = 1.0;
#include "res://shaders/planet_eclipse.gdshaderinc"

varying vec3 radial_world;
varying vec3 eclipse_position;

void vertex() {
	eclipse_position = VERTEX;
	radial_world = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	// A thin, sunlit limb approximation; surface fog handles views inside the shell.
	float mu = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float solar = dot(normalize(radial_world), normalize(sun_direction));
	float day = smoothstep(-0.13, 0.32, solar);
	float rim = pow(1.0 - mu, 4.0);
	// Optical path length grows toward the horizon; extinction softens the outer limb.
	float optical_depth = 1.0 - exp(-rim * 1.8);
	float twilight = (1.0 - smoothstep(0.0, 0.22, abs(solar))) * 0.32;
	vec3 scatter = mix(atmosphere_color.rgb, vec3(0.95, 0.48, 0.23), twilight);
	ALBEDO = scatter;
	ALPHA = optical_depth * day * primary_visibility(eclipse_position) * light_strength * 0.42;
}
