extends Node3D
const Raze = preload("res://scripts/raze.gd")
var actor: Node3D
var caption: Label
var loaded := false

func _ready() -> void:
	Engine.max_fps = 30
	get_viewport().scaling_3d_scale = 1.0
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("243844")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.9
	world.environment = env
	add_child(world)
	var camera := Camera3D.new()
	camera.position = Vector3(0,1.05,-3.5)
	add_child(camera)
	camera.look_at(Vector3(0,0.9,0))
	camera.current = true
	actor = Raze.new()
	add_child(actor)
	loaded = actor.load_model()
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var ui := Control.new()
	canvas.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caption = Label.new()
	caption.position = Vector2(22,20)
	caption.add_theme_font_size_override("font_size",22)
	caption.text = "RAZE / OPERADOR 01\nModelo cargado" if loaded else "RAZE / Archivo GLB pendiente"
	ui.add_child(caption)
	var hint := Label.new()
	hint.position = Vector2(22,90)
	hint.text = "Toca la mitad izquierda para bailar.\nMitad derecha: volver al lobby."
	ui.add_child(hint)

func _process(delta: float) -> void:
	if loaded:
		actor.rotate_y(delta*0.4)

func _input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed):
		if event.position.x < get_viewport().get_visible_rect().size.x*0.5 and loaded:
			if actor.dance():
				caption.text = "RAZE / Animacion original Tripo"
			else:
				caption.text = "RAZE / Animacion no disponible"
		else:
			get_tree().change_scene_to_file("res://lobby.tscn")
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://lobby.tscn")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().change_scene_to_file("res://lobby.tscn")
