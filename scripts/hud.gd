extends Control
var game
var move_id := -1
var look_id := -1
var fire_id := -1
var sprint_id := -1
var move_center := Vector2.ZERO
var qa_move_start := Vector3.ZERO
var qa_look_start := 0.0
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
	if game!=null and game.deployment_active():
		return {"JUMP":at(0.92,0.80),"RESET":at(0.77,0.10),"LOBBY":at(0.65,0.10)}
	var positions := {"FIRE":at(0.91,0.59),"AIM":at(0.79,0.48),"JUMP":at(0.92,0.80),"SLIDE":at(0.80,0.82),"LOAD":at(0.68,0.82),"RUN":at(0.10,0.49),"CROUCH":at(0.29,0.49),"SIDE":at(0.66,0.49),"FPS":at(0.92,0.10),"RESET":at(0.77,0.10),"LOBBY":at(0.65,0.10)}
	if game!=null and game.survival_mode:
		positions["PICKUP"] = at(0.60,0.70)
		positions["MED"] = at(0.08,0.32)
		positions["SHIELD"] = at(0.19,0.32)
		if game.experimental_deployment:
			positions["SWAP"] = at(0.55,0.87)
			positions["MELEE"] = at(0.40,0.82)
			positions["GRENADE"] = at(0.40,0.63)
			positions["ABILITY"] = at(0.40,0.43)
			if is_instance_valid(game.supplies) and game.supplies.near_shop():
				positions["BUY"] = at(0.32,0.24)
				positions["MAG"] = at(0.45,0.24)
				positions["FAST"] = at(0.58,0.24)
				positions["HOLO"] = at(0.71,0.24)
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
	if game.deployment_active():
		# Restrained peripheral streaks: cheap 2D lines, no full-screen blur.
		var strength: float = game.deployment.speed_effect
		if strength>0.08:
			var center := size*0.5
			var count := 8 if game.profile==0 else 14
			for i in range(count):
				var a := TAU*float(i)/float(count)+0.11
				var direction := Vector2(cos(a),sin(a))
				var extent := Vector2(size.x*0.46,size.y*0.46)
				var p := center+direction*extent*(0.78+0.19*fposmod(game.deployment.flight.elapsed*1.7+i*0.37,1.0))
				draw_line(p,p+direction*(18.0+25.0*strength)*u,Color(0.74,0.89,1.0,0.20*strength),1.0,true)
		draw_minimap(u)
		centered(at(0.49,0.12),game.deployment.status_text(),int(18*u),ACCENT)
		centered(at(0.49,0.19),"ALT %.0f m  ·  %.0f km/h" % [maxf(0.0,game.player.position.y-game.deployment.flight.ground_y),game.deployment.flight.velocity.length()*3.6],int(14*u))
		var joystick := move_center if move_id>=0 else at(0.14,0.80)
		draw_circle(joystick,58*u,DARK)
		draw_circle(joystick+knob,25*u,WHITE)
		var air_buttons := buttons()
		for name in air_buttons:
			var p: Vector2 = air_buttons[name]
			draw_circle(p,radius(name),DARK)
			var label := "SALIR / ALAS" if name=="JUMP" else str(name)
			centered(p,label,int(10*u))
		return
	if game.survival_mode:
		draw_storm_exposure()
	var font := int(12*u)
	draw_minimap(u)
	draw_rect(Rect2(at(0.145,0.025),Vector2(190,78)*u),DARK)
	label_at(at(0.145,0.025)+Vector2(9,16)*u,"LAST IMPACT / R0792",int(14*u),ACCENT)
	label_at(at(0.145,0.025)+Vector2(9,33)*u,"FPS %d · MEM EST %.0f MB" % [cached_fps,cached_mem],font)
	label_at(at(0.145,0.025)+Vector2(9,50)*u,"OBJETIVOS  %d / %d" % [game.eliminated,game.targets.size()],font)
	if game.survival_mode and not game.telemetry.latest.is_empty():
		var stats: Dictionary = game.telemetry.latest
		label_at(at(0.145,0.025)+Vector2(9,67)*u,"P95 %.0f ms · 1%% LOW %.0f" % [stats["p95_ms"],stats["one_percent_low_fps"]],font)
	if not game.message.is_empty():
		draw_rect(Rect2(at(0.49,0.16)-Vector2(155,14)*u,Vector2(310,28)*u),Color(0.04,0.07,0.09,0.66))
		centered(at(0.49,0.16),game.message,int(15*u))
	if game.survival_mode:
		var zone_label := "ZONA %d m · %ds · %d/%d rivales" % [roundi(game.zone.radius),game.zone.seconds_remaining(),game.targets.size()-game.eliminated,game.targets.size()]
		if game.zone.outside(game.player.global_position):
			zone_label += " · ¡SAL DE LA TORMENTA!"
		elif game.zone.signed_distance(game.player.global_position)>-7.0:
			zone_label += " · BORDE CERCA"
		centered(at(0.49,0.205),zone_label,int(11*u),Color("ffb26b") if game.zone.outside(game.player.global_position) else Color("5ecdf2"))
	var center := size*0.5
	var spread := 1.0 if game.player.aiming else 1.45
	var c := ACCENT if game.hit_left>0.0 else WHITE
	for v in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		draw_line(center+v*4*u*spread,center+v*12*u*spread,c,2*u,true)
	if is_instance_valid(game.supplies) and game.player.aiming and game.supplies.has_upgrade(game.weapon_id,"HOLO"):
		draw_arc(center,21*u,0,TAU,32,Color("58f0dc"),1.5*u,true)
		draw_circle(center,2*u,Color("58f0dc"))
	var joystick := move_center if move_id>=0 else at(0.14,0.80)
	draw_circle(joystick,58*u,Color(0.04,0.07,0.09,0.38))
	draw_arc(joystick,58*u,0,TAU,40,Color(1,1,1,0.55),2*u,true)
	draw_circle(joystick+knob,25*u,Color(0.88,0.92,0.93,0.58))
	var positions := buttons()
	var names := {"FIRE":"FUEGO","AIM":"MIRA","JUMP":"SALTO","SLIDE":"SLIDE","LOAD":"REC.","RUN":"CORRER","CROUCH":"AGACHAR","SIDE":"LADO","FPS":"CALIDAD","RESET":"RESET","LOBBY":"LOBBY","PICKUP":"RECOGER","MED":"CURAR","SHIELD":"ESCUDO","SWAP":"ARMA","MELEE":"HOJA","GRENADE":"PULSO","BUY":"ARMA 200","MAG":"MAG 100","FAST":"REC 125","HOLO":"MIRA 75","ABILITY":"HABILIDAD"}
	if game.survival_mode:
		if is_instance_valid(game.supplies):
			names["GRENADE"] = "PULSO %d" % game.supplies.grenades
			if game.supplies.near_shop(): names["BUY"] = "%s %d" % [game.supplies.next_store_weapon(),game.supplies.store_price()]
			centered(at(0.49,0.15),"CREDITOS %d | ARMAS %d/2" % [game.supplies.credits,game.owned_weapons.size()],int(11*u),ACCENT)
		names["MED"] = "CURAR %d" % game.inventory.medkits
		names["SHIELD"] = "ESCUDO %d" % game.inventory.shield_cells
		var pickup = game.nearest_pickup()
		if pickup!=null:
			centered(at(0.60,0.62),game.pickup_label(pickup.kind),int(12*u),pickup.item_color())
	if is_instance_valid(game.ability):
		var ability = game.ability
		names["ABILITY"] = "%ds" % ceili(ability.cooldown_left) if ability.cooldown_left>0.0 else "HABILIDAD"
		label_at(at(0.145,0.025)+Vector2(9,83)*u,ability.class_id+" / "+str(ability.spec().skill),int(10*u),Color(str(ability.spec().color)))
		if ability.active_left>0.0:
			draw_arc(center,32*u,0,TAU*ability.active_left/maxf(0.01,float(ability.spec().duration)),32,Color(str(ability.spec().color)),2*u,true)
	for name in positions:
		var p: Vector2 = positions[name]
		var r := radius(name)
		var active: bool = (name == "FIRE" and game.fire) or (name == "AIM" and game.player.aiming) or (name == "RUN" and game.mobile_sprint) or (name == "CROUCH" and game.player.crouch_requested)
		var fill := Color(0.70,0.29,0.11,0.68) if active else DARK
		if name=="ABILITY" and is_instance_valid(game.ability) and game.ability.cooldown_left>0.0: fill.a = 0.35
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
	var weapon_text: String = game.weapon_name()
	if is_instance_valid(game.supplies):
		if game.supplies.has_upgrade(game.weapon_id,"MAG"): weapon_text += " +M"
		if game.supplies.has_upgrade(game.weapon_id,"RELOAD"): weapon_text += " +R"
		if game.supplies.has_upgrade(game.weapon_id,"HOLO"): weapon_text += " +H"
	centered(ammo_pos+Vector2(0,14)*u,weapon_text,int(10*u),ACCENT)
	if game.reload_left>0.0:
		var progress := 1.0-clampf(float(game.reload_left)/game.reload_duration(),0.0,1.0)
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
	if game.deployment_active() and name not in ["JUMP","RESET","LOBBY"]:
		return
	if game.round_result!="" and name not in ["RESET","LOBBY","FPS"]:
		return
	match name:
		"FIRE":
			if fire_id == -1:
				fire_id = index
				game.fire = true
		"RUN":
			game.mobile_sprint = not game.mobile_sprint
		"CROUCH": game.player.toggle_crouch()
		"AIM":
			game.player.aiming = not game.player.aiming
			game.qa_control("AIM_ON" if game.player.aiming else "AIM_OFF")
		"SIDE":
			game.player.shoulder *= -1.0
			game.qa_control("SHOULDER")
		"JUMP": game.request_jump()
		"SLIDE": game.player.request_slide()
		"LOAD": game.start_reload()
		"SWAP": game.cycle_weapon()
		"MELEE": game.supplies.melee()
		"GRENADE": game.supplies.throw_grenade()
		"BUY": game.supplies.buy_weapon()
		"MAG": game.supplies.buy_upgrade("MAG")
		"FAST": game.supplies.buy_upgrade("RELOAD")
		"HOLO": game.supplies.buy_upgrade("HOLO")
		"ABILITY":
			if is_instance_valid(game.ability): game.ability.activate()
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
				qa_move_start = game.player.global_position
				set_move(event.position)
			elif look_id < 0:
				look_id = id
				qa_look_start = game.player.yaw
		else:
			if id == move_id:
				move_id = -1
				knob = Vector2.ZERO
				game.mobile_move = Vector2.ZERO
				if not event.canceled and game.player.global_position.distance_to(qa_move_start)>0.15:
					game.qa_control("MOVE_RELEASE")
				if event.canceled:
					game.mobile_sprint = false
			if id == look_id:
				look_id = -1
				if not event.canceled and absf(wrapf(game.player.yaw-qa_look_start,-PI,PI))>0.02:
					game.qa_control("LOOK_RELEASE")
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
			if game.deployment_active() and event.physical_keycode not in [KEY_SPACE,KEY_F2,KEY_ESCAPE]:
				return
			match event.physical_keycode:
				KEY_SPACE: game.request_jump()
				KEY_C: game.player.request_slide()
				KEY_X: game.player.toggle_crouch()
				KEY_R: game.start_reload()
				KEY_TAB: game.cycle_weapon()
				KEY_Q:
					if is_instance_valid(game.ability): game.ability.activate()
				KEY_V:
					if is_instance_valid(game.supplies): game.supplies.melee()
				KEY_B:
					if is_instance_valid(game.supplies): game.supplies.throw_grenade()
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
	if is_instance_valid(game.supplies):
		var shop: Vector3 = game.supplies.station.global_position
		draw_rect(Rect2(middle+Vector2(shop.x,shop.z)*k-Vector2.ONE*3*u,Vector2.ONE*6*u),Color("45dfb3"))
		if game.supplies.drop_state==1:
			var drop: Vector3 = game.supplies.drop_site
			draw_arc(middle+Vector2(drop.x,drop.z)*k,5*u,0,TAU,16,Color("f5db65"),2*u,true)
	for target in game.targets:
		if target.active and target.visible:
			var airborne: bool = is_instance_valid(game.rival_deployment) and game.rival_deployment.airborne(target)
			if not airborne and not game.deployment_active() and is_instance_valid(game.ability) and not game.ability.reveals(game.player.global_position.distance_to(target.global_position)): continue
			var marker := middle+Vector2(target.position.x,target.position.z)*k
			if airborne:
				draw_arc(marker,4.0*u,0,TAU,12,Color("75c9ff"),1.5*u,true)
			else:
				draw_circle(marker,3.0*u,ACCENT)
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
		"CROUCH":
			draw_polyline(PackedVector2Array([q+Vector2(-s,-3*u),q+Vector2(0,s),q+Vector2(s,-3*u)]),WHITE,2*u,true)
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
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.53,0.34,0.18,intensity*0.035))
	for i in range(5):
		var width := float(5-i)*size.y*0.018
		var c := Color(0.29,0.17,0.09,intensity*0.025)
		draw_rect(Rect2(0,0,size.x,width),c)
		draw_rect(Rect2(0,size.y-width,size.x,width),c)
		draw_rect(Rect2(0,width,width,size.y-width*2.0),c)
		draw_rect(Rect2(size.x-width,width,width,size.y-width*2.0),c)

	# Sparse, wind-driven sand streaks. Deterministic, no particle nodes or allocations per grain.
	var count: int = [12,20,32][game.profile]
	var t: float = game.zone.wind_clock
	for i in range(count):
		var seed := float(i)*0.61803399
		var drift := fposmod(seed+ t*(0.16+0.028*float(i%5)),1.0)
		var y := fposmod(seed*1.731+sin(t*0.37+float(i))*0.035,1.0)
		var p := Vector2(drift*size.x,y*size.y)
		var span := (6.0+float(i%4)*5.0)*unit()
		var alpha := intensity*0.17*sin(drift*PI)
		draw_line(p,p+Vector2(span,-span*0.14),Color(0.87,0.68,0.44,alpha),maxf(1.0,unit()),true)
