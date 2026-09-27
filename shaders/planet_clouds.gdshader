shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled, fog_disabled;

uniform vec4 cloud_color : source_color = vec4(0.88, 0.92, 1.0, 1.0);
uniform float seed = 0.0;
uniform vec3 sun_direction = vec3(-0.5, 0.47, 0.73);
uniform float light_strength = 1.0;

varying vec3 radial_world;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + seed * 0.0001);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(hash(i), hash(i + vec3(1.0, 0.0, 0.0)), f.x);
	float b = mix(hash(i + vec3(0.0, 1.0, 0.0)), hash(i + vec3(1.0, 1.0, 0.0)), f.x);
	float c = mix(hash(i + vec3(0.0, 0.0, 1.0)), hash(i + vec3(1.0, 0.0, 1.0)), f.x);
	float d = mix(hash(i + vec3(0.0, 1.0, 1.0)), hash(i + vec3(1.0, 1.0, 1.0)), f.x);
	return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}

float weather(vec3 p) {
	float value = 0.0;
	float weight = 0.5;
	for (int octave = 0; octave < 5; octave++) {
		value += noise(p) * weight;
		p = p * 2.03 + vec3(11.3, 5.7, 17.1);
		weight *= 0.5;
	}
	return value;
}

void vertex() {
	radial_world = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 direction = normalize(radial_world);
	float drift = TIME * 0.012;
	float c = cos(drift);
	float s = sin(drift);
	vec3 flow_direction = normalize(vec3(
		direction.x * c - direction.z * s,
		direction.y,
		direction.x * s + direction.z * c
	));
	vec3 offset = vec3(seed * 0.013);
	vec3 warp = vec3(noise(flow_direction * 3.5 + offset), noise(flow_direction * 3.5 + offset + 17.0), noise(flow_direction * 3.5 + offset + 39.0)) - 0.5;
	float fronts = weather(flow_direction * vec3(12.0, 20.0, 12.0) + warp * 3.0 + offset);
	float filaments = weather(flow_direction * 65.0 + warp + offset);
	float density = fronts * 0.82 + filaments * 0.18;
	float coverage = smoothstep(0.43, 0.72, density);
	float day = smoothstep(-0.18, 0.28, dot(direction, normalize(sun_direction)));
	ALBEDO = cloud_color.rgb * mix(0.55, 1.0, coverage) * (0.012 + day * clamp(light_strength, 0.0, 1.5));
	ALPHA = coverage * cloud_color.a * 0.88;
}
