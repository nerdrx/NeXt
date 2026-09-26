shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 ground_color : source_color = vec4(0.25, 0.29, 0.28, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 p = UV * 96.0;
	float grit = noise(p) * 0.62 + noise(p * 3.7) * 0.25 + noise(p * 14.0) * 0.13;
	float striation = smoothstep(0.65, 0.82, noise(p * vec2(1.1, 7.0)));
	ALBEDO = ground_color.rgb * mix(0.58, 1.18, grit) + vec3(0.08, 0.075, 0.06) * striation;
	ROUGHNESS = 0.96;
	METALLIC = 0.0;
}
