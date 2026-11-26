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
var stat_elapsed := 0.0
var cached_fps := 0
var cached_mem := 0.0
const WHITE := Color(0.95,0.97,0.97,0.96)
const DARK := Color(0.04,0.07,0.09,0.77)
const ACCENT := Color(0.96,0.57,0.24,1)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(true)

func _process(delta: float) -> void:
	stat_elapsed += delta
	if stat_elapsed>=0.5:
		stat_elapsed = 0.0
		cached_fps = Engine.get_frames_per_second()
		cached_mem = Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0
	queue_redraw()

func at(x: float,y: float) -> Vector2:
	return Vector2(size.x*x,size.y*y)

func unit() -> float:
	return clampf(size.y/540.0,0.7,1.4)

func buttons() -> Dictionary:
	var positions := {"FIRE":at(0.91,0.59),"AIM":at(0.79,0.48),"JUMP":at(0.92,0.80),"SLIDE":at(0.80,0.82),"LOAD":at(0.68,0.82),"RUN":at(0.10,0.49),"SIDE":at(0.66,0.49),"FPS":at(0.92,0.10),"RESET":at(0.77,0.10),"LOBBY":at(0.65,0.10)}
	if game!=null and game.survival_mode:
		positions["PICKUP"] = at(0.60,0.70)
		positions["MED"] = at(0.08,0.32)
		positions["SHIELD"] = at(0.19,0.32)
	return positions

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
	if game.survival_mode:
		draw_storm_exposure()
	var font := int(12*u)
	draw_minimap(u)
	draw_rect(Rect2(at(0.145,0.025),Vector2(180,62)*u),DARK)
	label_at(at(0.145,0.025)+Vector2(9,16)*u,"LAST IMPACT / R0751",int(14*u),ACCENT)
	label_at(at(0.145,0.025)+Vector2(9,33)*u,"FPS %d   ·   MEM %.0f MB" % [cached_fps,cached_mem],font)
	label_at(at(0.145,0.025)+Vector2(9,50)*u,"OBJETIVOS  %d / %d" % [game.eliminated,game.targets.size()],font)
	if game.survival_mode:
		draw_rect(Rect2(at(0.49,0.16)-Vector2(155,14)*u,Vector2(310,44)*u),Color(0.04,0.07,0.09,0.66))
	centered(at(0.49,0.16),game.message,int(15*u))
	if game.survival_mode:
		var zone_label := "ZONA %d m · %ds · %d/%d rivales" % [roundi(game.zone.radius),game.zone.seconds_remaining(),game.targets.size()-game.eliminated,game.targets.size()]
		if game.zone.outside(game.player.global_position):
			zone_label += " · TORMENTA: SAL DE AHI"
		elif game.zone.signed_distance(game.player.global_position)>-7.0:
			zone_label += " · FRENTE PROXIMO"
		centered(at(0.49,0.205),zone_label,int(12*u),Color("ffb26b") if game.zone.outside(game.player.global_position) else Color("5ecdf2"))
	var center := size*0.5
	var spread := 1.0 if game.player.aiming else 1.45
	var c := ACCENT if game.hit_left>0.0 else WHITE
	for v in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		draw_line(center+v*4*u*spread,center+v*12*u*spread,c,2*u,true)
	var joystick := move_center if move_id>=0 else at(0.14,0.80)
	draw_circle(joystick,58*u,Color(0.04,0.07,0.09,0.38))
	draw_arc(joystick,58*u,0,TAU,40,Color(1,1,1,0.55),2*u,true)
	draw_circle(joystick+knob,25*u,Color(0.88,0.92,0.93,0.58))
	var positions := buttons()
	var names := {"FIRE":"FUEGO","AIM":"MIRA","JUMP":"SALTO","SLIDE":"SLIDE","LOAD":"REC.","RUN":"CORRER","SIDE":"LADO","FPS":"CALIDAD","RESET":"RESET","LOBBY":"LOBBY","PICKUP":"RECOGER","MED":"CURAR","SHIELD":"ESCUDO"}
	if game.survival_mode:
		names["MED"] = "CURAR %d" % game.inventory.medkits
		names["SHIELD"] = "ESCUDO %d" % game.inventory.shield_cells
		var pickup = game.nearest_pickup()
		if pickup!=null:
			var supply_name := {"MED":"BOTIQUIN","SHIELD":"ESCUDO","AMMO":"ENERGIA"}
			centered(at(0.60,0.62),str(supply_name.get(pickup.kind,pickup.kind)),int(12*u),pickup.item_color())
	for name in positions:
		var p: Vector2 = positions[name]
		var r := radius(name)
		var active: bool = (name == "FIRE" and game.fire) or (name == "AIM" and game.player.aiming) or (name == "RUN" and game.mobile_sprint)
		var fill := Color(0.70,0.29,0.11,0.68) if active else DARK
		if game.survival_mode:
			if (name=="MED" and game.inventory.medkits==0) or (name=="SHIELD" and game.inventory.shield_cells==0) or (name=="PICKUP" and game.nearest_pickup()==null):
				fill.a = 0.35
		draw_circle(p,r,fill)
		draw_arc(p,r,0,TAU,32,Color(1,1,1,0.68),1.5*u,true)
		draw_button_icon(name,p,u)
		centered(p+Vector2(0,13*u),names[name],int(9*u))
	var ammo_pos := ammo_anchor()
	draw_rect(Rect2(ammo_pos-Vector2(70,17)*u,Vector2(140,39)*u),DARK)
	centered(ammo_pos, "%02d / %03d" % [game.ammo,game.reserve],int(20*u))
	centered(ammo_pos+Vector2(0,14)*u,"IGNIS X1",int(10*u),ACCENT)
	if game.reload_left>0.0:
		var progress := 1.0-clampf(float(game.reload_left)/1.4,0.0,1.0)
		var track := Rect2(ammo_pos+Vector2(-72,-27)*u,Vector2(144,4)*u)
		draw_rect(track,DARK)
		draw_rect(Rect2(track.position,Vector2(track.size.x*progress,track.size.y)),ACCENT)
	var bar := health_rect()
	draw_rect(bar,DARK)
	draw_rect(Rect2(bar.position-Vector2(5,18)*u,Vector2(160,29)*u),Color(0.04,0.07,0.09,0.45))
	draw_rect(Rect2(bar.position,Vector2(bar.size.x*clampf(float(game.health)/100.0,0.0,1.0),bar.size.y)),Color("68d9a4"))
	centered(bar.get_center()+Vector2(0,-9*u),"VIDA %d / ESCUDO %d" % [game.health,game.armor],int(10*u))

func button_at(pos: Vector2) -> String:
	var positions := buttons()
	var best := ""
	var nearest := INF
	for name in positions:
		var distance := pos.distance_to(positions[name])
		if distance <= radius(name)+5*unit() and distance < nearest:
			best = name
			nearest = distance
	return best

func press_button(name: String, index: int) -> void:
	if game.round_result!="" and name not in ["RESET","LOBBY","FPS"]:
		return
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
		"PICKUP": game.collect_nearby()
		"MED": game.use_medkit()
		"SHIELD": game.use_shield_cell()
		"RESET": game.reset_round()
		"FPS": game.next_profile()
		"LOBBY": get_tree().change_scene_to_file("res://lobby.tscn")

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
		if is_instance_valid(game.player):
			game.player.aiming = false
			game.player.combat_facing = false
			game.player.jump_requested = false
			game.player.jump_buffer = 0.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		clear_controls()

func _input(event: InputEvent) -> void:
	if game == null:
		return
	if game.round_result!="":
		if event is InputEventScreenTouch and event.pressed and not event.canceled:
			press_button(button_at(event.position),event.index)
		elif event is InputEventMouseButton and event.pressed and not OS.has_feature("android"):
			press_button(button_at(event.position),-2)
		elif event is InputEventKey and event.pressed and not event.echo:
			if event.physical_keycode==KEY_F2:
				game.reset_round()
			elif event.physical_keycode==KEY_ESCAPE:
				get_tree().change_scene_to_file("res://lobby.tscn")
		return
	if event is InputEventScreenTouch:
		var id: int = event.index
		if event.pressed and not event.canceled:
			if id == move_id or id == look_id or id == fire_id:
				return
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
				if event.canceled:
					game.mobile_sprint = false
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
				KEY_F: game.collect_nearby()
				KEY_H: game.use_medkit()
				KEY_G: game.use_shield_cell()
				KEY_Q: game.player.shoulder *= -1.0
				KEY_E: game.player.aiming = not game.player.aiming
				KEY_F1: game.next_profile()
				KEY_F2: game.reset_round()
				KEY_ESCAPE: get_tree().change_scene_to_file("res://lobby.tscn")
	elif event is InputEventMouseButton:
		if OS.has_feature("android"):
			return
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

func draw_minimap(u: float) -> void:
	var area := Rect2(at(0.025,0.025),Vector2(95,95)*u)
	draw_rect(area,DARK)
	draw_rect(area,Color("607987"),false,1.0)
	for fraction in [0.25,0.5,0.75]:
		var d: float = area.size.x*fraction
		draw_line(area.position+Vector2(d,0),area.position+Vector2(d,area.size.y),Color(0.5,0.65,0.72,0.18),1.0)
		draw_line(area.position+Vector2(0,d),area.position+Vector2(area.size.x,d),Color(0.5,0.65,0.72,0.18),1.0)
	var middle := area.get_center()
	var k := 95.0*u/(128.0 if game.survival_mode else 80.0)
	if game.survival_mode:
		for sector in game.frontier.sectors:
			var bounds: Rect2 = sector["rect"]
			var color: Color = sector["color"]
			color.a = 0.5
			draw_rect(Rect2(middle+bounds.position*k,bounds.size*k),color)
		for bounds in game.frontier.buildings:
			draw_rect(Rect2(middle+bounds.position*k,bounds.size*k),Color("8aa5ad"),false,1.0)
		centered(area.get_center()+Vector2(0,-area.size.y*0.5+8*u),"N",int(10*u))
		centered(area.get_center()+Vector2(0,area.size.y*0.5+9*u),game.frontier.sector_name(game.player.global_position),int(10*u))
	if game.survival_mode:
		draw_arc(middle,float(game.zone.radius)*k,0,TAU,48,Color("5ecdf2"),1.5*u,true)
	if game.survival_mode:
		for pickup in game.pickups:
			if pickup.active:
				draw_rect(Rect2(middle+Vector2(pickup.position.x,pickup.position.z)*k-Vector2.ONE*2*u,Vector2.ONE*4*u),pickup.item_color())
	for target in game.targets:
		if target.active:
			draw_circle(middle+Vector2(target.position.x,target.position.z)*k,3.0*u,ACCENT)
	var pos: Vector3 = game.player.position
	var dot := middle+Vector2(pos.x,pos.z)*k
	draw_circle(dot,4.0*u,WHITE)
	draw_line(dot,dot+Vector2(-sin(game.player.yaw),-cos(game.player.yaw))*10*u,WHITE,2.0,true)

func draw_button_icon(name: String,p: Vector2,u: float) -> void:
	var q := p-Vector2(0,7*u)
	var s := 9.0*u
	match name:
		"FIRE","AIM":
			draw_arc(q,s,0,TAU,16,WHITE,1.5*u,true)
			draw_line(q-Vector2(s+3*u,0),q+Vector2(s+3*u,0),WHITE,1.2*u,true)
			draw_line(q-Vector2(0,s+3*u),q+Vector2(0,s+3*u),WHITE,1.2*u,true)
		"JUMP","RUN":
			draw_polyline(PackedVector2Array([q+Vector2(-s,3*u),q+Vector2(0,-s),q+Vector2(s,3*u)]),WHITE,2*u,true)
		"MED":
			draw_line(q-Vector2(s,0),q+Vector2(s,0),Color("68d9a4"),3*u,true)
			draw_line(q-Vector2(0,s),q+Vector2(0,s),Color("68d9a4"),3*u,true)
		"SHIELD":
			draw_polyline(PackedVector2Array([q+Vector2(-s,-s),q+Vector2(s,-s),q+Vector2(s,0),q+Vector2(0,s),q+Vector2(-s,0),q+Vector2(-s,-s)]),Color("63bde8"),2*u,true)
		"PICKUP":
			draw_rect(Rect2(q-Vector2(s,s)*0.7,Vector2(s,s)*1.4),ACCENT,false,2*u)
			draw_line(q-Vector2(s*0.7,0),q+Vector2(s*0.7,0),ACCENT,1.5*u)
		"SLIDE":
			draw_line(q-Vector2(s,0),q+Vector2(s,0),WHITE,2*u,true)
			draw_line(q+Vector2(-s,5*u),q+Vector2(s,5*u),WHITE,2*u,true)
		"LOAD","RESET":
			draw_arc(q,s,0.25,TAU-0.6,20,WHITE,2*u,true)
			draw_line(q+Vector2(s,-s*0.65),q+Vector2(s,0),WHITE,2*u,true)
		_:
			draw_rect(Rect2(q-Vector2(s,s)*0.65,Vector2(s,s)*1.3),WHITE,false,1.5*u)

func ammo_anchor() -> Vector2:
	return at(0.83,0.94)

func health_rect() -> Rect2:
	var u := unit()
	return Rect2(at(0.145,0.025)+Vector2(9,83)*u,Vector2(150,6)*u)

func draw_storm_exposure() -> void:
	var intensity: float = game.storm_exposure
	if intensity<0.005:
		return
	# Cheap translucent dust tint and graduated edges behind the HUD.
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.53,0.34,0.18,intensity*0.19))
	for i in range(5):
		var width := float(5-i)*size.y*0.018
		var c := Color(0.29,0.17,0.09,intensity*0.065)
		draw_rect(Rect2(0,0,size.x,width),c)
		draw_rect(Rect2(0,size.y-width,size.x,width),c)
		draw_rect(Rect2(0,width,width,size.y-width*2.0),c)
		draw_rect(Rect2(size.x-width,width,width,size.y-width*2.0),c)
