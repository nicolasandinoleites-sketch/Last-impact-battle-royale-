extends Node3D
const START_RADIUS := 54.0
const END_RADIUS := 6.0
const GRACE := 25.0
const SHRINK_TIME := 180.0
const STORM_HEIGHT := 25.0
const StormShader = preload("res://shaders/storm_wall.gdshader")
var radius := START_RADIUS
var elapsed := 0.0
var phase := 0
var ring: MeshInstance3D
var wall: MeshInstance3D
var storm_material: ShaderMaterial
var quality := 0
var wind_clock := 0.0

func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("e9b16d")
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP,material)
	for i in range(97):
		var angle := float(i)*TAU/96.0
		mesh.surface_add_vertex(Vector3(cos(angle),0.0,sin(angle)))
	mesh.surface_end()
	ring = MeshInstance3D.new()
	ring.mesh = mesh
	ring.position.y = 0.065
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	storm_material = ShaderMaterial.new()
	storm_material.shader = StormShader
	storm_material.set_shader_parameter("cloud_tex",make_cloud_texture())
	wall = MeshInstance3D.new()
	wall.mesh = make_wall()
	wall.material_override = storm_material
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wall)
	set_profile(quality)
	reset_zone()

func make_cloud_texture() -> ImageTexture:
	var image := Image.create(128,128,false,Image.FORMAT_L8)
	# Periodic procedural cloud texture; the shader only samples two texels.
	for y in range(128):
		for x in range(128):
			var u := float(x)*TAU/128.0
			var v := float(y)*TAU/128.0
			var n := 0.5+0.18*sin(u*3.0+sin(v*2.0))*cos(v*2.0-u)+0.13*sin(u*5.0-v*3.0)+0.09*cos(u*9.0+v*7.0)+0.08*sin(v*11.0-u*4.0)
			var value := clampf(n,0.0,1.0)
			image.set_pixel(x,y,Color(value,value,value))
	return ImageTexture.create_from_image(image)

func make_wall() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(96):
		var a := float(i)/96.0
		var b := float(i+1)/96.0
		var p := Vector3(cos(a*TAU),0.0,sin(a*TAU))
		var q := Vector3(cos(b*TAU),0.0,sin(b*TAU))
		var positions := [p,q,p+Vector3.UP*STORM_HEIGHT,q,q+Vector3.UP*STORM_HEIGHT,p+Vector3.UP*STORM_HEIGHT]
		var uvs := [Vector2(a,0),Vector2(b,0),Vector2(a,1),Vector2(b,0),Vector2(b,1),Vector2(a,1)]
		for j in range(6):
			surface.set_uv(uvs[j])
			surface.add_vertex(positions[j])
	return surface.commit()

func set_profile(value: int) -> void:
	quality = clampi(value,0,2)
	if is_instance_valid(storm_material):
		storm_material.set_shader_parameter("density",[0.76,0.84,0.90][quality])

func _process(delta: float) -> void:
	wind_clock = fmod(wind_clock+delta,1000.0)
	if is_instance_valid(storm_material):
		storm_material.set_shader_parameter("wind_time",wind_clock)

func reset_zone() -> void:
	elapsed = 0.0
	radius = START_RADIUS
	phase = 0
	update_ring()

func advance(delta: float) -> void:
	elapsed += maxf(delta,0.0)
	var progress := clampf((elapsed-GRACE)/SHRINK_TIME,0.0,1.0)
	radius = lerpf(START_RADIUS,END_RADIUS,progress)
	phase = 0 if elapsed<GRACE else (2 if progress>=1.0 else 1)
	update_ring()

func update_ring() -> void:
	if is_instance_valid(ring):
		ring.scale = Vector3(radius,1.0,radius)
	if is_instance_valid(wall):
		wall.scale = Vector3(radius,1.0,radius)

func signed_distance(world_position: Vector3) -> float:
	var p := to_local(world_position)
	return Vector2(p.x,p.z).length()-radius

func outside(world_position: Vector3) -> bool:
	return signed_distance(world_position)>0.0

func exposure(world_position: Vector3) -> float:
	return smoothstep(-7.0,8.0,signed_distance(world_position))

func seconds_remaining() -> int:
	return ceili(maxf(0.0,(GRACE if phase==0 else GRACE+SHRINK_TIME)-elapsed))
