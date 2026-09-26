shader_type spatial;
render_mode unshaded, cull_back;

uniform vec4 star_color : source_color = vec4(1.0, 0.7, 0.32, 1.0);
uniform float star_kind = 0.0;
varying vec3 star_local_position;

void vertex() {
	star_local_position = VERTEX;
}

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
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

void fragment() {
	vec3 p = normalize(star_local_position);
	float turbulence = noise(p * (star_kind == 0.0 ? 16.0 : 24.0)) * 0.65 + noise(p * 42.0) * 0.35;
	float granulation = smoothstep(0.18, 0.88, turbulence);
	vec3 hot = mix(star_color.rgb * 0.4, vec3(1.0, 0.92, 0.78), granulation * 0.72);
	float limb = 0.72 + 0.28 * pow(max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 0.7);
	ALBEDO = hot;
	EMISSION = hot * (2.1 + granulation * 1.4) * limb;
}
