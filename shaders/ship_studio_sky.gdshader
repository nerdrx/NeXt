shader_type sky;

// Broad reflection cards, evaluated only for the preview radiance map.
// No external HDR asset is needed; replace with authored studio lighting later.
float softbox(vec3 direction, vec3 facing, vec3 up, vec2 half_size) {
 vec3 forward = normalize(facing);
 vec3 right = normalize(cross(forward, up));
 vec3 vertical = cross(right, forward);
 float depth = dot(direction, forward);
 vec2 projected = vec2(dot(direction, right), dot(direction, vertical)) / max(depth, 0.001);
 vec2 edge = smoothstep(half_size * 0.85, half_size, abs(projected));
 return (1.0-edge.x) * (1.0-edge.y) * step(0.001, depth);
}

void sky() {
 vec3 direction = normalize(EYEDIR);
 COLOR = mix(vec3(0.008, 0.012, 0.018), vec3(0.045, 0.055, 0.07), smoothstep(-0.5, 0.8, direction.y));
 COLOR += vec3(1.0, 0.94, 0.84) * 3.5 * softbox(direction, vec3(-0.55, 0.8, -0.3), vec3(0.0, 0.0, -1.0), vec2(0.7, 0.28));
 COLOR += vec3(0.65, 0.8, 1.0) * 1.8 * softbox(direction, vec3(0.8, 0.3, 0.3), vec3(0.0, 1.0, 0.0), vec2(0.12, 0.8));
 COLOR += vec3(0.9, 0.94, 1.0) * 2.0 * softbox(direction, vec3(0.1, 0.6, 0.9), vec3(0.0, 1.0, 0.0), vec2(0.6, 0.2));
}
