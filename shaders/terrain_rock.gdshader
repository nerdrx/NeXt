shader_type spatial;
render_mode diffuse_burley;

uniform vec3 planet_anchor;
varying vec3 rock_position;

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x),
		mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x),
		mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}

void vertex() {
	rock_position = VERTEX + planet_anchor;
}

void fragment() {
	float strata = noise(rock_position * 0.3);
	float stone = noise(rock_position * 2.5);
	float grit = noise(rock_position * 32.0);
	float veins = smoothstep(0.44, 0.51, noise(rock_position * 1.1));
	vec3 base = mix(COLOR.rgb, vec3(0.26, 0.25, 0.23), 0.55);
	ALBEDO = base * (0.48 + strata * 0.5 + stone * 0.32 + grit * 0.16) * mix(0.75, 1.0, veins);
	ROUGHNESS = 0.8 + grit * 0.18;
}
