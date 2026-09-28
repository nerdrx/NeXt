shader_type spatial;
render_mode diffuse_burley;

#include "res://shaders/planet_weather.gdshaderinc"
#include "res://shaders/planet_eclipse.gdshaderinc"
varying vec3 stellar_direction_view;
varying float eclipse_visibility;

uniform bool weather_enabled = false;
uniform float weather_seed = 0.0;
uniform float weather_shell_radius = 1.0;
uniform vec3 weather_sun_direction = vec3(-0.5, 0.47, 0.73);

uniform vec3 planet_anchor;
uniform vec3 noise_origins[7];
varying vec3 rock_position;

float hash(vec3 p) {
	return fract(sin(dot(mod(p, vec3(256.0)), vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
		mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
		mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float detail_fade(float scale) {
	float footprint = max(max(fwidth(rock_position.x), fwidth(rock_position.y)),
		fwidth(rock_position.z)) * scale;
	return 1.0 - smoothstep(0.35, 0.9, footprint);
}

void vertex() {
	rock_position = VERTEX;
	stellar_direction_view = (MODELVIEW_MATRIX * vec4(planet_sun_position - (VERTEX + planet_anchor), 0.0)).xyz;
}

void fragment() {
	eclipse_visibility = primary_visibility(rock_position + planet_anchor);
	// Broad mineral clouds, warped bedding, and chipped stone planes.
	float macro = noise(rock_position * 0.035 + noise_origins[0]);
	float warp = noise(rock_position * 0.11 + noise_origins[1] + vec3(7.1, 2.4, 9.3));
	vec3 bed = rock_position + vec3(warp - 0.5) * 2.2;
	float strata = noise(bed * vec3(0.13, 0.045, 0.13) + noise_origins[2]);
	float stone = noise(bed * 0.42 + noise_origins[3] + vec3(3.7, 8.2, 1.4));
	float fracture = noise(bed * 1.15 + noise_origins[4] + vec3(11.0, 4.0, 6.0));

	float fade_coarse = detail_fade(5.0);
	float fade_fine = detail_fade(18.0);
	float grain = noise(rock_position * 5.0 + noise_origins[5]) * fade_coarse;
	float grit = noise(rock_position * 18.0 + noise_origins[6] + vec3(2.0, 13.0, 5.0)) * fade_fine;
	float bump_height = grain * 0.035 + grit * 0.012;

	vec3 mineral_dark = vec3(0.16, 0.17, 0.17);
	vec3 mineral_warm = vec3(0.43, 0.37, 0.30);
	vec3 mineral_cool = vec3(0.28, 0.31, 0.31);
	vec3 mineral = mix(mineral_dark, mineral_warm, smoothstep(0.25, 0.75, macro));
	mineral = mix(mineral, mineral_cool, smoothstep(0.58, 0.82, strata) * 0.48);
	float plates = 0.78 + strata * 0.24 + stone * 0.22;
	float chips = mix(0.86, 1.08, fracture);
	float roughness = clamp(plates * chips + grain * 0.09 + grit * 0.08, 0.62, 0.98);

	ALBEDO = COLOR.rgb * mineral * plates * chips * (0.94 + grain * 0.12 + grit * 0.08);
	if (weather_enabled) {
		ALBEDO *= 1.0 - 0.4 * weather_shadow(rock_position + planet_anchor, normalize(planet_sun_position - rock_position - planet_anchor), weather_shell_radius, weather_seed, TIME);
	}
	ROUGHNESS = roughness;
	SPECULAR = 0.18;

	// Screen-space height gradient perturbs the view-space normal; fades with pixel footprint.
	vec3 n = normalize(NORMAL);
	vec3 px = dFdx(VERTEX);
	vec3 py = dFdy(VERTEX);
	vec3 rx = cross(py, n);
	vec3 ry = cross(n, px);
	float det = dot(px, rx);
	vec3 grad = sign(det) * (dFdx(bump_height) * rx + dFdy(bump_height) * ry);
	NORMAL = normalize(abs(det) * n - grad * 0.7);
}

#include "res://shaders/planet_light.gdshaderinc"
