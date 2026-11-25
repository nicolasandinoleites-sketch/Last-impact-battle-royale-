extends Node3D
var cube: MeshInstance3D
var label: Label

func _ready() -> void:
	Engine.max_fps = 30
	get_viewport().scaling_3d_scale = 1.0
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("46798c")
	world.environment = env
	add_child(world)
	var cam := Camera3D.new()
	cam.position = Vector3(3,2,5)
	add_child(cam)
	cam.look_at(Vector3.ZERO)
	cam.current = true
	cube = MeshInstance3D.new()
	cube.mesh = BoxMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("ff9b38")
	cube.material_override = mat
	add_child(cube)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var root := Control.new()
	canvas.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label = Label.new()
	label.position = Vector2(20,20)
	label.add_theme_font_size_override("font_size",20)
	root.add_child(label)
	var hint := Label.new()
	hint.position = Vector2(20,90)
	hint.text = "Debe verse un cubo naranja sobre fondo azul.\nToca la pantalla para volver al lobby."
	hint.add_theme_font_size_override("font_size",18)
	root.add_child(hint)
	print("LAST IMPACT R03 DIAGNOSTIC READY")

func _process(delta: float) -> void:
	cube.rotate_y(delta)
	label.text = "DIAGNOSTICO 3D / %d FPS\n%s" % [Engine.get_frames_per_second(),RenderingServer.get_video_adapter_name()]

func _input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		get_tree().change_scene_to_file("res://lobby.tscn")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().change_scene_to_file("res://lobby.tscn")
