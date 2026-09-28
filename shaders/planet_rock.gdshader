shader_type spatial;

#include "res://shaders/planet_weather.gdshaderinc"
#include "res://shaders/planet_eclipse.gdshaderinc"

uniform vec4 rock_tint : source_color = vec4(1.0);
uniform vec3 planet_anchor;
uniform bool weather_enabled = false;
uniform float weather_seed = 0.0;
uniform float weather_shell_radius = 1.0;
uniform vec3 weather_sun_direction = vec3(0.0, 1.0, 0.0);
varying vec3 planet_position;
varying vec3 stone_position;
varying vec3 stellar_direction_view;
varying float eclipse_visibility;

void vertex() {
	stone_position = VERTEX;
	// Multimesh rotation/scale plus explicit patch-local instance translation.
	// No large world translation enters the planet-relative shadow calculation.
	planet_position = planet_anchor + INSTANCE_CUSTOM.xyz + (MODEL_MATRIX * vec4(VERTEX, 0.0)).xyz;
	stellar_direction_view = (VIEW_MATRIX * vec4(planet_sun_position - planet_position, 0.0)).xyz;
}

void fragment() {
	eclipse_visibility = primary_visibility(planet_position);
	float mineral = weather_noise(stone_position * 9.0 + vec3(7.2), 0.0);
	float footprint = length(fwidth(stone_position)) * 65.0;
	float grain = mix(weather_noise(stone_position * 65.0, 0.0), 0.5, smoothstep(0.3, 0.9, footprint));
	float bedding = weather_noise(stone_position * vec3(8.0, 24.0, 8.0), 0.0);
	ALBEDO = COLOR.rgb * rock_tint.rgb * (0.48 + mineral * 0.38 + bedding * 0.16 + grain * 0.1);
	float relief = mineral * 0.015 + grain * 0.004;
	vec3 n = normalize(NORMAL);
	vec3 px = dFdx(VERTEX);
	vec3 py = dFdy(VERTEX);
	vec3 rx = cross(py, n);
	vec3 ry = cross(n, px);
	float det = dot(px, rx);
	if (abs(det) > 0.00000001) {
		vec3 grad = sign(det) * (dFdx(relief) * rx + dFdy(relief) * ry);
		NORMAL = normalize(abs(det) * n - grad);
	}
	if (weather_enabled) {
		ALBEDO *= 1.0 - 0.4 * weather_shadow(planet_position, normalize(planet_sun_position - planet_position), weather_shell_radius, weather_seed, TIME);
	}
	ROUGHNESS = 0.94;
	SPECULAR = 0.5;
}

#include "res://shaders/planet_light.gdshaderinc"
