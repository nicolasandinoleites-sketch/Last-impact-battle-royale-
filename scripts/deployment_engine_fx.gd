extends Node3D
# Presentation-only engine effect. Attach to an authored nozzle marker (+Z exhaust).
# The optional rotor must be a separate mesh/pivot with local +Z spin axis.
# No changes to collider, flight force, damage or gameplay authority.
var rotor: Node3D
var particles: CPUParticles3D
var glow: MeshInstance3D
var glow_mat: StandardMaterial3D
var plume: MeshInstance3D
var plume_mat: ShaderMaterial
var intensity := 0.0
var requested := 0.0
var phase := 0.0
var radius := 0.10
var exhaust_speed := 8.0
var quality := 0
var aircraft := false
var configured := false
var base_rotor_basis := Basis.IDENTITY
var live := false

func configure(rotor_pivot: Node3D, nozzle_radius: float, is_aircraft: bool, profile: int = 0) -> void:
	if configured:
		return
	rotor = rotor_pivot
	if is_instance_valid(rotor):
		base_rotor_basis = rotor.transform.basis
	radius = maxf(0.01,nozzle_radius)
	aircraft = is_aircraft
	quality = clampi(profile,0,2)
	exhaust_speed = radius*(18.0 if aircraft else 45.0)
	glow = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius*0.65
	disc.bottom_radius = radius*0.65
	disc.height = radius*0.08
	disc.radial_segments = 12
	disc.rings = 1
	glow.mesh = disc
	glow.rotation.x = PI*0.5
	glow.position.z = radius*0.02
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow_mat = StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.albedo_color = Color(1.0,0.42,0.09)
	glow.material_override = glow_mat
	add_child(glow)
	# Two intersecting tapered ribbons: constant-size, low-overdraw exhaust core.
	plume = MeshInstance3D.new()
	var geometry := SurfaceTool.new()
	geometry.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in [Vector3.RIGHT,Vector3.UP]:
		var base: Vector3 = axis*radius*0.62
		var tip: Vector3 = axis*radius*0.22
		var length := radius*(8.0 if aircraft else 10.0)
		var corners := [-base,base,Vector3(0,0,length)+tip,Vector3(0,0,length)-tip]
		var uv := [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]
		for index in [0,1,2,0,2,3]:
			geometry.set_uv(uv[index])
			geometry.add_vertex(corners[index])
	plume.mesh = geometry.commit()
	plume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform float power = 0.0;
uniform vec4 exhaust_color : source_color = vec4(1.0,0.45,0.08,1.0);
void fragment(){
 float side = pow(max(0.0,1.0-abs(UV.x*2.0-1.0)),1.4);
 float tail = pow(max(0.0,1.0-UV.y),1.65);
 float pulse = 0.92+0.08*sin(TIME*25.0-UV.y*13.0);
 ALBEDO = mix(exhaust_color.rgb,vec3(1.0,0.94,0.72),pow(tail,3.0)*0.85);
 ALPHA = power*side*tail*pulse*0.85;
}"""
	plume_mat = ShaderMaterial.new()
	plume_mat.shader = shader
	plume_mat.set_shader_parameter("exhaust_color",Color(0.72,0.81,0.95) if aircraft else Color(1.0,0.40,0.065))
	plume.material_override = plume_mat
	add_child(plume)
	particles = CPUParticles3D.new()
	particles.emitting = false
	particles.amount = [10,18,26][quality] if aircraft else [8,14,20][quality]
	particles.lifetime = 0.85 if aircraft else 0.42
	particles.local_coords = false
	particles.direction = Vector3(0,0,1)
	particles.spread = 6.0 if aircraft else 3.0
	particles.particle_flag_align_y = true
	particles.gravity = Vector3.ZERO
	particles.initial_velocity_min = exhaust_speed*0.8
	particles.initial_velocity_max = exhaust_speed*1.2
	particles.scale_amount_min = 0.65
	particles.scale_amount_max = 1.0
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var puff := SphereMesh.new()
	puff.radius = radius*0.23
	puff.height = radius*1.9
	puff.radial_segments = 6
	puff.rings = 3
	particles.mesh = puff
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	particles.material_override = mat
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0,0.18,0.65,1.0])
	ramp.colors = PackedColorArray([Color(1.0,0.75,0.30,0.85),Color(1.0,0.42,0.09,0.65),Color(0.70,0.65,0.60,0.20),Color(0.65,0.65,0.65,0.0)] if aircraft else [Color(1.0,0.91,0.55,0.95),Color(1.0,0.49,0.08,0.8),Color(0.74,0.22,0.05,0.25),Color(0.30,0.18,0.12,0.0)])
	particles.color_ramp = ramp
	add_child(particles)
	configured = true
	reset_effect()

func set_power(throttle: float, enabled: bool) -> void:
	requested = clampf(throttle,0.0,1.0) if enabled else 0.0
	live = enabled

func update_effect(delta: float, within_fx_range: bool = true) -> void:
	if not configured:
		return
	intensity = lerpf(intensity,requested,1.0-exp(-maxf(delta,0.0)*9.0))
	if intensity<0.005:
		intensity = 0.0
	phase = fposmod(phase+maxf(delta,0.0)*intensity*(85.0 if aircraft else 120.0),TAU)
	if is_instance_valid(rotor):
		rotor.transform.basis = base_rotor_basis*Basis(Vector3(0,0,1),phase)
	var active_fx := live and within_fx_range and intensity>0.03
	glow.visible = active_fx
	plume.visible = active_fx
	plume.scale = Vector3(1.0,1.0,0.30+0.70*intensity)
	plume_mat.set_shader_parameter("power",intensity)
	glow.scale = Vector3.ONE*(0.75+0.25*intensity)
	glow_mat.albedo_color = Color(1.0,0.35+0.47*intensity,0.06+0.19*intensity)
	if active_fx and not particles.visible:
		particles.show()
		particles.restart()
	particles.visible = active_fx
	particles.emitting = active_fx
	particles.initial_velocity_min = exhaust_speed*(0.35+0.45*intensity)
	particles.initial_velocity_max = exhaust_speed*(0.55+0.65*intensity)

func reset_effect() -> void:
	requested = 0.0
	intensity = 0.0
	phase = 0.0
	live = false
	if is_instance_valid(rotor):
		rotor.transform.basis = base_rotor_basis
	if is_instance_valid(glow):
		glow.hide()
	if is_instance_valid(plume):
		plume.hide()
		plume_mat.set_shader_parameter("power",0.0)
	if is_instance_valid(particles):
		particles.emitting = false
		particles.restart()
		particles.emitting = false
		particles.hide()
