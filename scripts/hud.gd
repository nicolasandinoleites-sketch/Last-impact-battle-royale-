extends Control
var game
var move_id := -1
var look_id := -1
var fire_id := -1
var sprint_id := -1
var move_center := Vector2.ZERO
var knob := Vector2.ZERO
var mouse_look := false
var mouse_fire := false
const WHITE := Color(0.95,0.97,0.97,0.96)
const DARK := Color(0.04,0.07,0.09,0.77)
const ACCENT := Color(0.96,0.57,0.24,1)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(true)

func _process(_delta: float) -> void:
	queue_redraw()

func at(x: float,y: float) -> Vector2:
	return Vector2(size.x*x,size.y*y)

func unit() -> float:
	return clampf(size.y/540.0,0.7,1.4)

func buttons() -> Dictionary:
	return {"FIRE":at(0.91,0.59),"AIM":at(0.79,0.48),"JUMP":at(0.92,0.80),"SLIDE":at(0.80,0.82),"LOAD":at(0.68,0.82),"RUN":at(0.24,0.58),"SIDE":at(0.66,0.49),"FPS":at(0.92,0.10),"RESET":at(0.77,0.10)}

func radius(name: String) -> float:
	return (42.0 if name == "FIRE" else 30.0)*unit()

func label_at(pos: Vector2, text: String, font_size: int, color: Color = WHITE) -> void:
	draw_string(ThemeDB.fallback_font,pos,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func centered(pos: Vector2, text: String, font_size: int, color: Color = WHITE) -> void:
	var width := ThemeDB.fallback_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	label_at(pos-Vector2(width*0.5,-font_size*0.32),text,font_size,color)

func _draw() -> void:
	if game == null:
		return
	var u := unit()
	var font := int(15*u)
	draw_rect(Rect2(at(0.025,0.025),Vector2(245,85)*u),DARK)
	label_at(at(0.025,0.025)+Vector2(12,22)*u,"LAST IMPACT / R02",int(19*u),ACCENT)
	label_at(at(0.025,0.025)+Vector2(12,44)*u,"FPS %d   ·   MEM %.0f MB" % [Engine.get_frames_per_second(),Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0],font)
	label_at(at(0.025,0.025)+Vector2(12,66)*u,"OBJETIVOS  %d / %d" % [game.eliminated,game.targets.size()],font)
	centered(at(0.5,0.07),game.message,int(17*u))
	var center := size*0.5
	var c := ACCENT if game.hit_left>0.0 else WHITE
	for v in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		draw_line(center+v*4*u,center+v*12*u,c,2*u,true)
	var joystick := move_center if move_id>=0 else at(0.14,0.80)
	draw_circle(joystick,58*u,Color(0.04,0.07,0.09,0.38))
	draw_arc(joystick,58*u,0,TAU,40,Color(1,1,1,0.55),2*u,true)
	draw_circle(joystick+knob,25*u,Color(0.88,0.92,0.93,0.58))
	var names := {"FIRE":"FUEGO","AIM":"MIRA","JUMP":"SALTO","SLIDE":"SLIDE","LOAD":"REC.","RUN":"CORRER","SIDE":"LADO","FPS":"CALIDAD","RESET":"RESET"}
	for name in buttons():
		var p: Vector2 = buttons()[name]
		var r := radius(name)
		var active: bool = (name == "FIRE" and game.fire) or (name == "AIM" and game.player.aiming) or (name == "RUN" and game.mobile_sprint)
		draw_circle(p,r,Color(0.70,0.29,0.11,0.68) if active else DARK)
		draw_arc(p,r,0,TAU,32,Color(1,1,1,0.68),1.5*u,true)
		centered(p,names[name],int(11*u))
	var ammo_pos := at(0.50,0.89)
	draw_rect(Rect2(ammo_pos-Vector2(85,20)*u,Vector2(170,48)*u),DARK)
	centered(ammo_pos, "%02d / %03d" % [game.ammo,game.reserve],int(24*u))
	centered(ammo_pos+Vector2(0,20)*u,"ENTRENAMIENTO",int(10*u),ACCENT)

func button_at(pos: Vector2) -> String:
	for name in buttons():
		if pos.distance_to(buttons()[name]) <= radius(name)+5*unit():
			return name
	return ""

func press_button(name: String, index: int) -> void:
	match name:
		"FIRE":
			if fire_id == -1:
				fire_id = index
				game.fire = true
		"RUN":
			game.mobile_sprint = not game.mobile_sprint
		"AIM": game.player.aiming = not game.player.aiming
		"SIDE": game.player.shoulder *= -1.0
		"JUMP": game.player.jump_requested = true
		"SLIDE": game.player.request_slide()
		"LOAD": game.start_reload()
		"RESET": game.reset_round()
		"FPS": game.next_profile()

func set_move(pos: Vector2) -> void:
	knob = (pos-move_center).limit_length(58*unit())
	var strength := knob.length()/(58*unit())
	game.mobile_move = knob.normalized()*clampf((strength-0.12)/0.88,0.0,1.0)

func clear_controls() -> void:
	move_id = -1
	look_id = -1
	fire_id = -1
	sprint_id = -1
	knob = Vector2.ZERO
	mouse_look = false
	mouse_fire = false
	if game != null:
		game.mobile_move = Vector2.ZERO
		game.mobile_sprint = false
		game.fire = false
		game.keys.clear()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		clear_controls()

func _input(event: InputEvent) -> void:
	if game == null:
		return
	if event is InputEventScreenTouch:
		var id := event.index
		if event.pressed:
			var name := button_at(event.position)
			if not name.is_empty():
				press_button(name,id)
			elif event.position.x < size.x*0.42 and event.position.y > size.y*0.45 and move_id < 0:
				move_id = id
				move_center = event.position
				set_move(event.position)
			elif look_id < 0:
				look_id = id
		else:
			if id == move_id:
				move_id = -1
				knob = Vector2.ZERO
				game.mobile_move = Vector2.ZERO
			if id == look_id:
				look_id = -1
			if id == fire_id:
				fire_id = -1
				game.fire = false
	elif event is InputEventScreenDrag:
		if event.index == move_id:
			set_move(event.position)
		elif event.index == look_id or event.index == fire_id:
			game.player.look_delta(event.relative/unit())
	elif event is InputEventKey:
		game.keys[event.physical_keycode] = event.pressed
		if event.pressed and not event.echo:
			match event.physical_keycode:
				KEY_SPACE: game.player.jump_requested = true
				KEY_C: game.player.request_slide()
				KEY_R: game.start_reload()
				KEY_Q: game.player.shoulder *= -1.0
				KEY_E: game.player.aiming = not game.player.aiming
				KEY_F1: game.next_profile()
				KEY_F2: game.reset_round()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var name := button_at(event.position)
				if name.is_empty():
					mouse_fire = true
					game.fire = true
				else:
					press_button(name,-2)
			else:
				mouse_fire = false
				fire_id = -1
				game.fire = false
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			mouse_look = event.pressed
	elif event is InputEventMouseMotion and (mouse_look or mouse_fire):
		game.player.look_delta(event.relative/unit())
