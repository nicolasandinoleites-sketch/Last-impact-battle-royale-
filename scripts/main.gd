extends Node3D
const PlayerScript = preload("res://scripts/player.gd")
const TargetScript = preload("res://scripts/target.gd")
const HudScript = preload("res://scripts/hud.gd")
var player
@export var survival_mode := false
@export var experimental_deployment := false
const Deployment = preload("res://scripts/frontier_deployment.gd")
var deployment: Node3D
const RivalDeployment = preload("res://scripts/rival_deployment.gd")
var rival_deployment: Node3D
const ZoneScript = preload("res://scripts/survival_zone.gd")
const DroneScript = preload("res://scripts/survival_drone.gd")
const OperatorScript = preload("res://scripts/survival_operator.gd")
var zone
const Frontier = preload("res://scripts/frontier_map.gd")
var frontier
var round_seed := 7300
var android_qa_ticks := 0
const MobileProfile = preload("res://scripts/mobile_profile.gd")
var qa_sample_start := 0
var qa_sample_frames := 0
var qa_sample_done := false
const FrameTelemetry = preload("res://scripts/frame_telemetry.gd")
var telemetry := FrameTelemetry.new()
const AdaptiveResolution = preload("res://scripts/adaptive_resolution.gd")
var adaptive_resolution := AdaptiveResolution.new()
var telemetry_paused := false
var qa_control_seen: Dictionary = {}
var round_result := ""
var zone_tick := 0.0
const InventoryScript = preload("res://scripts/survival_inventory.gd")
const PickupScript = preload("res://scripts/survival_pickup.gd")
var inventory = InventoryScript.new()
var pickups: Array = []
var corpse_pickups: Array = []
const CombatFX = preload("res://scripts/combat_impact_fx.gd")
const DropTable = preload("res://scripts/operator_drop_table.gd")
var combat_fx: Node3D
const PICKUP_RANGE := 1.8

const GameAudio = preload("res://scripts/game_audio.gd")
var game_audio: Node
var health := 100
var armor := 0
var hud
var targets: Array = []
const Arsenal = preload("res://scripts/weapon_catalog.gd")
var weapon_id := "IGNIS"
var owned_weapons: Array[String] = ["IGNIS"]
const Supplies = preload("res://scripts/battle_supplies.gd")
var supplies: Node3D
const Ability = preload("res://scripts/class_ability.gd")
var ability: Node
var magazine_bank: Dictionary = {}
var reserve_bank: Dictionary = {}
var ammo := 30
var reserve := 120
var eliminated := 0
var cooldown := 0.0
var reload_left := 0.0
var hit_left := 0.0
var fire := false
var keys := {}
var mobile_move := Vector2.ZERO
var mobile_sprint := false
var profile := 0
var sun: DirectionalLight3D
var world_environment: Environment
var storm_exposure := 0.0
var message_left := 0.0
var message := "Campo de entrenamiento":
	set(value):
		message = value
		message_left = 2.4 if not value.is_empty() else 0.0
const ArenaArt = preload("res://scripts/arena_art.gd")
var arena_art: Node3D

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load("user://lastimpact.cfg") == OK:
		profile = clampi(int(config.get_value("graphics","profile",0)),0,2)
	game_audio = GameAudio.new()
	add_child(game_audio)
	build_arena()
	if not survival_mode:
		arena_art = ArenaArt.new()
		add_child(arena_art)
		arena_art.decorate(self)
	apply_profile()
	if experimental_deployment:
		combat_fx = CombatFX.new()
		add_child(combat_fx)
		combat_fx.configure(profile)
	player = PlayerScript.new()
	player.position = Vector3(0,0.1,12)
	add_child(player)
	if survival_mode:
		zone = ZoneScript.new()
		add_child(zone)
		zone.set_profile(profile)
		game_audio.prepare_storm()
		message = "Supervivencia: permanece en la zona"
		spawn_pickups()
		if experimental_deployment:
			supplies = Supplies.new()
			add_child(supplies)
			supplies.configure(self)
			ability = Ability.new()
			add_child(ability)
			ability.configure(self)
	for p in [Vector3(0,0,-4),Vector3(-8,0,-8),Vector3(9,0,-13),Vector3(-15,0,-20),Vector3(14,0,7),Vector3(-18,0,7)]:
		var target
		if survival_mode:
			target = OperatorScript.new() if targets.size() in [2,4] else DroneScript.new()
		else:
			target = TargetScript.new()
		target.position = p
		if survival_mode:
			target.game = self
		add_child(target)
		target.destroyed.connect(_on_target_destroyed)
		targets.append(target)
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = HudScript.new()
	hud.game = self
	layer.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if survival_mode and experimental_deployment:
		deployment = Deployment.new()
		add_child(deployment)
		start_deployment()
	if survival_mode and OS.has_feature("android"):
		print("ANDROID RAZE CLIPS READY ",player.raze.clip_motion.available)
		print("ANDROID FRONTIER READY | player=",player.model_loaded," weapon=",player.weapon_loaded," rivals=",targets.size()," viewport=",get_tree().root.content_scale_size)

func mat(hex: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex)
	m.roughness = 1.0
	if OS.has_feature("android") or OS.get_environment("LASTIMPACT_SAFE_RENDER")=="1":
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func block(pos: Vector3, size: Vector3, material: Material) -> void:
	var b := StaticBody3D.new()
	b.position = pos
	add_child(b)
	var v := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	v.mesh = mesh
	v.material_override = material
	b.add_child(v)
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	c.shape = s
	b.add_child(c)

func build_arena() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("8cabb8")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c9d2d0")
	env.ambient_light_energy = 0.78
	world_environment = env
	world.environment = env
	add_child(world)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50,-30,0)
	sun.light_energy = 1.05
	sun.shadow_enabled = false
	add_child(sun)
	if survival_mode:
		frontier = Frontier.new()
		add_child(frontier)
		frontier.build(self)
		return
	var floor_mat := mat("65736c")
	floor_mat.albedo_texture = ArenaArt.floor_texture()
	floor_mat.uv1_scale = Vector3(20,20,20)
	var concrete := mat("a7a596")
	var dark := mat("49575a")
	var orange := mat("b87942")
	var panel_tex := ArenaArt.panel_texture()
	concrete.albedo_texture = panel_tex
	concrete.uv1_scale = Vector3(4,2,1)
	dark.albedo_texture = panel_tex
	dark.uv1_scale = Vector3(6,2,1)
	orange.albedo_texture = panel_tex
	block(Vector3(0,-0.3,0),Vector3(80,0.6,80),floor_mat)
	for p in [Vector3(-40,1.5,0),Vector3(40,1.5,0)]:
		block(p,Vector3(0.5,3,80),dark)
	for p in [Vector3(0,1.5,-40),Vector3(0,1.5,40)]:
		block(p,Vector3(80,3,0.5),dark)
	for p in [Vector3(-6,0.75,1),Vector3(7,0.75,3),Vector3(4,0.75,-10),Vector3(-11,0.75,-14),Vector3(15,0.75,-4)]:
		block(p,Vector3(2.5,1.5,1.3),orange)
	for x in [-23,23]:
		block(Vector3(x,1.5,-10),Vector3(7,3,5),concrete)
		block(Vector3(x,1.5,14),Vector3(5,3,7),concrete)
	for x in range(-30,31,10):
		block(Vector3(x,0.015,24),Vector3(0.13,0.03,5),dark)
	block(Vector3(0,1.2,-29),Vector3(18,2.4,0.6),concrete)
	# Training obstacle: low roof with 1.15 m of clear height.
	block(Vector3(12,1.35,18),Vector3(3.0,0.4,2.5),concrete)
	for x in [10.4,13.6]:
		block(Vector3(x,0.68,18),Vector3(0.3,1.35,2.5),dark)

func _on_target_destroyed() -> void:
	eliminated += 1
	if survival_mode:
		return
	message = "Zona despejada · REINICIAR" if eliminated == targets.size() else "Objetivo neutralizado"

func qa_control(action: String) -> void:
	if OS.has_feature("android") and not qa_control_seen.has(action):
		qa_control_seen[action] = true
		print("LAST IMPACT CONTROL ",action)

func deployment_active() -> bool:
	return is_instance_valid(deployment) and deployment.active

func request_jump() -> void:
	if deployment_active():
		deployment.request_action()
	else:
		player.jump_requested = true

func start_deployment() -> void:
	hud.clear_controls()
	for target in targets:
		target.set_physics_process(false)
	deployment.begin(player)
	if not is_instance_valid(rival_deployment):
		rival_deployment = RivalDeployment.new()
		add_child(rival_deployment)
		rival_deployment.configure(self)
	rival_deployment.begin()

func _physics_process(delta: float) -> void:
	if is_instance_valid(rival_deployment) and not deployment_active() and round_result=="":
		rival_deployment.step(delta,deployment.flight,false)
	if deployment_active():
		var air_keys := Vector2(float(keys.get(KEY_D,false))-float(keys.get(KEY_A,false)),float(keys.get(KEY_S,false))-float(keys.get(KEY_W,false)))
		deployment.step(delta,(mobile_move+air_keys).limit_length(1.0))
		rival_deployment.step(delta,deployment.flight,deployment_active())
		fire = false
		if not deployment_active():
			hud.clear_controls()
			for target in targets:
				if not rival_deployment.airborne(target):
					target.set_physics_process(true)
			message = "Aterrizaje completado"
		return
	if survival_mode:
		if OS.has_feature("android") and android_qa_ticks<120:
			android_qa_ticks += 1
			if android_qa_ticks==120 and player.model_loaded and player.weapon_loaded:
				print("ANDROID FRONTIER TICKS 120")
				qa_sample_start = Time.get_ticks_msec()
				qa_sample_frames = Engine.get_frames_drawn()
		update_survival(delta)
		if round_result!="":
			return
	if is_instance_valid(supplies): supplies.step(delta)
	if is_instance_valid(ability): ability.step(delta)
	var keyboard := Vector2(float(keys.get(KEY_D,false))-float(keys.get(KEY_A,false)),float(keys.get(KEY_S,false))-float(keys.get(KEY_W,false)))
	player.move_input = (mobile_move+keyboard).limit_length(1.0)
	player.sprint = mobile_sprint or keys.get(KEY_SHIFT,false)
	player.combat_facing = fire
	player.reload_visual = clampf(reload_left/reload_duration(),0.0,1.0)
	cooldown = maxf(0.0,cooldown-delta)
	hit_left = maxf(0.0,hit_left-delta)
	if reload_left > 0.0:
		reload_left -= delta
		if reload_left <= 0.0:
			var amount := mini(magazine_capacity()-ammo,reserve)
			ammo += amount
			reserve -= amount
			message = "Listo"
			if amount>0:
				qa_control("RELOAD_COMPLETE")
	if fire and cooldown <= 0.0 and reload_left <= 0.0:
		shoot()

func shoot() -> void:
	if deployment_active():
		return
	if round_result!="":
		return
	if ammo <= 0:
		start_reload()
		return
	ammo -= 1
	qa_control("SHOT")
	cooldown = float(Arsenal.spec(weapon_id).delay)*(ability.shot_factor() if is_instance_valid(ability) else 1.0)
	if player.weapon_loaded:
		player.weapon.pulse()
	game_audio.fire_player.play()
	player.view_recoil = minf(0.05,player.view_recoil+0.018)
	var cam: Camera3D = player.camera
	var center := get_viewport().get_visible_rect().size*0.5
	var origin := cam.project_ray_origin(center)
	var endpoint := origin+cam.project_ray_normal(center)*float(Arsenal.spec(weapon_id).range)
	var state := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(origin,endpoint,3)
	var result := state.intersect_ray(ray)
	if not result.is_empty():
		endpoint = result["position"]
	# Check line from character toward the crosshair hit to prevent firing through nearby cover.
	var muzzle: Vector3 = player.global_position + Basis(Vector3.UP,player.yaw)*Vector3(0.34,0.75 if player.low_stance else 1.32,-0.60)
	if player.weapon_loaded:
		muzzle = player.weapon.flash.global_position
	var attack := state.intersect_ray(PhysicsRayQueryParameters3D.create(muzzle,endpoint+(endpoint-muzzle).normalized()*0.08,3))
	if is_instance_valid(combat_fx):
		var hit_kind := ""
		var impact: Vector3 = endpoint
		var normal := Vector3.UP
		if not attack.is_empty():
			impact = attack.position
			normal = attack.normal
			hit_kind = impact_kind(attack.collider)
		combat_fx.emit_shot(muzzle,impact,normal,hit_kind,player.global_position,str(Arsenal.spec(weapon_id).family))
	if not attack.is_empty() and attack["collider"].has_method("take_hit"):
		attack["collider"].take_hit(int(Arsenal.spec(weapon_id).damage))
		hit_left = 0.15
		game_audio.hit_player.play()

func impact_kind(collider: Object) -> String:
	if collider==player: return "SHIELD" if armor>0 else "BODY"
	if collider.get_script()==OperatorScript: return "SHIELD" if collider.armor>0 else "BODY"
	return "WORLD"

func spawn_operator_drop(operator: Node3D) -> void:
	if not experimental_deployment or not is_instance_valid(operator): return
	if operator.global_position.y>5.0: return
	var items: Array = DropTable.operator_drop(operator.rounds,operator.armor,round_seed+targets.find(operator))
	for i in range(items.size()):
		var pickup = PickupScript.new()
		pickup.kind = items[i][0]
		pickup.quantity = items[i][1]
		add_child(pickup)
		pickup.global_position = operator.global_position+Vector3((i*2-1)*0.42,0,0)
		pickups.append(pickup)
		corpse_pickups.append(pickup)

func spawn_dynamic_pickup(kind: String, quantity: int, point: Vector3):
	var pickup = PickupScript.new()
	pickup.kind = kind
	pickup.quantity = quantity
	add_child(pickup)
	pickup.global_position = point
	pickups.append(pickup)
	corpse_pickups.append(pickup)
	return pickup

func clear_operator_drops() -> void:
	for pickup in corpse_pickups:
		pickups.erase(pickup)
		if is_instance_valid(pickup):
			pickup.hide()
			pickup.active = false
			pickup.queue_free()
	corpse_pickups.clear()

func magazine_capacity() -> int:
	var base := int(Arsenal.spec(weapon_id).mag)
	return ceili(base*1.25) if is_instance_valid(supplies) and supplies.has_upgrade(weapon_id,"MAG") else base

func reload_duration() -> float:
	var base := float(Arsenal.spec(weapon_id).reload)
	return base*0.8 if is_instance_valid(supplies) and supplies.has_upgrade(weapon_id,"RELOAD") else base

func weapon_name() -> String:
	return str(Arsenal.spec(weapon_id).name)

func pickup_label(kind: String) -> String:
	return Arsenal.pickup_label(kind)

func equip_weapon(id: String, acquire: bool = false, loaded_rounds: int = -1, attachments: Dictionary = {}) -> bool:
	if not experimental_deployment or deployment_active() or round_result!="" or not Arsenal.DATA.has(id) or id==weapon_id: return false
	if not owned_weapons.has(id):
		if not acquire: return false
		if owned_weapons.size()>=2:
			var old: String = weapon_id
			var drop = spawn_dynamic_pickup("WEAPON_"+old,1,player.global_position+Vector3(0.8,0,0))
			drop.loaded_rounds = ammo
			if is_instance_valid(supplies): drop.attachments = supplies.upgrades.get(old,{}).duplicate()
			owned_weapons[owned_weapons.find(old)] = id
			if is_instance_valid(supplies): supplies.upgrades.erase(old)
			magazine_bank.erase(old)
		else:
			owned_weapons.append(id)
		if is_instance_valid(supplies) and not attachments.is_empty(): supplies.upgrades[id] = attachments.duplicate()
		var limit := int(Arsenal.spec(id).mag)
		if is_instance_valid(supplies) and supplies.has_upgrade(id,"MAG"): limit = ceili(limit*1.25)
		magazine_bank[id] = limit if loaded_rounds<0 else mini(loaded_rounds,limit)
	if owned_weapons.has(weapon_id): magazine_bank[weapon_id] = ammo
	reserve_bank[str(Arsenal.spec(weapon_id).family)] = reserve
	weapon_id = id
	ammo = int(magazine_bank.get(id,0))
	reserve = int(reserve_bank.get(str(Arsenal.spec(id).family),0))
	reload_left = 0.0
	cooldown = maxf(cooldown,0.25)
	if player.weapon_loaded:
		player.weapon.clear_effects()
		player.weapon.set_variant(Arsenal.spec(id).tint)
	sync_weapon_accessories()
	message = weapon_name()+" equipado"
	return true

func sync_weapon_accessories() -> void:
	if is_instance_valid(player) and player.weapon_loaded:
		var mods: Dictionary = supplies.upgrades.get(weapon_id,{}) if is_instance_valid(supplies) else {}
		player.weapon.set_accessories(mods)

func cycle_weapon() -> bool:
	if owned_weapons.size()<2: return false
	return equip_weapon(owned_weapons[(owned_weapons.find(weapon_id)+1)%owned_weapons.size()])

func collect_ammo(kind: String, quantity: int) -> int:
	var family: String = str(Arsenal.AMMO_TYPES.get(kind,""))
	if family.is_empty(): return 0
	var selected: bool = family==str(Arsenal.spec(weapon_id).family)
	var current: int = reserve if selected else int(reserve_bank.get(family,0))
	var taken := mini(maxi(0,quantity),maxi(0,InventoryScript.AMMO_MAX-current))
	if selected: reserve += taken
	else: reserve_bank[family] = current+taken
	return taken

func map_pickup_sites() -> Array[Vector3]:
	if not experimental_deployment: return frontier.loot_positions(round_seed)
	var sites: Array[Vector3] = frontier.battle_loot_positions(round_seed)
	sites.append_array(frontier.arsenal_sites(round_seed,sites))
	sites.append_array(frontier.utility_sites(round_seed,sites))
	return sites

func start_reload() -> void:
	if deployment_active():
		return
	if round_result!="":
		return
	if ammo < magazine_capacity() and reserve > 0 and reload_left <= 0.0:
		reload_left = reload_duration()
		game_audio.reload_player.play()
		message = "Recargando..."

func reset_round() -> void:
	if deployment_active():
		deployment.finish()
	clear_operator_drops()
	if is_instance_valid(supplies): supplies.reset()
	if is_instance_valid(ability): ability.reset()
	if is_instance_valid(combat_fx): combat_fx.reset()
	telemetry.reset()
	telemetry.latest = {}
	round_result = ""
	player.set_physics_process(true)
	zone_tick = 0.0
	if survival_mode:
		zone.reset_zone()
		inventory.reset()
		round_seed += 1
		var sites: Array[Vector3] = map_pickup_sites()
		for i in range(pickups.size()):
			pickups[i].position = sites[i]
			pickups[i].reset_pickup()
	for t in targets:
		t.reset_target()
		t.set_physics_process(true)
	eliminated = 0
	health = 100
	armor = 0
	weapon_id = "IGNIS"
	owned_weapons.assign(["IGNIS"])
	magazine_bank.clear()
	reserve_bank.clear()
	if player.weapon_loaded: player.weapon.set_variant(Color.WHITE)
	sync_weapon_accessories()
	ammo = 30
	reserve = 120
	reload_left = 0.0
	cooldown = 0.0
	hit_left = 0.0
	fire = false
	player.position = Vector3(0,0.1,12)
	player.yaw = 0.0
	player.pitch = -0.13
	player.reset_movement()
	player.reset_physics_interpolation()
	hud.clear_controls()
	message = "Supervivencia: permanece en la zona" if survival_mode else "Campo de entrenamiento"
	if is_instance_valid(deployment):
		start_deployment()
	if OS.has_feature("android") and survival_mode:
		print("ANDROID ROUND RESET | seed=",round_seed," health=",health," ammo=",ammo)

func apply_profile() -> void:
	adaptive_resolution.reset()
	telemetry.reset()
	telemetry.latest = {}
	Engine.max_fps = [30,45,60][profile]
	if OS.has_feature("android"):
		MobileProfile.apply_android(get_tree().root,profile)
	else:
		get_viewport().scaling_3d_scale = [0.65,0.82,1.0][profile]
	if is_instance_valid(frontier) and is_instance_valid(frontier.decor):
		# Shared instancing keeps decorative detail cheap; low profile drops roof trim only.
		if frontier.decor.get_child_count()>2:
			frontier.decor.get_child(2).visible = profile>0
	if is_instance_valid(zone):
		zone.set_profile(profile)
	sun.shadow_enabled = profile == 2 and not OS.has_feature("android")

func next_profile() -> void:
	profile = (profile+1)%3
	qa_control("PROFILE_%d" % profile)
	apply_profile()
	var config := ConfigFile.new()
	config.set_value("graphics","profile",profile)
	config.save("user://lastimpact.cfg")
	if round_result=="":
		message = ["Bajo seguro · 30 FPS","Medio · 45 FPS","Alto · 60 FPS"][profile]

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and experimental_deployment:
		# Detach the instances before their shared render resources are released.
		for instance in find_children("*","MeshInstance3D",true,false):
			instance.mesh = null
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		telemetry_paused = true
		telemetry.reset()
		telemetry.latest = {}
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		telemetry_paused = false
		telemetry.reset()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().change_scene_to_file("res://lobby.tscn")

func update_survival(delta: float) -> void:
	if round_result!="":
		return
	zone.advance(delta)
	zone_tick += delta
	while zone_tick>=1.0:
		zone_tick -= 1.0
		if zone.outside(player.global_position):
			damage_player(5 if zone.phase<2 else 10,false)
		if round_result!="":
			return
		for target in targets:
			if target.active and (not is_instance_valid(rival_deployment) or not rival_deployment.airborne(target)) and zone.outside(target.global_position):
				target.take_hit(5 if zone.phase<2 else 10)
	if eliminated>=targets.size():
		finish_survival("VICTORIA")

func damage_player(amount: int, combat: bool = true) -> void:
	if deployment_active():
		return
	if not survival_mode or round_result!="" or amount<=0:
		return
	if is_instance_valid(ability): amount = ability.reduce_damage(amount,combat)
	var absorbed := mini(armor,amount)
	armor -= absorbed
	health = maxi(0,health-(amount-absorbed))
	if health==0:
		finish_survival("DERROTA")

func finish_survival(result: String) -> void:
	if round_result!="":
		return
	round_result = result
	message = result+" · REINICIAR o LOBBY"
	hud.clear_controls()
	player.reset_movement()
	player.set_physics_process(false)
	reload_left = 0.0

func spawn_pickups() -> void:
	var sites: Array[Vector3] = map_pickup_sites()
	var contents: Array = [
		["MED",1,Vector3(-3,0,10)],["SHIELD",1,Vector3(3,0,10)],["AMMO",40,Vector3(0,0,7)],
		["MED",2,Vector3(-10,0,3)],["SHIELD",2,Vector3(10,0,5)],["AMMO",50,Vector3(0,0,-7)],
		["MED",1,Vector3(-7,0,-19)],["SHIELD",1,Vector3(7,0,-20)],["AMMO",40,Vector3(17,0,13)]
	]
	if experimental_deployment:
		contents.append_array([["WEAPON_VOLTAR",1],["AMMO_LIGHT",72],["WEAPON_ARC",1],["AMMO_PLASMA",36],["WEAPON_HELIOS",1],["AMMO_HEAVY",18],["CASH",100],["GRENADE",1],["CASH",150],["GRENADE",2]])
	for data in contents:
		var pickup = PickupScript.new()
		pickup.kind = data[0]
		pickup.quantity = data[1]
		pickup.position = sites[pickups.size()]
		add_child(pickup)
		pickups.append(pickup)

func nearest_pickup():
	if deployment_active():
		return null
	if not survival_mode or round_result!="":
		return null
	var closest = null
	var best := PICKUP_RANGE
	for pickup in pickups:
		if not pickup.active:
			continue
		var distance: float = player.global_position.distance_to(pickup.global_position)
		if distance<=best:
			best = distance
			closest = pickup
	return closest

func collect_nearby() -> bool:
	var pickup = nearest_pickup()
	if pickup==null:
		return false
	var taken := 0
	if pickup.kind.begins_with("WEAPON_"):
		var id: String = pickup.kind.trim_prefix("WEAPON_")
		if owned_weapons.has(id):
			message = "Arma ya disponible"
			return false
		if not equip_weapon(id,true,pickup.loaded_rounds,pickup.attachments): return false
		pickup.collect(1)
		qa_control("PICKUP")
		return true
	elif pickup.kind=="CASH" and is_instance_valid(supplies):
		taken = pickup.quantity
		supplies.credits += taken
	elif pickup.kind=="GRENADE" and is_instance_valid(supplies):
		taken = mini(pickup.quantity,4-supplies.grenades)
		supplies.grenades += taken
	elif Arsenal.AMMO_TYPES.has(pickup.kind):
		taken = collect_ammo(pickup.kind,pickup.quantity)
	else:
		taken = inventory.add_item(pickup.kind,pickup.quantity)
	if taken<=0:
		message = "Capacidad completa"
		return false
	pickup.collect(taken)
	qa_control("PICKUP")
	message = "Suministro recogido: +%d" % taken
	return true

func use_medkit() -> bool:
	if deployment_active():
		return false
	if not survival_mode or round_result!="":
		return false
	var next: int = inventory.use_med(health)
	if next==health:
		return false
	health = next
	message = "Salud restaurada"
	return true

func use_shield_cell() -> bool:
	if deployment_active():
		return false
	if not survival_mode or round_result!="":
		return false
	var next: int = inventory.use_shield(armor)
	if next==armor:
		return false
	armor = next
	message = "Escudo restaurado"
	return true

func update_adaptive_resolution() -> void:
	if not OS.has_feature("android") or profile!=0 or not survival_mode or telemetry_paused or round_result!="" or not is_instance_valid(hud) or not is_instance_valid(player):
		return
	var safe: bool = hud.move_id<0 and hud.look_id<0 and hud.fire_id<0 and not fire and not player.aiming and reload_left<=0.0 and player.animation_speed<0.15 and player.is_on_floor() and player.slide_time<=0.0
	if adaptive_resolution.commit_if_safe(safe):
		get_tree().root.content_scale_size = adaptive_resolution.resolution()
		telemetry.reset()
		telemetry.latest = {}
		print("LAST IMPACT ADAPTIVE RESOLUTION ",adaptive_resolution.resolution())

func _process(_delta: float) -> void:
	if deployment_active():
		return
	update_adaptive_resolution()
	if round_result=="" and reload_left<=0.0 and message_left>0.0:
		message_left = maxf(0.0,message_left-_delta)
		if message_left<=0.0:
			message = ""
	if survival_mode and is_instance_valid(zone) and is_instance_valid(player):
		var body_exposure: float = zone.exposure(player.global_position)
		var camera_exposure: float = zone.exposure(player.camera.global_position)
		var exposure_target := maxf(body_exposure,camera_exposure*0.78)
		storm_exposure = lerpf(storm_exposure,exposure_target,1.0-exp(-_delta*2.6))
		world_environment.background_color = Color("8cabb8").lerp(Color("7f5937"),storm_exposure)
		world_environment.ambient_light_color = Color("c9d2d0").lerp(Color("b28e71"),storm_exposure)
		world_environment.fog_enabled = false
		world_environment.fog_light_color = Color("a07850")
		world_environment.fog_density = 0.0
		game_audio.set_storm_exposure(storm_exposure)
	if survival_mode and round_result=="" and not telemetry_paused and (not OS.has_feature("android") or android_qa_ticks>=120):
		var report := telemetry.record(Time.get_ticks_usec(),profile)
		if not report.is_empty():
			report["seed"] = round_seed
			report["zone_phase"] = zone.phase
			report["storm_exposure"] = storm_exposure
			report["build"] = ProjectSettings.get_setting("application/config/version")
			report["air_clips"] = player.raze.air_motion.available
			report["air_samples"] = player.raze.air_motion.samples
			report["sprint_tuned"] = player.raze.clip_motion.sprint_lock_enabled
			report["adaptive_level"] = adaptive_resolution.level
			var base_size: Vector2i = get_tree().root.content_scale_size
			report["base_width"] = base_size.x
			report["base_height"] = base_size.y
			report["player_animation_us_ema"] = player.animation_cost_us
			report["weapon_ik_us_ema"] = player.weapon_cost_us
			var operator_cost := 0.0
			var operator_skips := 0
			var hidden_operators := 0
			for rival in targets:
				if rival.active and "animation_cost_us" in rival:
					operator_cost += float(rival.animation_cost_us)
					operator_skips += int(rival.offscreen_anim_skips)
					hidden_operators += 1 if rival.lens_hidden else 0
			report["operator_animation_us_ema_sum"] = operator_cost
			report["operator_reduced_ticks"] = operator_skips
			report["lens_hidden_operators"] = hidden_operators
			report["locomotion_clips"] = player.raze.clip_motion.available
			report["clip_samples"] = player.raze.clip_motion.sample_count
			report["torso_clip_weight"] = player.raze.clip_motion.torso_weight
			report["crouch_clips"] = player.raze.crouch_motion.available
			report["crouch_samples"] = player.raze.crouch_motion.samples
			report["gait_calibrated"] = player.raze.clip_motion.calibrated
			report["gait_cadence_hz"] = player.raze.clip_motion.cadence_hz
			report["foot_contacts"] = player.raze.foot_contact.contact_count
			report["foot_ik_residual_m"] = player.raze.foot_contact.max_error
			report["static_blocks"] = frontier.batched_blocks
			report["static_groups"] = frontier.batch_draw_groups
			report["os"] = OS.get_name()
			report["device"] = OS.get_model_name()
			print("LAST IMPACT TELEMETRY ",JSON.stringify(report))
			if OS.has_feature("android") and profile==0:
				adaptive_resolution.observe(report)
	if not OS.has_feature("android") or not survival_mode or qa_sample_done or qa_sample_start==0:
		return
	var elapsed := Time.get_ticks_msec()-qa_sample_start
	if elapsed>=10000:
		qa_sample_done = true
		var count := Engine.get_frames_drawn()-qa_sample_frames
		print("ANDROID FRONTIER PERF | frames=",count," ms=",elapsed," fps=",float(count)*1000.0/float(elapsed)," static_mb=",Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0)
