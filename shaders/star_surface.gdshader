shader_type spatial;
render_mode cull_back, specular_disabled, ambient_light_disabled;

uniform vec4 star_color : source_color = vec4(1.0, 0.91, 0.78, 1.0);
uniform float star_kind = 1.0;
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

float filtered_noise(vec3 p, float frequency, float footprint) {
	// Unresolved granules converge to their mean instead of sparkling at distance.
	float resolved = 1.0 - smoothstep(0.35, 1.2, footprint * frequency);
	return mix(0.5, noise(p * frequency), resolved);
}

void fragment() {
	vec3 surface = normalize(star_local_position);
	float phase = TIME * 0.0008;
	vec3 p = vec3(cos(phase) * surface.x - sin(phase) * surface.z,
		surface.y, sin(phase) * surface.x + cos(phase) * surface.z);
	float footprint = max(length(dFdx(p)), length(dFdy(p)));
	float granules = filtered_noise(p, 105.0, footprint) * 0.60
		+ filtered_noise(p, 230.0, footprint) * 0.28
		+ filtered_noise(p, 480.0, footprint) * 0.12;
	float convection = filtered_noise(p, 19.0, footprint);
	// Quiet granulation, a few active regions, and dark cores with softer penumbrae.
	float activity = filtered_noise(p + vec3(3.1, 7.4, 1.7), 8.0, footprint);
	float latitude = 1.0 - smoothstep(0.35, 0.65, abs(p.y));
	float penumbra = smoothstep(0.72, 0.88, activity) * latitude;
	float umbra = smoothstep(0.86, 0.96, activity) * latitude;
	float ordinary_star = 1.0 - step(2.5, star_kind);
	float texture_strength = mix(0.22, 1.0, ordinary_star);
	float surface_flux = 1.0 + (granules - 0.5) * 0.65 * texture_strength
		+ (convection - 0.5) * 0.12 * texture_strength;
	surface_flux *= 1.0 - (penumbra * 0.48 + umbra * 0.38) * ordinary_star;
	float mu = max(dot(normalize(NORMAL), normalize(VIEW)), 0.0);
	float limb = 0.32 + 0.68 * pow(mu, 0.65);
	// Pure emission avoids a second flat albedo contribution under tone mapping.
	ALBEDO = vec3(0.0);
	EMISSION = star_color.rgb * 0.85 * surface_flux * limb;
}
