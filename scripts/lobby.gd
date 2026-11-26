extends Control

const BG := Color("121d26")
const PANEL := Color("202e39")
const EDGE := Color("354854")
const WHITE := Color("f2f5f5")
const MUTED := Color("a2b6c2")
const GOLD := Color("ffae58")
const LOGO = preload("res://icon.svg")
const Preview = preload("res://scripts/lobby_preview.gd")
var preview: SubViewport
var mode := "home"
var quality := 0
var status := ""
var launching := false
var info := ""
var refresh_left := 0.0
var preview_pending := false
var preview_elapsed := 0.0
var preview_load_ms := -1
var preview_started_ms := 0
var preview_resources: Array[Resource] = []
const PREVIEW_PATHS = ["res://assets/tripo/raze.glb","res://assets/tripo/ignis_x1.glb"]

func _ready() -> void:
	Engine.max_fps = 30
	get_viewport().scaling_3d_scale = 1.0
	var config := ConfigFile.new()
	if config.load("user://lastimpact.cfg") == OK:
		quality = clampi(int(config.get_value("graphics","profile",0)),0,2)
	info = "%s | %s" % [RenderingServer.get_video_adapter_name(),RenderingServer.get_video_adapter_api_version()]
	print("LAST IMPACT R070 LOBBY READY | ",info)
	if DisplayServer.get_name() != "headless":
		preview_pending = true
		preview_started_ms = Time.get_ticks_msec()
		for path in PREVIEW_PATHS:
			if ResourceLoader.load_threaded_request(path)!=OK:
				preview_pending = false
	queue_redraw()

func _process(delta: float) -> void:
	if preview_pending:
		preview_elapsed += delta
	poll_preview()
	if is_instance_valid(preview):
		preview.active_preview = (mode=="home" or mode=="loadout" or mode=="operator") and not launching
		if not preview.active_preview:
			preview.render_target_update_mode = SubViewport.UPDATE_DISABLED
	refresh_left -= delta
	if refresh_left <= 0.0:
		refresh_left = 0.25
		queue_redraw()

func rect(x: float,y: float,w: float,h: float) -> Rect2:
	return Rect2(Vector2(x,y)*size/Vector2(960,540),Vector2(w,h)*size/Vector2(960,540))

func point(x: float,y: float) -> Vector2:
	return Vector2(x,y)*size/Vector2(960,540)

func text_at(x: float,y: float,caption: String,px: int,color: Color = WHITE) -> void:
	var n := maxi(9,int(px*minf(size.x/960.0,size.y/540.0)))
	draw_string(ThemeDB.fallback_font,point(x,y),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,n,color)

func panel(area: Rect2,color: Color = PANEL) -> void:
	draw_rect(area,color)
	draw_rect(area,EDGE,false,1.0)

func action(area: Rect2,caption: String,highlight: bool = false,disabled: bool = false) -> void:
	var color := Color("36444b") if disabled else (GOLD if highlight else PANEL)
	panel(area,color)
	var px := maxi(10,int(19*minf(size.x/960.0,size.y/540.0)))
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,px).x
	draw_string(font,area.get_center()+Vector2(-width/2.0,px*0.34),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,px,BG if highlight else (MUTED if disabled else WHITE))

func operator_art() -> void:
	draw_stage()
	if is_instance_valid(preview) and preview.loaded:
		var area := rect(292,94,376,350)
		var ratio := minf(area.size.x/float(preview.size.x),area.size.y/float(preview.size.y))
		var dimensions := Vector2(preview.size)*ratio
		draw_texture_rect(preview.get_texture(),Rect2(area.get_center()-dimensions*0.5,dimensions),false)
		text_at(385,450,"RAZE / IGNIS X1",19,GOLD)
		text_at(390,474,"OPERADOR DE ASALTO",13,MUTED)
		return
	var parts := [
		[442,185,76,72,Color("536975")],
		[451,127,58,64,Color("41525a")],
		[459,144,42,13,GOLD],
		[429,199,22,103,Color("455760")],
		[510,199,22,103,Color("455760")],
		[450,259,27,128,Color("364a54")],
		[484,259,27,128,Color("364a54")],
		[444,380,34,21,Color("26353e")],
		[484,380,34,21,Color("26353e")],
		[452,198,56,38,Color("283942")]
	]
	for p in parts:
		draw_rect(rect(p[0],p[1],p[2],p[3]),p[4])
	text_at(421,439,"RAZE / OPERADOR 01",17)
	text_at(405,459,"Vista previa segura",13,MUTED)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),BG)
	for i in range(9):
		draw_line(point(i*150-300,540),point(i*150+250,0),Color(0.25,0.36,0.43,0.14),1.0)
	draw_texture_rect(LOGO,rect(24,18,58,58),false)
	text_at(96,47,"LAST IMPACT",31)
	text_at(98,69,"R070 / ALPHA TECNICA",13,MUTED)
	text_at(768,40,"OFFLINE",15,GOLD)
	text_at(768,64,"%d FPS" % Engine.get_frames_per_second(),15,MUTED)
	draw_line(point(24,88),point(936,88),EDGE,1.0)
	if mode == "home":
		panel(rect(24,112,248,84))
		text_at(40,143,"RECLUTA",23)
		text_at(40,173,"Nivel 01  |  Perfil local",15,MUTED)
		action(rect(24,211,248,54),"OPERADOR")
		action(rect(24,276,248,54),"ARMAMENTO")
		action(rect(24,341,248,54),"AJUSTES")
		operator_art()
		panel(rect(690,112,246,154))
		text_at(704,139,"MODO DE JUEGO",14,GOLD)
		text_at(704,171,"ENTRENAMIENTO",20)
		text_at(704,196,"6 objetivos / offline",14,MUTED)
		text_at(704,226,"Supervivencia: 6 drones",13,MUTED)
		action(rect(690,270,246,48),"DIAGNOSTICO 3D")
		action(rect(690,326,246,50),"ENTRENAR")
		action(rect(690,384,246,54),"SUPERVIVENCIA",true)
		text_at(26,500,"Build de prueba | Android",14,MUTED)
		text_at(690,460,"Calidad: "+["Baja segura","Media","Alta"][quality],14,MUTED)
	elif mode == "settings":
		text_at(35,128,"AJUSTES GRAFICOS",29)
		text_at(35,161,"Modo seguro: resolucion nativa, 30 FPS, sin sombras.",17,MUTED)
		for i in range(3):
			action(rect(35,190+i*64,500,52),["BAJA SEGURA / 30 FPS","MEDIA / 45 FPS","ALTA / 60 FPS"][i],i==quality)
		text_at(35,414,"Motor: Compatibility / OpenGL ES 3",17,MUTED)
		text_at(35,440,info.left(85),13,MUTED)
		action(rect(710,450,226,62),"VOLVER")
	elif mode == "loadout":
		operator_art()
		panel(rect(24,112,248,210))
		text_at(40,142,"EQUIPAMIENTO",17,GOLD)
		text_at(40,178,"IGNIS X1",24)
		text_at(40,207,"Rifle de energia",15,MUTED)
		text_at(40,233,"Capacidad: 30",15,MUTED)
		text_at(40,259,"Reserva inicial: 120",15,MUTED)
		text_at(40,291,"Equipado",15,GOLD)
		action(rect(710,450,226,62),"VOLVER")
	elif mode == "operator":
		text_at(35,128,"OPERADORES",29)
		operator_art()
		text_at(35,186,"OPERADOR 01",20,GOLD)
		text_at(35,214,"Recluta de pruebas",17,MUTED)
		text_at(35,242,"Modelo RAZE",16,MUTED)
		action(rect(710,450,226,62),"VOLVER")
	if launching:
		panel(rect(290,465,380,52),Color("27333d"))
		text_at(310,497,"Cargando escenario...",19,GOLD)
	elif not status.is_empty():
		text_at(26,525,status.left(110),13,GOLD)

func choose_profile(value: int) -> void:
	quality = clampi(value,0,2)
	var config := ConfigFile.new()
	config.set_value("graphics","profile",quality)
	config.save("user://lastimpact.cfg")
	queue_redraw()

func launch(path: String) -> void:
	if launching:
		return
	launching = true
	queue_redraw()
	await get_tree().process_frame
	var error := ResourceLoader.load_threaded_request(path)
	if error == OK:
		while ResourceLoader.load_threaded_get_status(path)==ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
		if ResourceLoader.load_threaded_get_status(path)==ResourceLoader.THREAD_LOAD_LOADED:
			var packed := ResourceLoader.load_threaded_get(path) as PackedScene
			error = get_tree().change_scene_to_packed(packed) if packed!=null else ERR_CANT_OPEN
		else:
			error = ERR_CANT_OPEN
	else:
		error = get_tree().change_scene_to_file(path)
	if error != OK:
		launching = false
		status = "No se pudo cargar el escenario: %s" % error
		queue_redraw()

func activate(pos: Vector2) -> void:
	if launching:
		return
	if mode == "home":
		if rect(690,384,246,54).has_point(pos):
			launch("res://survival.tscn")
		elif rect(690,326,246,50).has_point(pos):
			launch("res://main.tscn")
		elif rect(690,270,246,48).has_point(pos):
			launch("res://diagnostic.tscn")
		elif rect(24,341,248,54).has_point(pos):
			mode = "settings"
		elif rect(24,211,248,54).has_point(pos):
			launch("res://operator.tscn")
		elif rect(24,276,248,54).has_point(pos):
			mode = "loadout"
	else:
		if rect(710,450,226,62).has_point(pos):
			mode = "home"
		elif mode == "settings":
			for i in range(3):
				if rect(35,190+i*64,500,52).has_point(pos):
					choose_profile(i)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and not event.canceled:
		activate(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not OS.has_feature("android"):
		activate(event.position)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		mode = "home"
		queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		mode = "home"
		queue_redraw()

func draw_stage() -> void:
	var area := rect(288,98,384,346)
	draw_rect(area,Color("192730"))
	draw_rect(rect(304,112,352,236),Color("253741"))
	for i in range(5):
		var x := 308.0+i*85.0
		draw_rect(rect(x,114,5,235),Color("344954"))
		draw_rect(rect(x+7,122,2,128),Color("536873"))
	draw_rect(rect(305,120,350,6),Color("41525b"))
	draw_rect(rect(305,132,350,3),Color("c87943"))
	draw_colored_polygon(PackedVector2Array([point(304,349),point(656,349),point(672,443),point(288,443)]),Color("202c34"))
	for i in range(7):
		draw_line(point(480,349),point(288+i*64,443),Color("384952"),1.0,true)
	for y in [368,392,420]:
		draw_line(point(298,y),point(662,y),Color("384952"),1.0,true)
	draw_set_transform(point(480,409),0.0,Vector2(size.x/960.0,size.y/540.0))
	draw_circle(Vector2.ZERO,75.0,Color(0.08,0.12,0.15,0.55))
	draw_arc(Vector2.ZERO,75.0,0.0,TAU,48,Color("91643f"),2.0,true)
	draw_set_transform(Vector2.ZERO)
	draw_rect(area,EDGE,false,1.0)

func poll_preview() -> void:
	if not preview_pending or launching:
		return
	if preview_elapsed>12.0:
		preview_pending = false
		status = "Vista previa: modo seguro"
		return
	for path in PREVIEW_PATHS:
		var state := ResourceLoader.load_threaded_get_status(path)
		if state==ResourceLoader.THREAD_LOAD_FAILED or state==ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			preview_pending = false
			status = "Vista previa no disponible"
			return
		if state!=ResourceLoader.THREAD_LOAD_LOADED:
			return
	for path in PREVIEW_PATHS:
		var resource := ResourceLoader.load_threaded_get(path)
		if resource!=null:
			preview_resources.append(resource)
	preview_pending = false
	preview = Preview.new()
	add_child(preview)
	preview_load_ms = Time.get_ticks_msec()-preview_started_ms
	if preview.loaded:
		print("LOBBY PREVIEW READY MS ",preview_load_ms)
	else:
		status = "Vista previa no disponible: modo seguro"
		preview.queue_free()
		preview = null
	queue_redraw()
