shader_type spatial;
render_mode ambient_light_disabled, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 surface_color : source_color = vec4(0.3, 0.5, 0.32, 1.0);
uniform vec4 ocean_color : source_color = vec4(0.04, 0.12, 0.22, 1.0);
uniform float seed = 0.0;
uniform bool clouds = true;
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
	for (int octave = 0; octave < 6; octave++) {
		sum += noise(p) * amplitude;
		p *= 2.0;
		amplitude *= 0.5;
	}
	return sum;
}

void fragment() {
	vec3 direction = normalize(planet_local_position);
	float continents = fbm(direction * 5.2 + vec3(seed * 0.013));
	float land = smoothstep(0.48, 0.53, continents);
	float coast = smoothstep(0.455, 0.49, continents) * (1.0 - land);
	float detail = fbm(direction * 128.0 + vec3(seed * 0.07));
	float ridges = 1.0 - abs(fbm(direction * 64.0 + vec3(seed * 0.03)) * 2.0 - 1.0);
	vec3 terrain = surface_color.rgb * mix(0.72, 1.19, detail);
	terrain = mix(terrain * 0.76, terrain * 1.12, smoothstep(0.60, 0.78, continents));
	terrain *= mix(0.92, 1.08, ridges);
	vec3 ocean = ocean_color.rgb * (0.76 + detail * 0.30);
	ocean = mix(ocean, vec3(0.55, 0.49, 0.36), coast * 0.7);
	float polar = smoothstep(0.72, 0.93, abs(direction.y));
	terrain = mix(terrain, vec3(0.68, 0.71, 0.68), polar * 0.82);
	float cloud_field = fbm(direction * 20.0 + vec3(17.0, seed * 0.01, 3.0));
	float cloud_mask = clouds ? smoothstep(0.53, 0.61, cloud_field) : 0.0;
	ALBEDO = mix(ocean, terrain, land);
	ALBEDO = mix(ALBEDO, vec3(0.84, 0.87, 0.84), cloud_mask * 0.42);
	ROUGHNESS = mix(0.26, 0.88, land);
	METALLIC = 0.0;
	SPECULAR = 0.65;
}
