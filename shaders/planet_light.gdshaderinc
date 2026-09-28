// Shared primary-relative direct lighting for globes and streamed ground.
void light() {
	vec3 l = LIGHT_IS_DIRECTIONAL ? normalize(stellar_direction_view) : LIGHT;
	// Global parallel shadow maps do not describe this per-planet primary vector.
	float attenuation = LIGHT_IS_DIRECTIONAL ? eclipse_visibility : ATTENUATION;
	float nl = max(dot(NORMAL, l), 0.0);
	if (nl > 0.0 && attenuation > 0.0) {
		DIFFUSE_LIGHT += nl * LIGHT_COLOR * attenuation / PI;
		vec3 half_vector = normalize(VIEW + l);
		float nv = max(dot(NORMAL, VIEW), 0.001);
		float nh = max(dot(NORMAL, half_vector), 0.0);
		float vh = max(dot(VIEW, half_vector), 0.0);
		float a2 = pow(max(ROUGHNESS, 0.08), 4.0);
		float denominator = nh * nh * (a2 - 1.0) + 1.0;
		float distribution = a2 / (PI * denominator * denominator);
		float k = pow(ROUGHNESS + 1.0, 2.0) / 8.0;
		float geometry = nv / (nv * (1.0 - k) + k) * nl / (nl * (1.0 - k) + k);
		float fresnel = 0.04 + 0.96 * pow(1.0 - vh, 5.0);
		SPECULAR_LIGHT += LIGHT_COLOR * attenuation * distribution * geometry * fresnel / (4.0 * nv);
	}
}
