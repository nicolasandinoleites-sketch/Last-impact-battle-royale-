extends SubViewport
const Raze = preload("res://scripts/raze.gd")
const Ignis = preload("res://scripts/ignis.gd")
var actor: Node3D
var weapon: Node3D
var loaded := false

func _ready() -> void:
	size = Vector2i(360,390)
	own_world_3d = true
	transparent_bg = true
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("17252e")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 1.0
	add_child(env)
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0.30,1.05,-3.0)
	cam.look_at(Vector3(0,0.92,0))
	cam.fov = 39.0
	cam.current = true
	actor = Raze.new()
	add_child(actor)
	loaded = actor.load_model()
	if loaded:
		weapon = Ignis.new()
		add_child(weapon)
		loaded = weapon.equip(actor.right_socket,actor)
		weapon.actor = actor
		actor.armed = loaded

func _process(delta: float) -> void:
	if loaded:
		actor.rotation.y = 0.68 + sin(Time.get_ticks_msec()*0.0006)*0.12
		actor.locomotion(delta,0.0,true,false,false)
		weapon.update_pose(delta,false,0.0)
