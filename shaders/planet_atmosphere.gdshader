shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_add, shadows_disabled, fog_disabled;

uniform vec4 atmosphere_color : source_color = vec4(0.3, 0.65, 1.0, 1.0);
uniform vec3 sun_direction = vec3(-0.5, 0.47, 0.73);
uniform float light_strength = 1.0;
varying vec3 radial_world;

void vertex() {
	radial_world = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	// A thin, sunlit limb approximation; surface fog handles views inside the shell.
	float mu = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float day = smoothstep(-0.16, 0.4, dot(normalize(radial_world), normalize(sun_direction)));
	float rim = pow(1.0 - mu, 4.5);
	ALBEDO = atmosphere_color.rgb;
	ALPHA = rim * day * light_strength * 0.48;
}
