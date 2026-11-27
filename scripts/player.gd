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
var crouch_requested := false
var crouched := false
var slide_cooldown := 0.0
var jump_buffer := 0.0
var ground_grace := 0.0
var combat_facing := false
var combat_hold := 0.0
var local_motion := Vector2.ZERO
var animation_speed := 0.0
var animation_cost_us := 0.0
var weapon_cost_us := 0.0
const Raze = preload("res://scripts/raze.gd")
const LocomotionController = preload("res://scripts/locomotion_controller.gd")
var previous_horizontal := Vector2.ZERO
var body_acceleration := Vector2.ZERO
var locomotion_state := "IDLE"
var raze: Node3D
var model_loaded := false
const Ignis = preload("res://scripts/ignis.gd")
var weapon: Node3D
var weapon_loaded := false
var reload_visual := 0.0
var view_recoil := 0.0
var contact_shadow: MeshInstance3D
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
		raze.enable_locomotion_clips()
		for child in placeholder:
			if child is Node3D:
				child.hide()
	if model_loaded:
		weapon = Ignis.new()
		add_child(weapon)
		weapon_loaded = weapon.equip(raze.right_socket,visual)
		raze.armed = weapon_loaded
		weapon.actor = raze
	create_contact_shadow()
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
	view_recoil = move_toward(view_recoil,0.0,delta*0.45)
	pivot.rotation = Vector3(clampf(pitch+view_recoil,-0.85,0.48),yaw,0)
	pivot.position.y = lerpf(pivot.position.y, 0.98 if low_stance else (1.52 if aiming else 1.36), minf(1.0,delta*10.0))
	boom.position.x = lerpf(boom.position.x, shoulder * (0.78 if aiming else 0.64), minf(1.0, delta * 12.0))
	boom.spring_length = lerpf(boom.spring_length, 2.40 if aiming else 2.85, minf(1.0, delta * 12.0))
	camera.fov = lerpf(camera.fov, 52.0 if aiming else 60.0, minf(1.0, delta * 12.0))

func toggle_crouch() -> void:
	if slide_time>0.0 or not is_on_floor():
		return
	crouch_requested = not crouch_requested

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
	animation_speed = 0.0
	animation_cost_us = 0.0
	weapon_cost_us = 0.0
	previous_horizontal = Vector2.ZERO
	body_acceleration = Vector2.ZERO
	locomotion_state = "IDLE"
	sprint = false
	move_input = Vector2.ZERO
	slide_time = 0.0
	slide_cooldown = 0.0
	jump_requested = false
	jump_buffer = 0.0
	ground_grace = 0.0
	aiming = false
	combat_facing = false
	combat_hold = 0.0
	local_motion = Vector2.ZERO
	crouch_requested = false
	crouched = false
	set_stance(false)
	reload_visual = 0.0
	view_recoil = 0.0
	if model_loaded:
		raze.reset_locomotion()
	if weapon_loaded:
		weapon.clear_effects()
	if is_instance_valid(visual):
		visual.rotation.y = yaw
	if is_instance_valid(camera):
		update_camera(1.0)

func _physics_process(delta: float) -> void:
	slide_cooldown = maxf(0.0,slide_cooldown-delta)
	if jump_requested:
		jump_buffer = 0.13
	jump_requested = false
	jump_buffer = maxf(0.0,jump_buffer-delta)
	ground_grace = 0.10 if is_on_floor() else maxf(0.0,ground_grace-delta)
	var sliding := slide_time>0.0
	if sliding or crouch_requested:
		set_stance(true)
	elif low_stance and can_stand():
		set_stance(false)
	var previous_crouched := crouched
	crouched = low_stance and not sliding
	if crouched!=previous_crouched and get_parent().has_method("qa_control"):
		get_parent().qa_control("CROUCH_ON" if crouched else "CROUCH_OFF")
	combat_hold = 0.36 if aiming or combat_facing else maxf(0.0,combat_hold-delta)
	update_camera(delta)
	var direction := Basis(Vector3.UP,yaw) * Vector3(move_input.x,0,move_input.y)
	var sprint_forward := sprint and not low_stance and move_input.y< -0.45 and -move_input.y>absf(move_input.x)*0.75
	var speed := 6.2 if sprint_forward else 3.8
	if aiming or combat_facing:
		speed = 2.8 if aiming else 3.8
	if low_stance:
		speed = 2.0
	if slide_time > 0.0:
		slide_time = maxf(0.0,slide_time-delta)
		direction = slide_direction
		speed = lerpf(3.0,8.0,slide_time/0.65)
	var owner_game = get_parent()
	if owner_game.get("ability")!=null and not sliding:
		speed *= owner_game.ability.movement_factor()
	var desired := Vector2(direction.x,direction.z)*speed
	var horizontal_velocity := Vector2(velocity.x,velocity.z)
	var next_velocity := LocomotionController.step(horizontal_velocity,desired,is_on_floor(),sprint_forward and not aiming and not combat_facing,delta)
	velocity.x = next_velocity.x
	velocity.z = next_velocity.y
	if not is_on_floor():
		velocity.y -= 18.0*delta
	if jump_buffer > 0.0 and ground_grace > 0.0 and not low_stance:
		velocity.y = 6.0
		if get_parent().has_method("qa_control"):
			get_parent().qa_control("JUMP")
		jump_buffer = 0.0
		ground_grace = 0.0
	move_and_slide()
	contact_shadow.visible = is_on_floor()
	contact_shadow.position.y = 0.018
	# Animate actual horizontal displacement, not requested movement against a wall.
	var real_motion := get_real_velocity()
	var horizontal := Vector3(real_motion.x,0.0,real_motion.z)
	animation_speed = horizontal.length()
	update_facing(horizontal if animation_speed>0.18 else Vector3.ZERO,delta)
	var planar := Vector2(horizontal.x,horizontal.z)
	var world_accel := (planar-previous_horizontal)/maxf(delta,0.001)
	previous_horizontal = planar
	var body_basis := visual.global_transform.basis.orthonormalized().inverse()
	var local_accel := body_basis*Vector3(world_accel.x,0,world_accel.y)
	body_acceleration = body_acceleration.lerp(Vector2(local_accel.x,local_accel.z).limit_length(24.0),1.0-exp(-delta*9.0))
	locomotion_state = ("CROUCH_MOVE" if animation_speed>0.18 else "CROUCH") if crouched else ("SLIDE" if low_stance else ("JUMP" if velocity.y>0.0 and not is_on_floor() else ("FALL" if not is_on_floor() else ("SPRINT" if sprint_forward and combat_hold<=0.0 and animation_speed>4.2 else ("AIM_MOVE" if aiming and animation_speed>0.18 else ("AIM" if aiming else ("MOVE" if animation_speed>0.18 else "IDLE")))))))
	var local_velocity := visual.global_transform.basis.orthonormalized().inverse()*horizontal
	local_motion = Vector2(local_velocity.x,local_velocity.z)
	phase += delta * (12.0 if sprint else 9.0)
	var stride := sin(phase)*0.45 if animation_speed>0.18 and is_on_floor() else 0.0
	left_leg.rotation.x = stride
	right_leg.rotation.x = -stride
	if model_loaded:
		var anim_start_us := Time.get_ticks_usec()
		raze.locomotion(delta,animation_speed,is_on_floor(),low_stance,combat_hold>0.0,sprint_forward,velocity.y,local_motion,body_acceleration,crouched)
		animation_cost_us = lerpf(animation_cost_us,float(Time.get_ticks_usec()-anim_start_us),0.12)
		if raze.clip_motion.weight>0.5 and get_parent().has_method("qa_control"):
			get_parent().qa_control("CLIP_ACTIVE")
		if raze.crouch_motion.weight>0.5 and get_parent().has_method("qa_control"):
			get_parent().qa_control("CROUCH_CLIP_ACTIVE")
		if raze.air_motion.weight>0.3 and get_parent().has_method("qa_control"):
			get_parent().qa_control("AIR_CLIP_"+raze.air_motion.state)
	else:
		visual.scale.y = lerpf(visual.scale.y,0.55 if low_stance else 1.0,minf(1.0,delta*12.0))
	if weapon_loaded:
		var weapon_start_us := Time.get_ticks_usec()
		weapon.update_pose(delta,aiming or combat_facing,reload_visual,low_stance,pitch+view_recoil)
		weapon_cost_us = lerpf(weapon_cost_us,float(Time.get_ticks_usec()-weapon_start_us),0.12)
	if position.y < -8.0:
		position = Vector3(0,0.1,12)
		reset_movement()
		reset_physics_interpolation()

# Low-cost contact cue independent of dynamic shadow support.
func create_contact_shadow() -> void:
	var img := Image.create(64,64,false,Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			var d := Vector2((x-31.5)/31.5,(y-31.5)/31.5).length()
			var opacity := 0.35*pow(maxf(0.0,1.0-d*d),2.0)
			img.set_pixel(x,y,Color(0.05,0.06,0.07,opacity))
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = ImageTexture.create_from_image(img)
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.4,1.4)
	contact_shadow = MeshInstance3D.new()
	contact_shadow.mesh = plane
	contact_shadow.material_override = mat
	contact_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	contact_shadow.position.y = 0.018
	add_child(contact_shadow)

func update_facing(direction: Vector3,delta: float) -> void:
	var in_combat := aiming or combat_facing or combat_hold>0.0
	var goal := LocomotionController.facing_target(yaw,visual.rotation.y,slide_direction if slide_time>0.0 else direction,in_combat,slide_time>0.0)
	var rate := 22.0 if in_combat else 10.0
	visual.rotation.y = lerp_angle(visual.rotation.y,goal,1.0-exp(-delta*rate))
