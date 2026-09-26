shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 paint : source_color = vec4(0.13, 0.18, 0.22, 1.0);
uniform float metal = 0.55;
uniform float rough = 0.46;
float grain(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 edge = min(UV, 1.0 - UV);
	float seam = 1.0 - smoothstep(0.006, 0.012, min(edge.x, edge.y));
	float bevel = smoothstep(0.013, 0.02, min(edge.x, edge.y)) * (1.0 - smoothstep(0.02, 0.027, min(edge.x, edge.y)));
	float variation = grain(floor(UV * 350.0));
	ALBEDO = paint.rgb * (0.96 + variation * 0.07) * (1.0 - seam * 0.68) + vec3(bevel * 0.055);
	METALLIC = metal;
	ROUGHNESS = clamp(rough + variation * 0.07 + seam * 0.2, 0.1, 0.95);
	SPECULAR = 0.5;
}
