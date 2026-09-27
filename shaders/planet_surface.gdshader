shader_type spatial;
render_mode ambient_light_disabled, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 surface_color : source_color = vec4(0.3, 0.5, 0.32, 1.0);
uniform vec4 ocean_color : source_color = vec4(0.04, 0.12, 0.22, 1.0);
uniform float seed = 0.0;
uniform bool clouds = true;
uniform bool has_ocean = true;
varying vec3 planet_local_position;

void vertex() {
	planet_local_position = VERTEX;
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
	vec3 seed_offset = vec3(seed * 0.013);
	// Low-frequency warp makes broad, irregular continents instead of speckles.
	vec3 warp = vec3(
		noise(direction * 2.7 + seed_offset),
		noise(direction * 2.7 + seed_offset + vec3(19.1, 7.2, 3.4)),
		noise(direction * 2.7 + seed_offset + vec3(5.3, 23.7, 11.8))
	) - 0.5;
	float continents = fbm(direction * 3.4 + warp * 1.65 + seed_offset);
	float land = has_ocean ? smoothstep(0.491, 0.499, continents) : 1.0;
	float coast = has_ocean ? smoothstep(0.479, 0.494, continents) * (1.0 - land) : 0.0;
	float detail = fbm(direction * 42.0 + warp * 0.8 + seed_offset * 4.0);
	float basins = fbm(direction * 7.0 + seed_offset * 2.0);
	vec3 terrain = surface_color.rgb * mix(0.84, 1.13, detail);
	terrain *= mix(0.82, 1.08, smoothstep(0.40, 0.64, basins));
	terrain = mix(terrain, terrain * 1.12, smoothstep(0.60, 0.76, continents));
	vec3 ocean = ocean_color.rgb * mix(0.88, 1.08, detail);
	ocean = mix(ocean, surface_color.rgb * 0.72, coast * 0.48);
	float polar = has_ocean ? smoothstep(0.76, 0.94, abs(direction.y)) : 0.0;
	float cloud_warp = noise(direction * 4.5 + seed_offset + vec3(31.0, 2.0, 13.0));
	float cloud_field = fbm(direction * 10.0 + warp * 1.1 + vec3(cloud_warp * 2.5, 17.0, 3.0));
	float cloud_mask = (clouds && has_ocean) ? smoothstep(0.52, 0.62, cloud_field) : 0.0;
	ALBEDO = has_ocean ? mix(ocean, terrain, land) : terrain;
	ALBEDO = mix(ALBEDO, vec3(0.72, 0.76, 0.78), polar * 0.78);
	ALBEDO = mix(ALBEDO, vec3(0.84, 0.87, 0.84), cloud_mask * 0.32);
	ROUGHNESS = has_ocean ? mix(0.88, 0.58, 1.0 - land) : 0.92;
	METALLIC = 0.0;
	SPECULAR = 0.18;
}
