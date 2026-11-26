extends CharacterBody3D

var move_input := Vector2.ZERO
var sprint := false
var yaw := 0.0
var pitch := -0.13
var jump_requested := false
var slide_time := 0.0
var slide_direction := Vector3.ZERO
var camera: Camera3D
var pivot: Node3D
var boom: SpringArm3D
var visual: Node3D
var phase := 0.0
var left_leg: Node3D
var right_leg: Node3D
var shoulder := 1.0
var aiming := false
var capsule: CapsuleShape3D
var col: CollisionShape3D
var low_stance := false
var slide_cooldown := 0.0
var jump_buffer := 0.0
var ground_grace := 0.0
var combat_facing := false
const Raze = preload("res://scripts/raze.gd")
var raze: Node3D
var model_loaded := false
const Ignis = preload("res://scripts/ignis.gd")
var weapon: Node3D
var weapon_loaded := false
var reload_visual := 0.0
const STANDING_HEIGHT := 1.8
const LOW_HEIGHT := 1.0

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	capsule = CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.8
	col = CollisionShape3D.new()
	col.shape = capsule
	col.position.y = 0.9
	add_child(col)
	visual = Node3D.new()
	add_child(visual)
	var suit := material(Color("4b626a"))
	var armor := material(Color("243439"))
	var accent := material(Color("e99342"))
	part(visual, Vector3(0,1.2,0), Vector3(0.64,0.65,0.35), suit)
	part(visual, Vector3(0,1.74,0), Vector3(0.40,0.36,0.39), armor)
	part(visual, Vector3(0,1.19,0.23), Vector3(0.49,0.46,0.21), armor)
	part(visual, Vector3(0,1.40,0.35), Vector3(0.42,0.06,0.03), accent)
	part(visual, Vector3(-0.40,1.17,-0.10), Vector3(0.20,0.49,0.22), suit)
	part(visual, Vector3(0.39,1.23,-0.15), Vector3(0.20,0.42,0.25), suit)
	part(visual, Vector3(0.36,1.32,-0.49), Vector3(0.17,0.19,0.66), armor)
	left_leg = Node3D.new()
	right_leg = Node3D.new()
	for i in range(2):
		var leg: Node3D = left_leg if i == 0 else right_leg
		leg.position = Vector3(-0.18 if i == 0 else 0.18, 0.89, 0)
		visual.add_child(leg)
		part(leg, Vector3(0,-0.34,0), Vector3(0.25,0.68,0.27), suit)
		part(leg, Vector3(0,-0.72,-0.06), Vector3(0.27,0.18,0.39), armor)
	raze = Raze.new()
	var placeholder := visual.get_children()
	visual.add_child(raze)
	model_loaded = raze.load_model()
	if model_loaded:
		for child in placeholder:
			if child is Node3D:
				child.hide()
	if model_loaded:
		weapon = Ignis.new()
		add_child(weapon)
		weapon_loaded = weapon.equip(raze.right_socket,visual)
		raze.armed = weapon_loaded
		weapon.actor = raze
	pivot = Node3D.new()
	pivot.position = Vector3(0,1.52,0)
	add_child(pivot)
	boom = SpringArm3D.new()
	boom.spring_length = 3.5
	boom.collision_mask = 1
	boom.margin = 0.12
	var sphere := SphereShape3D.new()
	sphere.radius = 0.18
	boom.shape = sphere
	pivot.add_child(boom)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 70
	camera.near = 0.08
	camera.far = 110
	boom.add_child(camera)
	update_camera(1.0)

func material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	return m

func part(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> void:
	var n := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.material_override = mat
	n.position = pos
	parent.add_child(n)

func look_delta(relative: Vector2) -> void:
	var sensitivity := 0.0025 if aiming else 0.004
	yaw = wrapf(yaw - relative.x * sensitivity, -PI, PI)
	pitch = clampf(pitch - relative.y * sensitivity, -0.85, 0.48)

func update_camera(delta: float) -> void:
	pivot.rotation = Vector3(pitch,yaw,0)
	pivot.position.y = lerpf(pivot.position.y, 0.95 if low_stance else 1.52, minf(1.0,delta*10.0))
	boom.position.x = lerpf(boom.position.x, shoulder * (0.58 if aiming else 0.48), minf(1.0, delta * 12.0))
	boom.spring_length = lerpf(boom.spring_length, 1.95 if aiming else 2.75, minf(1.0, delta * 12.0))
	camera.fov = lerpf(camera.fov, 48.0 if aiming else 65.0, minf(1.0, delta * 12.0))

func request_slide() -> void:
	if is_on_floor() and slide_time <= 0.0 and slide_cooldown <= 0.0 and not low_stance and move_input.length() > 0.4:
		slide_direction = Basis(Vector3.UP,yaw) * Vector3(move_input.x,0,move_input.y).normalized()
		slide_time = 0.65
		slide_cooldown = 1.15

func can_stand() -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = capsule.radius
	shape.height = STANDING_HEIGHT - 0.04
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY,global_position+Vector3.UP*(STANDING_HEIGHT*0.5+0.03))
	query.collision_mask = 1
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func set_stance(low: bool) -> void:
	if low_stance == low:
		return
	low_stance = low
	capsule.height = LOW_HEIGHT if low else STANDING_HEIGHT
	col.position.y = capsule.height*0.5

func reset_movement() -> void:
	velocity = Vector3.ZERO
	move_input = Vector2.ZERO
	slide_time = 0.0
	slide_cooldown = 0.0
	jump_requested = false
	jump_buffer = 0.0
	ground_grace = 0.0
	aiming = false
	combat_facing = false
	set_stance(false)
	reload_visual = 0.0
	if weapon_loaded:
		weapon.clear_effects()

func _physics_process(delta: float) -> void:
	slide_cooldown = maxf(0.0,slide_cooldown-delta)
	if jump_requested:
		jump_buffer = 0.13
	jump_requested = false
	jump_buffer = maxf(0.0,jump_buffer-delta)
	ground_grace = 0.10 if is_on_floor() else maxf(0.0,ground_grace-delta)
	if slide_time > 0.0:
		set_stance(true)
	elif low_stance and can_stand():
		set_stance(false)
	update_camera(delta)
	var direction := Basis(Vector3.UP,yaw) * Vector3(move_input.x,0,move_input.y)
	var speed := 6.2 if sprint else 3.8
	if aiming or combat_facing:
		speed = 2.8 if aiming else 3.8
	if low_stance:
		speed = 2.0
	if slide_time > 0.0:
		slide_time = maxf(0.0,slide_time-delta)
		direction = slide_direction
		speed = lerpf(3.0,8.0,slide_time/0.65)
	velocity.x = move_toward(velocity.x,direction.x*speed,delta*24.0)
	velocity.z = move_toward(velocity.z,direction.z*speed,delta*24.0)
	if not is_on_floor():
		velocity.y -= 18.0*delta
	if jump_buffer > 0.0 and ground_grace > 0.0 and not low_stance:
		velocity.y = 6.0
		jump_buffer = 0.0
		ground_grace = 0.0
	move_and_slide()
	if direction.length() > 0.12:
		var angle := atan2(-direction.x,-direction.z)
		visual.rotation.y = lerp_angle(visual.rotation.y,yaw if aiming or combat_facing else angle,minf(1.0,delta*14.0))
	elif aiming or combat_facing:
		visual.rotation.y = lerp_angle(visual.rotation.y,yaw,minf(1.0,delta*14.0))
	phase += delta * (12.0 if sprint else 9.0)
	var stride := sin(phase)*0.45 if direction.length()>0.12 and is_on_floor() else 0.0
	left_leg.rotation.x = stride
	right_leg.rotation.x = -stride
	if model_loaded:
		raze.locomotion(delta,Vector2(velocity.x,velocity.z).length(),is_on_floor(),low_stance,aiming or combat_facing,sprint,velocity.y)
	else:
		visual.scale.y = lerpf(visual.scale.y,0.55 if low_stance else 1.0,minf(1.0,delta*12.0))
	if weapon_loaded:
		weapon.update_pose(delta,aiming or combat_facing,reload_visual,low_stance,pitch)
	if position.y < -8.0:
		position = Vector3(0,0.1,12)
		reset_movement()
