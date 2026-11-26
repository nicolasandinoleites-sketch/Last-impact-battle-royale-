shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec3 dust_color : source_color = vec3(0.51,0.34,0.19);
uniform float density : hint_range(0.0,1.0) = 0.89;
uniform float wind_time = 0.0;
uniform float secondary_layer = 0.0;
uniform sampler2D cloud_tex : repeat_enable, filter_linear;
void vertex() {
	float h = UV.y;
	float swell = sin(UV.x*62.83185-wind_time*0.18)*sin(h*3.14159);
	VERTEX.xz *= 1.0+swell*0.018;
}
void fragment() {
	float h = UV.y;
	float broad = texture(cloud_tex,vec2(UV.x*4.0-wind_time*0.017,h*0.90+wind_time*0.015)).r;
	float fine = texture(cloud_tex,vec2(UV.x*11.0-wind_time*0.035+(broad-0.5)*0.39,h*2.0+broad*0.52)).r;
	float body = smoothstep(0.22,0.78,broad*0.68+fine*0.32);
	float rolling = smoothstep(0.28,0.72,fine);
	float crown = 1.0-smoothstep(0.60,0.97,h+(broad-0.5)*0.40);
	float ground = exp(-h*4.5);
	vec3 sand = dust_color*mix(0.66,1.43,body);
	vec3 dark_cloud = mix(vec3(0.115,0.12,0.13),dust_color*0.83,rolling);
	vec3 lit = mix(sand,dark_cloud,smoothstep(0.16,0.76,h));
	// Local light and dark billows create depth without volumetric ray marching.
	ALBEDO = lit*mix(0.83,1.13,rolling);
	ALPHA = clamp((0.48+body*0.52+ground*0.18)*crown*density*(1.0-secondary_layer*0.10),0.0,0.97);
}
