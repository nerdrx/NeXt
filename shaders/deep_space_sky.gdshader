shader_type sky;
render_mode use_debanding;

uniform vec4 nebula_color : source_color = vec4(0.16, 0.23, 0.45, 1.0);
uniform vec4 nebula_accent : source_color = vec4(0.5, 0.15, 0.48, 1.0);

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y), mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float band = pow(max(0.0, 1.0 - abs(d.y + 0.12)), 5.0);
	float cloud = noise(d * 11.0 + vec3(3.0, 0.0, 7.0)) * 0.65 + noise(d * 24.0) * 0.35;
	float nebula = smoothstep(0.35, 0.83, cloud) * band;
	vec3 col = vec3(0.004, 0.008, 0.02) + nebula_color.rgb * nebula * 0.62;
	col += nebula_accent.rgb * smoothstep(0.68, 0.94, cloud) * band * 0.6;
	float star_field = step(0.9982, hash(floor(d * 1800.0)));
	float bright_star = step(0.99975, hash(floor(d * 900.0)));
	col += vec3(0.55, 0.68, 0.9) * star_field * 0.7 + vec3(1.0, 0.8, 0.56) * bright_star * 2.0;
	COLOR = col;
}
