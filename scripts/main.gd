extends Node3D
const PlayerScript = preload("res://scripts/player.gd")
const TargetScript = preload("res://scripts/target.gd")
const HudScript = preload("res://scripts/hud.gd")
var player
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

func _ready() -> void:
	var config := ConfigFile.new()
	if config.load("user://lastimpact.cfg") == OK:
		profile = clampi(int(config.get_value("graphics","profile",0)),0,2)
	build_arena()
	apply_profile()
	player = PlayerScript.new()
	player.position = Vector3(0,0.1,12)
	add_child(player)
	for p in [Vector3(0,0,-4),Vector3(-8,0,-8),Vector3(9,0,-13),Vector3(-15,0,-20),Vector3(14,0,7),Vector3(-18,0,7)]:
		var target = TargetScript.new()
		target.position = p
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
	if OS.has_feature("android"):
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
	env.background_color = Color("81959e")
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
	var concrete := mat("a7a596")
	var dark := mat("49575a")
	var orange := mat("b87942")
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
	message = "Zona despejada · REINICIAR" if eliminated == targets.size() else "Objetivo neutralizado"

func _physics_process(delta: float) -> void:
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
	if ammo <= 0:
		start_reload()
		return
	ammo -= 1
	cooldown = 0.15
	if player.weapon_loaded:
		player.weapon.pulse()
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
	var attack := state.intersect_ray(PhysicsRayQueryParameters3D.create(muzzle,endpoint+(endpoint-muzzle).normalized()*0.08,3))
	if not attack.is_empty() and attack["collider"].has_method("take_hit"):
		attack["collider"].take_hit(34)
		hit_left = 0.15

func start_reload() -> void:
	if ammo < 30 and reserve > 0 and reload_left <= 0.0:
		reload_left = 1.4
		message = "Recargando..."

func reset_round() -> void:
	for t in targets:
		t.reset_target()
	eliminated = 0
	ammo = 30
	reserve = 120
	reload_left = 0.0
	cooldown = 0.0
	hit_left = 0.0
	fire = false
	player.position = Vector3(0,0.1,12)
	player.reset_movement()
	hud.clear_controls()
	player.yaw = 0.0
	player.pitch = -0.13
	message = "Campo de entrenamiento"

func apply_profile() -> void:
	Engine.max_fps = [30,45,60][profile]
	get_viewport().scaling_3d_scale = 1.0 if OS.has_feature("android") else [0.65,0.82,1.0][profile]
	sun.shadow_enabled = profile == 2 and not OS.has_feature("android")

func next_profile() -> void:
	profile = (profile+1)%3
	apply_profile()
	message = ["Bajo seguro · 30 FPS","Medio · 45 FPS","Alto · 60 FPS"][profile]

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().change_scene_to_file("res://lobby.tscn")
