extends Node3D
const PlayerScript = preload("res://scripts/player.gd")
const TargetScript = preload("res://scripts/target.gd")
const HudScript = preload("res://scripts/hud.gd")
var player
@export var survival_mode := false
const ZoneScript = preload("res://scripts/survival_zone.gd")
const DroneScript = preload("res://scripts/survival_drone.gd")
var zone
var round_result := ""
var zone_tick := 0.0
const InventoryScript = preload("res://scripts/survival_inventory.gd")
const PickupScript = preload("res://scripts/survival_pickup.gd")
var inventory = InventoryScript.new()
var pickups: Array = []
const PICKUP_RANGE := 1.8

const GameAudio = preload("res://scripts/game_audio.gd")
var game_audio: Node
var health := 100
var armor := 0
var hud
var targets: Array = []
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
var message := "Campo de entrenamiento"
const ArenaArt = preload("res://scripts/arena_art.gd")
var arena_art: Node3D

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load("user://lastimpact.cfg") == OK:
		profile = clampi(int(config.get_value("graphics","profile",0)),0,2)
	game_audio = GameAudio.new()
	add_child(game_audio)
	build_arena()
	arena_art = ArenaArt.new()
	add_child(arena_art)
	arena_art.decorate(self)
	apply_profile()
	player = PlayerScript.new()
	player.position = Vector3(0,0.1,12)
	add_child(player)
	if survival_mode:
		zone = ZoneScript.new()
		add_child(zone)
		message = "Supervivencia: permanece en la zona"
		spawn_pickups()
	for p in [Vector3(0,0,-4),Vector3(-8,0,-8),Vector3(9,0,-13),Vector3(-15,0,-20),Vector3(14,0,7),Vector3(-18,0,7)]:
		var target = DroneScript.new() if survival_mode else TargetScript.new()
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
	world.environment = env
	add_child(world)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50,-30,0)
	sun.light_energy = 1.05
	sun.shadow_enabled = false
	add_child(sun)
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

func _physics_process(delta: float) -> void:
	if survival_mode:
		update_survival(delta)
		if round_result!="":
			return
	var keyboard := Vector2(float(keys.get(KEY_D,false))-float(keys.get(KEY_A,false)),float(keys.get(KEY_S,false))-float(keys.get(KEY_W,false)))
	player.move_input = (mobile_move+keyboard).limit_length(1.0)
	player.sprint = mobile_sprint or keys.get(KEY_SHIFT,false)
	player.combat_facing = fire
	player.reload_visual = clampf(reload_left/1.4,0.0,1.0)
	cooldown = maxf(0.0,cooldown-delta)
	hit_left = maxf(0.0,hit_left-delta)
	if reload_left > 0.0:
		reload_left -= delta
		if reload_left <= 0.0:
			var amount := mini(30-ammo,reserve)
			ammo += amount
			reserve -= amount
			message = "Listo"
	if fire and cooldown <= 0.0 and reload_left <= 0.0:
		shoot()

func shoot() -> void:
	if round_result!="":
		return
	if ammo <= 0:
		start_reload()
		return
	ammo -= 1
	cooldown = 0.15
	if player.weapon_loaded:
		player.weapon.pulse()
	game_audio.fire_player.play()
	player.view_recoil = minf(0.05,player.view_recoil+0.018)
	var cam: Camera3D = player.camera
	var center := get_viewport().get_visible_rect().size*0.5
	var origin := cam.project_ray_origin(center)
	var endpoint := origin+cam.project_ray_normal(center)*100.0
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
	if not attack.is_empty() and attack["collider"].has_method("take_hit"):
		attack["collider"].take_hit(34)
		hit_left = 0.15
		game_audio.hit_player.play()

func start_reload() -> void:
	if round_result!="":
		return
	if ammo < 30 and reserve > 0 and reload_left <= 0.0:
		reload_left = 1.4
		game_audio.reload_player.play()
		message = "Recargando..."

func reset_round() -> void:
	round_result = ""
	zone_tick = 0.0
	if survival_mode:
		zone.reset_zone()
		inventory.reset()
		for pickup in pickups:
			pickup.reset_pickup()
	for t in targets:
		t.reset_target()
	eliminated = 0
	health = 100
	armor = 0
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

func apply_profile() -> void:
	Engine.max_fps = [30,45,60][profile]
	get_viewport().scaling_3d_scale = 1.0 if OS.has_feature("android") else [0.65,0.82,1.0][profile]
	sun.shadow_enabled = profile == 2 and not OS.has_feature("android")

func next_profile() -> void:
	profile = (profile+1)%3
	apply_profile()
	var config := ConfigFile.new()
	config.set_value("graphics","profile",profile)
	config.save("user://lastimpact.cfg")
	if round_result=="":
		message = ["Bajo seguro · 30 FPS","Medio · 45 FPS","Alto · 60 FPS"][profile]

func _notification(what: int) -> void:
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
			damage_player(5 if zone.phase<2 else 10)
		if round_result!="":
			return
		for target in targets:
			if target.active and zone.outside(target.global_position):
				target.take_hit(5 if zone.phase<2 else 10)
	if eliminated>=targets.size():
		finish_survival("VICTORIA")

func damage_player(amount: int) -> void:
	if not survival_mode or round_result!="" or amount<=0:
		return
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
	reload_left = 0.0

func spawn_pickups() -> void:
	for data in [
		["MED",1,Vector3(-3,0,10)],["SHIELD",1,Vector3(3,0,10)],["AMMO",40,Vector3(0,0,7)],
		["MED",2,Vector3(-10,0,3)],["SHIELD",2,Vector3(10,0,5)],["AMMO",50,Vector3(0,0,-7)],
		["MED",1,Vector3(-7,0,-19)],["SHIELD",1,Vector3(7,0,-20)],["AMMO",40,Vector3(17,0,13)]
	]:
		var pickup = PickupScript.new()
		pickup.kind = data[0]
		pickup.quantity = data[1]
		pickup.position = data[2]
		add_child(pickup)
		pickups.append(pickup)

func nearest_pickup():
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
	if pickup.kind=="AMMO":
		taken = mini(pickup.quantity,maxi(0,InventoryScript.AMMO_MAX-reserve))
		reserve += taken
	else:
		taken = inventory.add_item(pickup.kind,pickup.quantity)
	if taken<=0:
		message = "Capacidad completa"
		return false
	pickup.collect(taken)
	message = "Suministro recogido: +%d" % taken
	return true

func use_medkit() -> bool:
	if not survival_mode or round_result!="":
		return false
	var next: int = inventory.use_med(health)
	if next==health:
		return false
	health = next
	message = "Salud restaurada"
	return true

func use_shield_cell() -> bool:
	if not survival_mode or round_result!="":
		return false
	var next: int = inventory.use_shield(armor)
	if next==armor:
		return false
	armor = next
	message = "Escudo restaurado"
	return true
