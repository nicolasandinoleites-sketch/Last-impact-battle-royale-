shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec3 dust_color : source_color = vec3(0.49,0.34,0.23);
uniform float density : hint_range(0.0,1.0) = 0.82;
uniform float wind_time = 0.0;
uniform sampler2D cloud_tex : repeat_enable, filter_linear;
void fragment() {
	float h = UV.y;
	vec2 flow = vec2(UV.x*5.0-wind_time*0.022, h*1.7+wind_time*0.013);
	float broad = texture(cloud_tex,flow).r;
	float fine = texture(cloud_tex,vec2(UV.x*11.0-wind_time*0.044,h*3.4)).r;
	float body = smoothstep(0.12,0.72,broad*0.72+fine*0.28);
	float top = 1.0-smoothstep(0.57,1.0,h+0.16*(broad-0.5));
	float base = 1.0-smoothstep(0.0,0.3,h);
	vec3 dark = dust_color*0.51;
	vec3 light = dust_color*1.43;
	ALBEDO = mix(dark,light,clamp(body*0.68+base*0.32,0.0,1.0));
	ALPHA = clamp((0.18+body*0.70+base*0.18)*top*density,0.0,0.93);
}
