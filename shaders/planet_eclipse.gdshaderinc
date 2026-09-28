// Local planet coordinates keep these small through floating-origin rebases.
uniform vec3 planet_sun_position = vec3(-1700.0, 1150.0, -4100.0);
uniform int eclipse_count = 0;
uniform vec4 eclipse_bodies[8];

float primary_visibility(vec3 sample_position) {
	vec3 ray = planet_sun_position - sample_position;
	float ray_length_squared = dot(ray, ray);
	if (ray_length_squared < 0.000001) return 1.0;
	float visibility = 1.0;
	for (int i = 0; i < 8; i++) {
		if (i >= eclipse_count) break;
		vec4 body = eclipse_bodies[i];
		if (body.w <= 0.0) continue;
		float t = clamp(dot(body.xyz - sample_position, ray) / ray_length_squared, 0.0, 1.0);
		float distance_to_ray = length(sample_position + ray * t - body.xyz);
		// One-pixel antialiasing of a point-source shadow, not a finite-star penumbra.
		float edge = max(fwidth(distance_to_ray), 0.001);
		visibility = min(visibility, smoothstep(body.w - edge, body.w + edge, distance_to_ray));
	}
	return visibility;
}
