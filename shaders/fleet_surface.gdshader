shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 paint : source_color = vec4(0.45, 0.48, 0.5, 1.0);
uniform float base_roughness = 0.45;
uniform float metalness = 0.05;
uniform float coating = 0.25;
varying vec3 local_position;
float hash3(vec3 p) {
 p = fract(p * 0.1031);
 p += dot(p, p.yzx + 33.33);
 return fract((p.x + p.y) * p.z);
}
float grain(vec3 p) {
 vec3 i = floor(p); vec3 f = fract(p); f = f*f*(3.0-2.0*f);
 return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex() { local_position = VERTEX; }
void fragment() {
 float mottling = grain(local_position * 3.5);
 float footprint = length(fwidth(local_position)) * 95.0;
 float detail = 1.0 - smoothstep(0.3, 1.2, footprint);
 float micro = mix(0.5, grain(local_position * 95.0), detail);
 float abrasion = smoothstep(0.77, 0.94, grain(local_position * vec3(85.0, 2.0, 2.0))) * detail;
 ALBEDO = paint.rgb * (0.94 + 0.08 * mottling);
 ROUGHNESS = clamp(base_roughness + (mottling-0.5)*0.12 + (micro-0.5)*0.065 + abrasion*0.07, 0.12, 0.92);
 METALLIC = metalness;
 SPECULAR = 0.5;
 CLEARCOAT = coating;
 CLEARCOAT_ROUGHNESS = 0.35;
 // Submillimetre finish variation; fade below pixel size to avoid sparkle.
 float height = (micro-0.5) * 0.00012;
 vec3 q0 = dFdx(VERTEX); vec3 q1 = dFdy(VERTEX);
 vec3 r1 = cross(q1, NORMAL); vec3 r2 = cross(NORMAL, q0);
 float det = dot(q0, r1);
 if (abs(det) > 0.000001) {
  NORMAL = normalize(abs(det)*NORMAL - sign(det)*(dFdx(height)*r1+dFdy(height)*r2));
 }
}
