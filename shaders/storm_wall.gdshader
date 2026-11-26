shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec3 dust_color : source_color = vec3(0.53,0.38,0.25);
uniform float density : hint_range(0.0,1.0) = 0.82;
uniform float wind_time = 0.0;
uniform sampler2D cloud_tex : repeat_enable, filter_linear;
void fragment() {
	float h = UV.y;
	float broad = texture(cloud_tex,vec2(UV.x*6.0-wind_time*0.018,h*1.15+wind_time*0.011)).r;
	float fine = texture(cloud_tex,vec2(UV.x*13.0-wind_time*0.039+(broad-0.5)*0.35,h*2.4+broad*0.38)).r;
	float body = smoothstep(0.18,0.77,broad*0.70+fine*0.30);
	float crown = 1.0-smoothstep(0.62,1.0,h+(broad-0.5)*0.42);
	float ground = exp(-h*5.0);
	vec3 lower = dust_color*mix(0.80,1.45,body);
	vec3 upper = mix(vec3(0.16,0.18,0.20),dust_color*0.70,body);
	ALBEDO = mix(lower,upper,smoothstep(0.10,0.82,h));
	ALPHA = clamp((0.40+body*0.48+ground*0.14)*crown*density,0.0,0.92);
}
