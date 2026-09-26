shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, blend_add, shadows_disabled;

uniform vec4 atmosphere_color : source_color = vec4(0.3, 0.65, 1.0, 1.0);

void fragment() {
	float fresnel = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 3.2);
	ALBEDO = atmosphere_color.rgb;
	ALPHA = fresnel * 0.72;
}
