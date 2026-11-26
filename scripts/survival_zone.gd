extends Node3D
const START_RADIUS := 54.0
const END_RADIUS := 6.0
const GRACE := 25.0
const SHRINK_TIME := 180.0
const STORM_HEIGHT := 38.0
const StormShader = preload("res://shaders/storm_wall.gdshader")
var radius := START_RADIUS
var elapsed := 0.0
var phase := 0
var ring: MeshInstance3D
var wall: MeshInstance3D
var outer_cloud: MeshInstance3D
var outer_material: ShaderMaterial
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
	# The safe boundary remains exact in gameplay and on the minimap, not a neon world ring.
	ring.hide()
	storm_material = ShaderMaterial.new()
	storm_material.shader = StormShader
	storm_material.set_shader_parameter("cloud_tex",make_cloud_texture())
	wall = MeshInstance3D.new()
	wall.mesh = make_wall()
	wall.material_override = storm_material
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wall)
	outer_material = storm_material.duplicate() as ShaderMaterial
	outer_material.set_shader_parameter("secondary_layer",1.0)
	outer_cloud = MeshInstance3D.new()
	outer_cloud.mesh = wall.mesh
	outer_cloud.material_override = outer_material
	outer_cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(outer_cloud)
	set_profile(quality)
	reset_zone()

func make_cloud_texture() -> ImageTexture:
	var image := Image.create(128,128,false,Image.FORMAT_L8)
	var noise := FastNoiseLite.new()
	noise.seed = 7531
	noise.frequency = 0.036
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.53
	# Blend periodic noise at opposite edges, not trigonometric repeating waves.
	for y in range(128):
		for x in range(128):
			var u := smoothstep(0.0,1.0,float(x)/128.0)
			var v := smoothstep(0.0,1.0,float(y)/128.0)
			var a := lerpf(noise.get_noise_2d(x,y),noise.get_noise_2d(x-128,y),u)
			var b := lerpf(noise.get_noise_2d(x,y-128),noise.get_noise_2d(x-128,y-128),u)
			var value := clampf(0.5+lerpf(a,b,v)*1.05,0.0,1.0)
			image.set_pixel(x,y,Color(value,value,value))
	return ImageTexture.create_from_image(image)

# A billowing profile with an anchored ground edge, rounded leading nose and irregular crown.
# Geometry is purely visual: damage, loot and navigation continue to use the exact radius.
func wall_vertex(angle: float, row: int) -> Vector3:
	var levels := [0.0,0.10,0.29,0.57,0.82,1.0]
	var radial := [1.0,0.983,0.952,0.975,1.055,1.10]
	var h: float = levels[row]
	var a := angle*TAU
	var lobes := 0.58*sin(a*7.0+0.4)+0.27*sin(a*13.0-1.4)+0.15*cos(a*23.0)
	var crown := 1.0+lobes*0.24
	var r: float = radial[row]+lobes*0.043*sin(h*PI)
	return Vector3(cos(a)*r,STORM_HEIGHT*h*lerpf(1.0,crown,h),sin(a)*r)

func make_wall() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(112):
		var a := float(i)/112.0
		var b := float(i+1)/112.0
		for row in range(5):
			var p := wall_vertex(a,row)
			var q := wall_vertex(b,row)
			var p_top := wall_vertex(a,row+1)
			var q_top := wall_vertex(b,row+1)
			var v := float(row)/5.0
			var v_top := float(row+1)/5.0
			var positions := [p,q,p_top,q,q_top,p_top]
			var uvs := [Vector2(a,v),Vector2(b,v),Vector2(a,v_top),Vector2(b,v),Vector2(b,v_top),Vector2(a,v_top)]
			for j in range(6):
				surface.set_uv(uvs[j])
				surface.add_vertex(positions[j])
	return surface.commit()

func set_profile(value: int) -> void:
	quality = clampi(value,0,2)
	if is_instance_valid(storm_material):
		storm_material.set_shader_parameter("density",[0.89,0.94,0.97][quality])
	if is_instance_valid(outer_cloud):
		outer_cloud.visible = quality>0
		outer_material.set_shader_parameter("density",[0.0,0.31,0.42][quality])

func _process(delta: float) -> void:
	wind_clock = fmod(wind_clock+delta,1000.0)
	if is_instance_valid(storm_material):
		storm_material.set_shader_parameter("wind_time",wind_clock)
	if is_instance_valid(outer_material):
		outer_material.set_shader_parameter("wind_time",wind_clock*0.68+37.0)

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
	if is_instance_valid(outer_cloud):
		outer_cloud.scale = Vector3(radius+5.0,1.12,radius+5.0)

func signed_distance(world_position: Vector3) -> float:
	var p := to_local(world_position)
	return Vector2(p.x,p.z).length()-radius

func outside(world_position: Vector3) -> bool:
	return signed_distance(world_position)>0.0

func exposure(world_position: Vector3) -> float:
	return smoothstep(-7.0,8.0,signed_distance(world_position))

func seconds_remaining() -> int:
	return ceili(maxf(0.0,(GRACE if phase==0 else GRACE+SHRINK_TIME)-elapsed))
