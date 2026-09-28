shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 paint : source_color = vec4(0.45, 0.48, 0.5, 1.0);
uniform float base_roughness = 0.45;
uniform float roughness_variation = 0.12;
uniform float metalness = 0.05;
uniform float coating = 0.25;
uniform float panel_strength : hint_range(0.0, 1.0) = 0.0;
uniform float industrial_detail : hint_range(0.0, 1.0) = 0.0;
// Optional family paint scheme, expressed in hull-local metres.
uniform float livery_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 livery_paint : source_color = vec4(0.75, 0.72, 0.64, 1.0);
uniform vec3 hull_extent = vec3(10.0);
uniform vec2 panel_pitch = vec2(2.8, 2.8);
uniform vec3 panel_origin = vec3(0.0);
varying vec3 local_position;
varying vec3 local_normal;
float hash3(vec3 p) {
 p = fract(p * 0.1031);
 p += dot(p, p.yzx + 33.33);
 return fract((p.x + p.y) * p.z);
}
float grain(vec3 p) {
 vec3 i = floor(p); vec3 f = fract(p); f = f*f*(3.0-2.0*f);
 return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex() { local_position = VERTEX; local_normal = NORMAL; }
void fragment() {
 float surface_footprint = length(fwidth(local_position));
 float mottling_detail = 1.0 - smoothstep(0.3, 1.2, surface_footprint * 3.5);
 float mottling = mix(0.5, grain(local_position * 3.5), mottling_detail);
 float footprint = surface_footprint * 95.0;
 float detail = 1.0 - smoothstep(0.3, 1.2, footprint);
 float micro = mix(0.5, grain(local_position * 95.0), detail);
 float abrasion = smoothstep(0.77, 0.94, grain(local_position * vec3(85.0, 2.0, 2.0))) * detail;
 // Project from object space: paneling follows the ship, never the world origin.
 vec3 axis = abs(local_normal);
 vec3 panel_position = local_position + panel_origin;
 vec2 surface = panel_position.xz;
 if (axis.x > axis.y && axis.x > axis.z) { surface = panel_position.zy; }
 else if (axis.z > axis.y) { surface = panel_position.xy; }
 vec2 pitch = max(panel_pitch, vec2(0.05));
 vec2 panel_uv = surface / pitch + vec2(0.5);
 vec2 edge = min(fract(panel_uv), 1.0-fract(panel_uv)) * pitch;
 float edge_distance = min(edge.x, edge.y);
 float pixel = max(length(fwidth(surface)), 0.0001);
 float panel_detail = 1.0 - smoothstep(0.03, 0.14, pixel);
 float groove = (1.0-smoothstep(0.003, 0.003+pixel, edge_distance)) * min(1.0, 0.006/pixel) * panel_detail * panel_strength;
 // Recessed fasteners and seal dirt establish metre scale without luminous trim.
 vec2 corner_offset = edge - vec2(0.065);
 float bolt_radius = length(corner_offset);
 // Fade each feature at its own physical scale; widening it by a whole pixel
 // without reducing coverage would turn distant fasteners into dark blobs.
 float fastener_detail = (1.0-smoothstep(0.006, 0.025, pixel)) * industrial_detail;
 float bolt = (1.0-smoothstep(0.012-pixel*0.5, 0.012+pixel*0.5, bolt_radius)) * fastener_detail;
 float bolt_rim = (1.0-smoothstep(0.022-pixel*0.5, 0.022+pixel*0.5, bolt_radius)) * fastener_detail;
 float seal_dirt = (1.0-smoothstep(0.012, 0.075, edge_distance)) * industrial_detail * panel_strength * panel_detail;
 float tone_detail = 1.0-smoothstep(0.25, 1.0, length(fwidth(panel_uv)));
 float panel_tone = mix(0.5, hash3(vec3(floor(panel_uv), 7.0)), tone_detail);
 float panel_height = smoothstep(0.0, 0.018, edge_distance) * 0.002 * panel_detail * panel_strength;
 float finish_tone = mix(0.94 + 0.08 * mottling, 0.975 + 0.035 * mottling, panel_strength);
 ALBEDO = paint.rgb * finish_tone * (1.0 + (panel_tone-0.5)*0.065*panel_strength);
 // Broad painted shoulders establish a readable silhouette before fine detail.
 vec3 hull_uv = local_position / max(hull_extent, vec3(0.1));
 float paint_pixel = max(length(fwidth(hull_uv.xz)), 0.0001);
 float shoulder = abs(hull_uv.x) - (0.22 + hull_uv.z * 0.10);
 float stripe = (1.0-smoothstep(0.045-paint_pixel, 0.045+paint_pixel, abs(shoulder))) * smoothstep(0.25, 0.8, local_normal.y);
 // Angled flank identification band, with the same metre-scale filtered edge.
 float side_band = (1.0-smoothstep(0.045-paint_pixel, 0.045+paint_pixel, abs(hull_uv.z + hull_uv.y*0.35 + 0.12))) * smoothstep(0.4, 0.85, abs(local_normal.x));
 float livery = max(stripe, side_band) * livery_strength;
 ALBEDO = mix(ALBEDO, livery_paint.rgb * finish_tone, livery);
 ALBEDO *= 1.0 - groove * 0.42 - seal_dirt * 0.13;
 ALBEDO = mix(ALBEDO, vec3(0.09), bolt_rim * 0.38);
 ALBEDO = mix(ALBEDO, vec3(0.19), bolt);
 ROUGHNESS = clamp(base_roughness + (mottling-0.5)*roughness_variation + (micro-0.5)*0.065 + abrasion*0.07 + groove*0.14 + seal_dirt*0.08, 0.12, 0.92);
 METALLIC = mix(metalness, 0.75, bolt);
 SPECULAR = 0.5;
 CLEARCOAT = coating;
 CLEARCOAT_ROUGHNESS = 0.35;
 // Submillimetre finish variation; fade below pixel size to avoid sparkle.
 float height = (micro-0.5) * 0.00012 + panel_height - bolt_rim * 0.0015;
 vec3 q0 = dFdx(VERTEX); vec3 q1 = dFdy(VERTEX);
 vec3 r1 = cross(q1, NORMAL); vec3 r2 = cross(NORMAL, q0);
 float det = dot(q0, r1);
 if (abs(det) > 0.000001) {
  NORMAL = normalize(abs(det)*NORMAL - sign(det)*(dFdx(height)*r1+dFdy(height)*r2));
 }
}
