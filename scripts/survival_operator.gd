extends CharacterBody3D
signal destroyed
const Raze = preload("res://scripts/raze.gd")
const Ignis = preload("res://scripts/ignis.gd")
var rival_weapon: Node3D
var weapon_loaded := false
var opponent: Node3D
var rounds := 6
var reload_left := 0.0
var shot_left := 0.0
var shots := 0
var reloads := 0
var tracer: MeshInstance3D
var tracer_left := 0.0
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
# Tactical behavior is enabled only in the aircraft Battle Royale mode.
var armor := 0
var tactical_goal := Vector3.ZERO
var tactical_pickup: Node3D
var decision_left := 0.0
var patrol_index := 0
var last_seen := Vector3.ZERO
var memory_left := 0.0
var loot_count := 0
var tactical_ready := false

func tactical_enabled() -> bool:
	return is_instance_valid(game) and game.experimental_deployment

func opponent_position() -> Vector3:
	return opponent.global_position if is_instance_valid(opponent) else game.player.global_position

func target_available(candidate) -> bool:
	if not is_instance_valid(candidate) or candidate==self: return false
	if candidate==game.player: return game.health>0
	if candidate.get_script()!=get_script() or not candidate.active: return false
	return not is_instance_valid(game.rival_deployment) or not game.rival_deployment.airborne(candidate)

func select_opponent() -> Node3D:
	var best: Node3D = null
	var best_distance := 18.0
	var candidates: Array = [game.player]
	candidates.append_array(game.targets)
	for candidate in candidates:
		if not target_available(candidate): continue
		var d: float = global_position.distance_to(candidate.global_position)
		if d<=best_distance and absf(candidate.global_position.y-global_position.y)<3.0 and clear_path(candidate.global_position):
			best = candidate
			best_distance = d
	return best

func visible_player() -> bool:
	var difference: Vector3 = game.player.global_position-global_position
	if difference.length()>18.0 or absf(difference.y)>3.0:
		return false
	return clear_path(game.player.global_position)

func clear_path(destination: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*0.8,destination+Vector3.UP*0.8,1)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func set_tactical_goal(state: String, destination: Vector3) -> void:
	if state!=ai_state or tactical_goal.distance_to(destination)>2.0:
		path_left = 0.0
	ai_state = state
	tactical_goal = destination

func select_supply():
	var best: Node3D = null
	var score := INF
	for pickup in game.pickups:
		if not pickup.active or game.zone.outside(pickup.global_position): continue
		if pickup.kind=="MED" and hp>70: continue
		if pickup.kind=="SHIELD" and armor>=35: continue
		if pickup.kind not in ["MED","SHIELD"]: continue
		var distance: float = global_position.distance_to(pickup.global_position)
		if distance>32.0: continue
		var claimed := false
		for other in game.targets:
			if other!=self and other.get_script()==get_script() and other.active and other.tactical_pickup==pickup:
				claimed = true
		if claimed: continue
		var route: PackedVector3Array = game.frontier.route(global_position,pickup.global_position)
		if route.is_empty() and distance>2.0: continue
		var cost := distance+float(route.size())*0.35
		if pickup.kind=="MED" and hp<45: cost -= 15.0
		if cost<score:
			best = pickup
			score = cost
	return best

func collect_supply() -> bool:
	if not is_instance_valid(tactical_pickup) or not tactical_pickup.active: return false
	if global_position.distance_to(tactical_pickup.global_position)>1.4 or not clear_path(tactical_pickup.global_position): return false
	var used := 0
	if tactical_pickup.kind=="MED" and hp<100:
		hp = mini(100,hp+35)
		used = 1
	elif tactical_pickup.kind=="SHIELD" and armor<50:
		armor = mini(50,armor+25)
		used = 1
	if used==0: return false
	tactical_pickup.collect(used)
	loot_count += 1
	tactical_pickup = null
	decision_left = 0.0
	return true

func open_goal(candidate: Vector3) -> Vector3:
	var cell: Vector2i = game.frontier.nearest_open(game.frontier.cell_at(candidate))
	return game.frontier.cell_center(cell)

# Virtual arena cover nodes: use the existing navigation grid and level occlusion.
func select_reload_cover() -> Vector3:
	if not target_available(opponent): return global_position
	var origin: Vector2i = game.frontier.cell_at(global_position)
	var best: Vector3 = global_position
	var best_cost := INF
	for x in range(-3,4):
		for z in range(-3,4):
			var cell := origin+Vector2i(x,z)
			if not game.frontier.grid.is_in_boundsv(cell) or game.frontier.grid.is_point_solid(cell): continue
			var point: Vector3 = game.frontier.cell_center(cell)
			if game.zone.outside(point): continue
			var ray := PhysicsRayQueryParameters3D.create(point+Vector3.UP*0.9,opponent_position()+Vector3.UP*0.9,1)
			if get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
			var route: PackedVector3Array = game.frontier.route(global_position,point)
			if route.is_empty(): continue
			var cost: float = float(route.size())+global_position.distance_to(point)*0.25
			if cost<best_cost:
				best_cost = cost
				best = point
	return best

func decide_tactical(delta: float) -> Vector3:
	memory_left = maxf(0.0,memory_left-delta)
	decision_left -= delta
	if not tactical_ready:
		tactical_ready = true
		tactical_goal = global_position
		patrol_index = game.targets.find(self)
		decision_left = 0.0
	if decision_left>0.0:
		return tactical_goal
	decision_left = 0.30
	if not (ai_state=="COVER" and reload_left>0.0 and target_available(opponent)):
		opponent = select_opponent()
	var seen := is_instance_valid(opponent)
	if seen:
		last_seen = opponent_position()
		memory_left = 2.4
	var center: Vector3 = game.zone.global_position
	if game.zone.outside(global_position) or global_position.distance_to(center)>maxf(3.0,game.zone.radius-3.0):
		tactical_pickup = null
		set_tactical_goal("ZONE",open_goal(center))
		return tactical_goal
	var supply = select_supply()
	if is_instance_valid(supply) and (not seen or hp<45):
		tactical_pickup = supply
		set_tactical_goal("LOOT",supply.global_position)
		return tactical_goal
	tactical_pickup = null
	if seen and hp<35:
		var away: Vector3 = global_position-opponent_position()
		away.y = 0.0
		if away.length_squared()<0.01: away = Vector3.RIGHT
		var retreat: Vector3 = global_position+away.normalized()*8.0
		if game.zone.outside(retreat): retreat = center.lerp(global_position,0.6)
		set_tactical_goal("RETREAT",open_goal(retreat))
	elif seen:
		if reload_left>0.0 and global_position.distance_to(opponent_position())>2.0:
			var cover := select_reload_cover()
			if cover.distance_to(global_position)>0.5:
				set_tactical_goal("COVER",cover)
			else: set_tactical_goal("ENGAGE",opponent_position())
		else: set_tactical_goal("ENGAGE",opponent_position())
	elif memory_left>0.0 and global_position.distance_to(last_seen)>2.0:
		set_tactical_goal("SEARCH",open_goal(last_seen))
	elif ai_state!="PATROL" or global_position.distance_to(tactical_goal)<1.5:
		var angle := float(patrol_index)*2.399963
		patrol_index += 1
		var candidate := Vector3(cos(angle),0,sin(angle))*minf(32.0,maxf(2.0,game.zone.radius-5.0)) + center
		set_tactical_goal("PATROL",open_goal(candidate))
	return tactical_goal


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
	if model_loaded and tactical_enabled():
		rival_weapon = Ignis.new()
		visual.add_child(rival_weapon)
		weapon_loaded = rival_weapon.equip(actor.right_socket,visual)
		rival_weapon.actor = actor
		actor.armed = weapon_loaded
		if weapon_loaded:
			tracer = MeshInstance3D.new()
			var beam := BoxMesh.new()
			beam.size = Vector3(0.018,0.018,1.0)
			tracer.mesh = beam
			tracer.material_override = flat_material(Color("79e4ff"))
			tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(tracer)
			tracer.top_level = true
			tracer.hide()
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
	if not tactical_enabled():
		ai_state = "FOLLOW"
		if game.zone.outside(global_position):
			ai_state = "ZONE"
			destination = game.zone.global_position
			direction = Vector3(-global_position.x,0,-global_position.z).normalized()
		elif distance<1.3:
			ai_state = "IDLE"
			direction = Vector3.ZERO
	if tactical_enabled():
		# Preserve tactical state across physics frames; decision rate is bounded.
		destination = decide_tactical(delta)
		var offset := destination-global_position
		offset.y = 0.0
		direction = offset.normalized() if offset.length()>1.0 else Vector3.ZERO
		if ai_state=="ENGAGE" and is_instance_valid(opponent) and global_position.distance_to(opponent_position())<9.0: direction = Vector3.ZERO
		if ai_state=="LOOT": collect_supply()
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
	var combat: bool = tactical_enabled() and ai_state=="ENGAGE" and target_available(opponent)
	if combat:
		var aim: Vector3 = opponent_position()-global_position
		visual.rotation.y = lerp_angle(visual.rotation.y,atan2(-aim.x,-aim.z),1.0-exp(-delta*12.0))
	# Render-only guard. Keep active state, hitbox, navigation and contact damage.
	var camera: Camera3D = game.player.camera
	update_lens_guard(camera.global_position)
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
		actor.locomotion(minf(anim_elapsed,0.20),horizontal.length(),is_on_floor(),false,combat,false,velocity.y,Vector2(local.x,local.z) if distance<full_animation_distance else Vector2.ZERO)
		if weapon_loaded:
			rival_weapon.update_pose(minf(anim_elapsed,0.20),combat,clampf(reload_left/1.4,0.0,1.0))
		animation_cost_us = lerpf(animation_cost_us,float(Time.get_ticks_usec()-start_us),0.12)
		anim_elapsed = 0.0
		anim_updates += 1
	if weapon_loaded and tactical_enabled():
		step_rival_combat(delta,combat)
	# Preserve legacy contact behavior in the old survival mode.
	if distance<1.4 and height_gap<1.1 and contact_left<=0.0 and not tactical_enabled():
		var ray := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*0.75,game.player.global_position+Vector3.UP*0.75,1)
		if get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			contact_left = 1.5
			game.damage_player(8)

func step_rival_combat(delta: float, combat: bool) -> void:
	shot_left = maxf(0.0,shot_left-delta)
	tracer_left = maxf(0.0,tracer_left-delta)
	if is_instance_valid(tracer): tracer.visible = tracer_left>0.0
	if reload_left>0.0:
		reload_left = maxf(0.0,reload_left-delta)
		if reload_left<=0.0:
			rounds = 6
			reloads += 1
		return
	if not combat or not target_available(opponent) or shot_left>0.0: return
	if game.deployment_active() or game.round_result!="": return
	if rounds<=0:
		reload_left = 1.4
		return
	if global_position.distance_to(opponent_position())>18.0 or not clear_path(opponent_position()): return
	var from: Vector3 = rival_weapon.flash.global_position
	var to: Vector3 = opponent_position()+Vector3.UP*0.9
	var query := PhysicsRayQueryParameters3D.create(from,to,1)
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty(): return
	rounds -= 1
	shots += 1
	shot_left = 0.65
	rival_weapon.pulse()
	if is_instance_valid(tracer) and global_position.distance_to(game.player.global_position)<24.0:
		tracer.global_position = (from+to)*0.5
		if from.distance_to(to)>0.01:
			tracer.look_at(to)
			tracer.scale = Vector3(1,1,from.distance_to(to))
		tracer_left = 0.08
		tracer.show()
	if opponent==game.player: game.damage_player(6)
	else: opponent.take_hit(9)

func update_lens_guard(camera_position: Vector3) -> void:
	lens_hidden = CameraGuard.overlaps_lens(camera_position,global_position,lens_hidden)
	visual.visible = not lens_hidden

func take_hit(damage: int) -> void:
	if not active:
		return
	var incoming := maxi(0,damage)
	if tactical_enabled():
		var absorbed := mini(armor,incoming)
		armor -= absorbed
		incoming -= absorbed
		decision_left = 0.0
	hp = maxi(0,hp-incoming)
	if hp==0:
		active = false
		if is_instance_valid(tracer): tracer.hide()
		visible = false
		collision_layer = 0
		velocity = Vector3.ZERO
		tactical_pickup = null
		ai_state = "INACTIVE"
		destroyed.emit()

func reset_target() -> void:
	position = spawn_point
	reset_physics_interpolation()
	hp = 100
	armor = 0
	opponent = null
	rounds = 6
	reload_left = 0.0
	shot_left = 0.0
	shots = 0
	reloads = 0
	tracer_left = 0.0
	if is_instance_valid(tracer): tracer.hide()
	if weapon_loaded:
		rival_weapon.clear_effects()
		rival_weapon.show()
	tactical_ready = false
	tactical_pickup = null
	decision_left = 0.0
	memory_left = 0.0
	loot_count = 0
	patrol_index = 0
	last_seen = Vector3.ZERO
	tactical_goal = Vector3.ZERO
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
