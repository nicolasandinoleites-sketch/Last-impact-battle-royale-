extends CharacterBody3D
signal destroyed
const Raze = preload("res://scripts/raze.gd")
const CameraGuard = preload("res://scripts/camera_guard.gd")
var lens_hidden := false
var animation_cost_us := 0.0
var offscreen_anim_skips := 0
var animation_lod_enabled := true
var game
var hp := 100
var active := true
var spawn_point := Vector3.ZERO
var actor
var visual: Node3D
var model_loaded := false
var fallback: MeshInstance3D
var badge_mesh: MeshInstance3D
var anim_elapsed := 0.0
var anim_updates := 0
var contact_left := 0.0
var detour_left := 0.0
var detour_sign := 1.0
var ai_state := "IDLE"
var path_left := 0.0
var route_points := PackedVector3Array()
var route_index := 0
var animation_interval := 1.0/20.0
var full_animation_distance := 14.0

func _ready() -> void:
	spawn_point = position
	collision_layer = 2
	collision_mask = 1
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.height = 1.8
	shape.radius = 0.36
	col.shape = shape
	col.position.y = 0.9
	add_child(col)
	visual = Node3D.new()
	add_child(visual)
	actor = Raze.new()
	visual.add_child(actor)
	model_loaded = actor.load_model()
	if model_loaded:
		for child in actor.model.find_children("*","MeshInstance3D",true,false):
			var mesh_node := child as MeshInstance3D
			if mesh_node.mesh==null:
				continue
			for i in range(mesh_node.mesh.get_surface_count()):
				var material := mesh_node.get_active_material(i) as StandardMaterial3D
				if material!=null:
					var tinted := material.duplicate() as StandardMaterial3D
					tinted.albedo_color *= Color(1.0,0.68,0.60,1.0)
					mesh_node.set_surface_override_material(i,tinted)
	else:
		actor.hide()
		fallback = MeshInstance3D.new()
		fallback.mesh = shape_mesh()
		fallback.position.y = 0.9
		fallback.material_override = flat_material(Color("a96050"))
		visual.add_child(fallback)
	badge_mesh = MeshInstance3D.new()
	var badge := BoxMesh.new()
	badge.size = Vector3(0.26,0.07,0.12)
	badge_mesh.mesh = badge
	badge_mesh.position.y = 2.0
	badge_mesh.material_override = flat_material(Color("ff805b"))
	badge_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(badge_mesh)

func shape_mesh() -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.36
	mesh.height = 1.8
	mesh.radial_segments = 10
	mesh.rings = 5
	return mesh

func flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat

func _physics_process(delta: float) -> void:
	if not active or not is_instance_valid(game) or game.round_result!="" or not is_instance_valid(game.player):
		return
	contact_left = maxf(0.0,contact_left-delta)
	detour_left = maxf(0.0,detour_left-delta)
	var difference: Vector3 = game.player.global_position-global_position
	var height_gap := absf(difference.y)
	difference.y = 0.0
	var distance := difference.length()
	var direction := difference.normalized()
	var destination: Vector3 = game.player.global_position
	ai_state = "FOLLOW"
	if game.zone.outside(global_position):
		ai_state = "ZONE"
		destination = game.zone.global_position
		direction = Vector3(-global_position.x,0,-global_position.z).normalized()
	elif distance<1.3:
		ai_state = "IDLE"
		direction = Vector3.ZERO
	if direction.length_squared()>0.01:
		direction = navigation_direction(destination,delta,direction)
	if detour_left>0.0 and direction.length_squared()>0.01:
		direction = direction.rotated(Vector3.UP,detour_sign*PI*0.5)
	velocity.x = move_toward(velocity.x,direction.x*2.35,delta*10.0)
	velocity.z = move_toward(velocity.z,direction.z*2.35,delta*10.0)
	if not is_on_floor():
		velocity.y -= delta*18.0
	else:
		velocity.y = minf(velocity.y,0.0)
	move_and_slide()
	for i in range(get_slide_collision_count()):
		var hit := get_slide_collision(i)
		if absf(hit.get_normal().y)<0.5 and detour_left<=0.0:
			detour_left = 0.8
			detour_sign *= -1.0
			break
	var horizontal := get_real_velocity()
	horizontal.y = 0.0
	if horizontal.length()>0.18:
		visual.rotation.y = lerp_angle(visual.rotation.y,atan2(-horizontal.x,-horizontal.z),1.0-exp(-delta*10.0))
	elif distance>0.1:
		visual.rotation.y = lerp_angle(visual.rotation.y,atan2(-difference.x,-difference.z),1.0-exp(-delta*7.0))
	# Render-only guard. Keep active state, hitbox, navigation and contact damage.
	var camera: Camera3D = game.player.camera
	lens_hidden = CameraGuard.overlaps_lens(camera.global_position,global_position,lens_hidden)
	visual.visible = not lens_hidden
	# Use several conservative samples so a tall actor at the frustum edge is not
	# treated as fully offscreen. Near actors retain the normal update rate.
	var on_screen := camera.is_position_in_frustum(global_position+Vector3.UP*0.25) or camera.is_position_in_frustum(global_position+Vector3.UP*0.9) or camera.is_position_in_frustum(global_position+Vector3.UP*1.75)
	var reduced := animation_lod_enabled and (lens_hidden or (distance>8.0 and not on_screen))
	animation_interval = 1.0/5.0 if reduced else (1.0/20.0 if distance<full_animation_distance else 1.0/10.0)
	if reduced:
		offscreen_anim_skips += 1
	anim_elapsed += delta
	if model_loaded and anim_elapsed>=animation_interval:
		var local := visual.global_transform.basis.orthonormalized().inverse()*horizontal
		var start_us := Time.get_ticks_usec()
		actor.locomotion(minf(anim_elapsed,0.20),horizontal.length(),is_on_floor(),false,false,false,velocity.y,Vector2(local.x,local.z) if distance<full_animation_distance else Vector2.ZERO)
		animation_cost_us = lerpf(animation_cost_us,float(Time.get_ticks_usec()-start_us),0.12)
		anim_elapsed = 0.0
		anim_updates += 1
	# Arcade contact-only opponent, same damage rule as the prototype drone.
	if distance<1.4 and height_gap<1.1 and contact_left<=0.0:
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
		ai_state = "INACTIVE"
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
	detour_sign = 1.0
	path_left = 0.0
	route_points.clear()
	route_index = 0
	anim_elapsed = 0.0
	anim_updates = 0
	lens_hidden = false
	visual.show()
	animation_cost_us = 0.0
	offscreen_anim_skips = 0
	ai_state = "IDLE"
	visual.rotation.y = 0.0
	if model_loaded:
		actor.reset_locomotion()

func navigation_direction(destination: Vector3, delta: float, direct: Vector3) -> Vector3:
	path_left -= delta
	if path_left<=0.0:
		route_points = game.frontier.route(global_position,destination)
		route_index = 1
		path_left = 0.65
	while route_index<route_points.size():
		var difference := route_points[route_index]-global_position
		difference.y = 0.0
		if difference.length()>0.65:
			return difference.normalized()
		route_index += 1
	return direct
