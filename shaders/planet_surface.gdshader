shader_type spatial;
render_mode ambient_light_disabled, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://shaders/planet_weather.gdshaderinc"
#include "res://shaders/planet_eclipse.gdshaderinc"

uniform bool weather_enabled = false;
uniform float weather_seed = 0.0;
uniform float weather_shell_radius = 1.0;
uniform vec3 weather_sun_direction = vec3(-0.5, 0.47, 0.73);

uniform vec4 surface_color : source_color = vec4(0.3, 0.5, 0.32, 1.0);
uniform vec4 ocean_color : source_color = vec4(0.04, 0.12, 0.22, 1.0);
uniform float planet_radius = 850.0;
varying float eclipse_visibility;
varying vec3 stellar_direction_view;
uniform float seed = 0.0;
uniform bool has_ocean = true;
uniform sampler2D height_map : filter_linear, repeat_enable;
uniform vec2 height_map_size = vec2(512.0, 256.0);
uniform float height_scale = 12.0;
uniform float sea_level = 6.0;
uniform bool fine_patch_active = false;
uniform vec3 fine_patch_normal = vec3(0.0, 1.0, 0.0);
uniform vec3 fine_patch_tangent = vec3(1.0, 0.0, 0.0);
uniform vec3 fine_patch_bitangent = vec3(0.0, 0.0, 1.0);
uniform float fine_patch_radius = 1.0;
uniform float fine_patch_extent = 0.0;
varying vec3 planet_local_position;

float height_at(vec3 direction) {
	vec2 uv = vec2(atan(direction.z, direction.x) / TAU + 0.5,
		acos(clamp(direction.y, -1.0, 1.0)) / PI);
	uv.y = clamp(uv.y, 0.5 / height_map_size.y, 1.0 - 0.5 / height_map_size.y);
	return textureLod(height_map, uv, 0.0).r * height_scale;
}

void vertex() {
	vec3 direction = normalize(VERTEX);
	float height = height_at(direction);
	planet_local_position = direction;
	VERTEX = direction * (length(VERTEX) + (has_ocean ? max(height, sea_level) : height));
	stellar_direction_view = (MODELVIEW_MATRIX * vec4(planet_sun_position - VERTEX, 0.0)).xyz;
}

float hash(vec3 p) {
	p = fract(p * 0.3183099 + seed * 0.0001);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(hash(i), hash(i + vec3(1, 0, 0)), f.x);
	float b = mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x);
	float c = mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x);
	float d = mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x);
	return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}

float fbm(vec3 p) {
	float sum = 0.0;
	float amplitude = 0.5;
	for (int octave = 0; octave < 4; octave++) {
		sum += noise(p) * amplitude;
		p *= 2.0;
		amplitude *= 0.5;
	}
	return sum;
}

void fragment() {
	vec3 direction = normalize(planet_local_position);
	float height = height_at(direction);
	eclipse_visibility = primary_visibility(direction * (planet_radius + (has_ocean ? max(height, sea_level) : height)));
	vec3 seed_offset = vec3(seed * 0.013);
	// Low-frequency warp adds cosmetic variation without moving the saved terrain.
	vec3 warp = vec3(
		noise(direction * 2.7 + seed_offset),
		noise(direction * 2.7 + seed_offset + vec3(19.1, 7.2, 3.4)),
		noise(direction * 2.7 + seed_offset + vec3(5.3, 23.7, 11.8))
	) - 0.5;
	float detail = fbm(direction * 42.0 + warp * 0.8 + seed_offset * 4.0);
	float basins = fbm(direction * 7.0 + seed_offset * 2.0);
	float land = has_ocean ? smoothstep(sea_level - 0.015, sea_level + 0.015, height) : 1.0;
	float coast = has_ocean ? smoothstep(sea_level - 0.12, sea_level - 0.015, height) * (1.0 - land) : 0.0;
	if (fine_patch_active && land > 0.5) {
		float forward = dot(direction, fine_patch_normal);
		if (forward > 0.0) {
			float u = fine_patch_radius * dot(direction, fine_patch_tangent) / forward;
			float v = fine_patch_radius * dot(direction, fine_patch_bitangent) / forward;
			float clipped_extent = fine_patch_extent * (1.0 - 2.0 / 48.0);
			if (abs(u) <= clipped_extent && abs(v) <= clipped_extent) discard;
		}
	}
	vec3 terrain = surface_color.rgb * mix(0.84, 1.13, detail);
	terrain *= mix(0.82, 1.08, smoothstep(0.40, 0.64, basins));
	terrain = mix(terrain, terrain * 1.12, smoothstep(0.55, 0.85, height / height_scale));
	vec3 ocean = ocean_color.rgb * mix(0.88, 1.08, detail);
	ocean = mix(ocean, surface_color.rgb * 0.72, coast * 0.48);
	float polar = has_ocean ? smoothstep(0.76, 0.94, abs(direction.y)) : 0.0;
	ALBEDO = has_ocean ? mix(ocean, terrain, land) : terrain;
	ALBEDO = mix(ALBEDO, vec3(0.72, 0.76, 0.78), polar * 0.78);
	if (weather_enabled) {
		vec3 relative = direction * (planet_radius + (has_ocean ? max(height, sea_level) : height));
		ALBEDO *= 1.0 - 0.4 * weather_shadow(relative, normalize(planet_sun_position - relative), weather_shell_radius, weather_seed, TIME);
	}
	ROUGHNESS = has_ocean ? mix(0.88, 0.58, 1.0 - land) : 0.92;
	METALLIC = 0.0;
	SPECULAR = 0.18;
}

// The compact map places worlds around a finite primary, so each globe needs
// its own light vector. The single scene directional light supplies color/energy.
#include "res://shaders/planet_light.gdshaderinc"
