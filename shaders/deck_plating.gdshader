shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 paint : source_color = vec4(0.17, 0.20, 0.22, 1.0);
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void fragment() {
	vec2 p = world_pos.xz;
	vec2 cell = p / vec2(2.5, 5.0);
	vec2 q = fract(cell);
	vec2 border = min(q, 1.0-q);
	float edge = min(border.x, border.y);
	float width = max(fwidth(edge), 0.0002);
	float seam = 1.0 - smoothstep(0.003-width, 0.003+width, edge);
	float lip = (1.0-smoothstep(0.011,0.016,edge)) * (1.0-seam);
	float panel_tone = hash(floor(cell)) * 0.14;
	float rough_noise = noise(p * 9.0);
	float scuff = pow(noise(p * vec2(2.0, 17.0)), 4.0) * 0.045;
	vec2 bolt = min(abs(q-vec2(0.04,0.025)), abs(q-vec2(0.96,0.975)));
	float bolt_head = 1.0-smoothstep(0.004,0.006,length(bolt * vec2(0.5,1.0)));
	vec3 base = paint.rgb * (0.94+panel_tone) + vec3(scuff);
	base = mix(base, vec3(0.018,0.022,0.027), seam * 0.85);
	base += vec3(lip * 0.025);
	base = mix(base, vec3(0.12,0.14,0.15), bolt_head * 0.75);
	float hazard = step(41.0,abs(p.x)) * (1.0-step(42.0,abs(p.x)));
	float stripe = step(0.5,fract((p.x+p.y)*0.6));
	base = mix(base,mix(vec3(0.07),vec3(0.47,0.34,0.12),stripe),hazard*0.75);
	ALBEDO = base;
	METALLIC = 0.68;
	ROUGHNESS = clamp(0.41 + rough_noise*0.16 + seam*0.3,0.0,1.0);
	SPECULAR = 0.5;
}
