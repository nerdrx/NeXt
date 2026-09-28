shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

uniform vec4 star_color : source_color = vec4(1.0, 0.91, 0.78, 1.0);

void vertex() {
	// Camera-facing local halo; regular depth testing lets planets eclipse it.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 offset = UV * 2.0 - 1.0;
	float radius = length(offset);
	float angle = atan(offset.y, offset.x);
	float rays = 0.97 + 0.03 * sin(angle * 17.0 + sin(angle * 7.0) * 1.7);
	float halo = exp(-max(radius - 0.5, 0.0) * 14.0) * rays;
	halo *= 1.0 - smoothstep(0.85, 1.0, radius);
	ALBEDO = star_color.rgb * 1.4;
	ALPHA = halo * 0.32;
}
