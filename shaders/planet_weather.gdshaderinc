float weather_hash(vec3 p, float seed_value) {
	p = fract(p * 0.3183099 + seed_value * 0.0001);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float weather_noise(vec3 p, float seed_value) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(weather_hash(i, seed_value), weather_hash(i + vec3(1.0, 0.0, 0.0), seed_value), f.x);
	float b = mix(weather_hash(i + vec3(0.0, 1.0, 0.0), seed_value), weather_hash(i + vec3(1.0, 1.0, 0.0), seed_value), f.x);
	float c = mix(weather_hash(i + vec3(0.0, 0.0, 1.0), seed_value), weather_hash(i + vec3(1.0, 0.0, 1.0), seed_value), f.x);
	float d = mix(weather_hash(i + vec3(0.0, 1.0, 1.0), seed_value), weather_hash(i + vec3(1.0, 1.0, 1.0), seed_value), f.x);
	return mix(mix(a, b, f.y), mix(c, d, f.y), f.z);
}

float weather_fbm(vec3 p, float seed_value) {
	float value = 0.0;
	float weight = 0.5;
	for (int octave = 0; octave < 5; octave++) {
		value += weather_noise(p, seed_value) * weight;
		p = p * 2.03 + vec3(11.3, 5.7, 17.1);
		weight *= 0.5;
	}
	return value;
}

float weather_coverage(vec3 direction, float seed_value, float time_value) {
	direction = normalize(direction);
	float drift = time_value * 0.012;
	float c = cos(drift);
	float s = sin(drift);
	vec3 flow_direction = normalize(vec3(
		direction.x * c - direction.z * s,
		direction.y,
		direction.x * s + direction.z * c
	));
	vec3 offset = vec3(seed_value * 0.013);
	vec3 warp = vec3(weather_noise(flow_direction * 3.5 + offset, seed_value), weather_noise(flow_direction * 3.5 + offset + 17.0, seed_value), weather_noise(flow_direction * 3.5 + offset + 39.0, seed_value)) - 0.5;
	float fronts = weather_fbm(flow_direction * vec3(12.0, 20.0, 12.0) + warp * 3.0 + offset, seed_value);
	float filaments = weather_fbm(flow_direction * 65.0 + warp + offset, seed_value);
	float density = fronts * 0.82 + filaments * 0.18;
	return smoothstep(0.43, 0.72, density);
}

float weather_shadow(vec3 relative_position, vec3 sun_vector, float shell_radius, float seed_value, float time_value) {
	float position_length = length(relative_position);
	if (shell_radius <= position_length) {
		return 0.0;
	}
	vec3 sun = normalize(sun_vector);
	float projection = dot(relative_position, sun);
	float exit_distance = -projection + sqrt(projection * projection + shell_radius * shell_radius - dot(relative_position, relative_position));
	vec3 cloud_direction = normalize(relative_position + sun * exit_distance);
	float night = smoothstep(0.0, 0.15, dot(normalize(relative_position), sun));
	return weather_coverage(cloud_direction, seed_value, time_value) * night;
}
