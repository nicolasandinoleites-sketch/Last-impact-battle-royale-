extends CharacterBody3D
signal destroyed
var game
var hp := 100
var active := true
var spawn_point := Vector3.ZERO
var body: Node3D
var spin := 0.0
var contact_left := 0.0
var detour_left := 0.0
var detour_side := 1.0
var path_left := 0.0
var route_points := PackedVector3Array()
var route_index := 0

func _ready() -> void:
	spawn_point = position
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.48
	collision.shape = shape
	collision.position.y = 0.75
	add_child(collision)
	body = Node3D.new()
	body.position.y = 0.75
	add_child(body)
	var core := SphereMesh.new()
	core.radius = 0.32
	core.height = 0.64
	core.radial_segments = 12
	core.rings = 6
	part(core,Vector3.ZERO,Color("344c62"))
	var shell := BoxMesh.new()
	shell.size = Vector3(0.95,0.14,0.38)
	part(shell,Vector3.ZERO,Color("8ba8b7"))
	var light_mesh := SphereMesh.new()
	light_mesh.radius = 0.11
	light_mesh.height = 0.22
	light_mesh.radial_segments = 8
	light_mesh.rings = 4
	part(light_mesh,Vector3(0,0,-0.31),Color("ff9b43"))

func part(mesh: Mesh, offset: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = offset
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	instance.material_override = mat
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(instance)

func _physics_process(delta: float) -> void:
	if not active or not is_instance_valid(game) or game.round_result!="" or not is_instance_valid(game.player):
		return
	contact_left = maxf(0.0,contact_left-delta)
	detour_left = maxf(0.0,detour_left-delta)
	var difference: Vector3 = game.player.global_position-global_position
	difference.y = 0.0
	var direction := difference.normalized()
	var destination: Vector3 = game.player.global_position
	if game.zone.outside(global_position):
		destination = game.zone.global_position
		direction = Vector3(-global_position.x,0,-global_position.z).normalized()
	elif difference.length()<1.35:
		direction = Vector3.ZERO
	if direction.length_squared()>0.01:
		direction = navigation_direction(destination,delta,direction)
	if detour_left>0.0 and direction.length_squared()>0.01:
		direction = direction.rotated(Vector3.UP,detour_side*PI*0.5)
	velocity = direction*2.2
	move_and_slide()
	if get_slide_collision_count()>0 and detour_left<=0.0:
		detour_side *= -1.0
		detour_left = 0.8
	if difference.length()>0.1:
		body.rotation.y = lerp_angle(body.rotation.y,atan2(-difference.x,-difference.z),minf(1.0,delta*8.0))
	spin += delta*2.7
	body.position.y = 0.75+sin(spin)*0.07
	# Arcade contact damage only; do not apply it through level geometry.
	if difference.length()<1.45 and absf(game.player.global_position.y-global_position.y)<1.1 and contact_left<=0.0:
		var ray := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*0.75,game.player.global_position+Vector3.UP*0.75,1)
		if get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			contact_left = 1.5
			game.damage_player(8)

func take_hit(damage: int) -> void:
	if not active:
		return
	hp = maxi(0,hp-maxi(0,damage))
	if hp==0:
		active = false
		visible = false
		collision_layer = 0
		velocity = Vector3.ZERO
		destroyed.emit()

func reset_target() -> void:
	position = spawn_point
	reset_physics_interpolation()
	hp = 100
	active = true
	visible = true
	collision_layer = 2
	velocity = Vector3.ZERO
	contact_left = 0.0
	detour_left = 0.0
	detour_side = 1.0
	path_left = 0.0
	route_points.clear()
	route_index = 0
	spin = 0.0

func navigation_direction(destination: Vector3, delta: float, direct: Vector3) -> Vector3:
	path_left -= delta
	if path_left<=0.0:
		route_points = game.frontier.route(global_position,destination)
		route_index = 1
		path_left = 0.8
	while route_index<route_points.size():
		var difference := route_points[route_index]-global_position
		difference.y = 0.0
		if difference.length()>0.65:
			return difference.normalized()
		route_index += 1
	return direct
