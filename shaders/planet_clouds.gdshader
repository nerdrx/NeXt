shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled, fog_disabled;

uniform vec4 cloud_color : source_color = vec4(0.88, 0.92, 1.0, 1.0);
uniform float seed = 0.0;
uniform vec3 sun_direction = vec3(-0.5, 0.47, 0.73);
uniform float light_strength = 1.0;

#include "planet_weather.gdshaderinc"

varying vec3 radial_world;

void vertex() {
	radial_world = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 direction = normalize(radial_world);
	float coverage = weather_coverage(normalize(radial_world), seed, TIME);
	float day = smoothstep(-0.18, 0.28, dot(direction, normalize(sun_direction)));
	ALBEDO = cloud_color.rgb * mix(0.55, 1.0, coverage) * (0.012 + day * clamp(light_strength, 0.0, 1.5));
	ALPHA = coverage * cloud_color.a * 0.88;
}
