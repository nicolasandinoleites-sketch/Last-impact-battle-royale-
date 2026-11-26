shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled, shadows_disabled;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D cloud_tex : repeat_enable, filter_linear;
uniform vec2 storm_center = vec2(0.0);
uniform float safe_radius = 54.0;
uniform float wind_time = 0.0;
uniform int sample_count = 2;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

// Return extinction density and density-weighted cloud shade in world space.
vec2 dust_at(vec3 p) {
	// Roof reaches at most 39 m, plus 9 m feather. Density is exactly zero above it.
	if (p.y >= 48.0) { return vec2(0.0); }
	float edge = smoothstep(-5.0,8.0,length(p.xz-storm_center)-safe_radius);
	if (edge <= 0.0) { return vec2(0.0); }
	vec2 uv = p.xz*0.027 + vec2(p.y*0.012,-p.y*0.019) + vec2(-wind_time*0.017,wind_time*0.007);
	float n = texture(cloud_tex,uv).r;
	float roof = 30.0 + (n-0.5)*18.0;
	float vertical = 1.0-smoothstep(12.0,roof+9.0,p.y);
	float billow = mix(0.57,1.22,smoothstep(0.12,0.85,n));
	float density = edge*vertical*billow;
	float shade = clamp(0.25+0.55*smoothstep(4.0,30.0,p.y)+(n-0.5)*0.15,0.0,1.0);
	return vec2(density,density*shade);
}

vec2 segment(vec3 origin,vec3 ray,float a,float b) {
	float span = max(0.0,b-a);
	if (span<0.001) { return vec2(0.0); }
	if (sample_count==1) { return dust_at(origin+ray*(a+span*0.5))*span; }
	vec2 s0 = dust_at(origin+ray*(a+span*0.22));
	vec2 s1 = dust_at(origin+ray*(a+span*0.72));
	return (s0+s1)*span*0.5;
}

void fragment() {
	float raw = texture(scene_depth,SCREEN_UV).r;
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV,raw)*2.0-1.0;
	#else
	vec3 ndc = vec3(SCREEN_UV*2.0-1.0,raw);
	#endif
	vec4 view = INV_PROJECTION_MATRIX*vec4(ndc,1.0);
	vec3 point = view.xyz / max(abs(view.w),0.00001);
	vec3 ray = normalize((INV_VIEW_MATRIX*vec4(normalize(point),0.0)).xyz);
	vec3 origin = INV_VIEW_MATRIX[3].xyz;
	float far_t = min(length(point),130.0);
	// Intersect the safe interior, then integrate only the outside portions.
	vec2 o = origin.xz-storm_center;
	vec2 d = ray.xz;
	float aa = dot(d,d);
	float bb = dot(o,d);
	float rr = max(1.0,safe_radius-5.0);
	float cc = dot(o,o)-rr*rr;
	float disc = bb*bb-aa*cc;
	vec2 accum = vec2(0.0);
	// A segment with both endpoints in the inner safe disk cannot cross its boundary.
	// Conservative margin avoids changing boundary pixels due to floating-point error.
	vec2 end_xz = o + d*far_t;
	float inner = max(0.0,rr-0.001);
	bool wholly_safe = dot(o,o)<inner*inner && dot(end_xz,end_xz)<inner*inner;
	if (wholly_safe) {
		accum = vec2(0.0);
	} else if (aa>0.00001 && disc>0.0) {
		float root = sqrt(disc);
		float enter = (-bb-root)/aa;
		float leave = (-bb+root)/aa;
		accum = segment(origin,ray,0.0,clamp(enter,0.0,far_t));
		accum += segment(origin,ray,clamp(leave,0.0,far_t),far_t);
	} else if (cc>=0.0) {
		accum = segment(origin,ray,0.0,far_t);
	}
	float tint = accum.y/max(accum.x,0.0001);
	vec3 warm = vec3(0.66,0.47,0.28);
	vec3 dark = vec3(0.33,0.31,0.29);
	ALBEDO = mix(warm,dark,tint);
	ALPHA = clamp(1.0-exp(-accum.x*0.083),0.0,0.975);
}
