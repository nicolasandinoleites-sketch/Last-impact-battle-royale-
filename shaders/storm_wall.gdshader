shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec3 dust_color : source_color = vec3(0.51,0.34,0.19);
uniform float density : hint_range(0.0,1.0) = 0.89;
uniform float wind_time = 0.0;
uniform float secondary_layer = 0.0;
uniform float camera_fade_start = 2.5;
uniform float camera_fade_end = 11.0;
uniform sampler2D cloud_tex : repeat_enable, filter_linear;
void vertex() {
	float h = UV.y;
	float swell = sin(UV.x*62.83185-wind_time*0.18)*sin(h*3.14159);
	VERTEX.xz *= 1.0+swell*0.018;
}
void fragment() {
	float h = UV.y;
	float broad = texture(cloud_tex,vec2(UV.x*4.0-wind_time*0.017,h*0.90+wind_time*0.015)).r;
	float fine = texture(cloud_tex,vec2(UV.x*13.0-wind_time*0.039,h*3.0+wind_time*0.009)).r;
	float body = smoothstep(0.12,0.88,broad*0.75+fine*0.25);
	float rolling = smoothstep(0.10,0.90,fine);
	float crown = 1.0-smoothstep(0.60,0.97,h+(broad-0.5)*0.40);
	float ground = exp(-h*4.5);
	vec3 sand = dust_color*mix(0.88,1.20,body);
	vec3 dark_cloud = mix(vec3(0.16,0.15,0.14),dust_color*0.84,body);
	vec3 lit = mix(sand,dark_cloud,smoothstep(0.16,0.76,h));
	// Local light and dark billows create depth without volumetric ray marching.
	ALBEDO = lit*mix(0.94,1.06,rolling);
	// Fade actual storm surface near the camera; local fog replaces it.
	float camera_fade = smoothstep(camera_fade_start,camera_fade_end,length(VERTEX));
	// Feather ground intersection so it cannot look like a hard circular sheet.
	float ground_feather = mix(0.12,1.0,smoothstep(0.0,0.13,h));
	ALPHA = clamp((0.48+body*0.45+ground*0.13)*crown*density*(1.0-secondary_layer*0.10)*camera_fade*ground_feather,0.0,0.95);
}
