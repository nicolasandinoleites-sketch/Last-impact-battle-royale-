extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func check(ok: bool, label: String) -> bool:
	if not ok:
		push_error("TEST FAILED: " + label)
		quit(1)
		return false
	print("PASS: " + label)
	return true

func run() -> void:
	var lobby = load("res://lobby.tscn").instantiate()
	root.add_child(lobby)
	await frames(5)
	if not check(lobby.mode == "home" and lobby.size.x > 0, "lobby startup"):
		return
	lobby.activate(lobby.rect(24,276,248,54).get_center())
	if not check(lobby.mode=="loadout", "functional armament menu"):
		return
	lobby.mode = "settings"
	lobby.choose_profile(0)
	if not check(lobby.quality == 0, "safe graphics settings"):
		return
	root.remove_child(lobby)
	lobby.free()
	var diagnostic = load("res://diagnostic.tscn").instantiate()
	root.add_child(diagnostic)
	await frames(5)
	if not check(is_instance_valid(diagnostic.cube) and root.get_camera_3d() != null, "diagnostic scene"):
		return
	root.remove_child(diagnostic)
	diagnostic.free()
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await frames(30)
	if not check(scene.targets.size() == 6 and scene.player.is_on_floor(), "spawn and targets"):
		return
	if not check(scene.player.model_loaded and scene.player.raze.skeleton.get_bone_count() >= 70, "RAZE imported rig"):
		return
	if not check(scene.player.raze.animator != null and scene.player.raze.animator.get_animation_list().size() > 0, "RAZE animation library"):
		return
	if not check(scene.player.weapon_loaded and is_instance_valid(scene.player.weapon.model), "IGNIS GLB imported and equipped"):
		return
	scene.player.weapon.pulse()
	if not check(scene.player.weapon.flash.visible and scene.player.weapon.pulse_count==1, "IGNIS cosmetic flash"):
		return
	scene.player.weapon.clear_effects()
	if not check(not scene.player.weapon.flash.visible, "IGNIS effect reset"):
		return
	var weapon = scene.player.weapon
	if not check(is_instance_valid(weapon.energy_cell) and weapon.cell_stage=="DOCKED", "separate fictional energy module"):
		return
	weapon.update_reload_cell(0.60)
	if not check(weapon.cell_stage=="EXCHANGE" and weapon.energy_cell.position.distance_to(weapon.cell_dock)>0.04, "reload module travels"):
		return
	weapon.update_reload_cell(0.30)
	if not check(weapon.cell_stage=="INSERT", "reload module return phase"):
		return
	weapon.sprint_pose = 0.8
	weapon.clear_effects()
	if not check(weapon.sprint_pose==0.0 and weapon.aim_pitch==0.0, "weapon visual reset"):
		return
	if not check(weapon.cell_stage=="DOCKED" and weapon.energy_cell.position.is_equal_approx(weapon.cell_dock), "reload module reset"):
		return
	var art_script = load("res://scripts/arena_art.gd")
	var floor_tex: ImageTexture = art_script.floor_texture()
	var panel_tex: ImageTexture = art_script.panel_texture()
	if not check(floor_tex.get_width()==256 and panel_tex.get_width()==256 and floor_tex==art_script.floor_texture() and panel_tex==art_script.panel_texture(), "shared detailed arena textures"):
		return
	if not check(scene.arena_art.batch_count==4 and scene.arena_art.decoration_count>80, "batched arena decoration"):
		return
	var old_yaw: float = scene.player.yaw
	scene.player.visual.rotation.y = 0.8
	scene.player.sprint = false
	scene.player.update_facing(Vector3.RIGHT,1.0)
	if not check(absf(angle_difference(scene.player.visual.rotation.y,old_yaw))<0.01, "strafe keeps camera orientation"):
		return
	scene.player.visual.rotation.y = old_yaw
	var button_positions: Dictionary = scene.hud.buttons()
	for button_name in button_positions:
		if not check(scene.hud.button_at(button_positions[button_name])==button_name, "touch button center "+str(button_name)):
			return
	var h: Rect2 = scene.hud.health_rect()
	if not check(h.position.y < scene.hud.size.y*0.30 and h.end.x<scene.hud.size.x*0.45, "health outside avatar region"):
		return
	var touch := InputEventScreenTouch.new()
	touch.index = 2
	touch.pressed = true
	touch.position = scene.hud.at(0.14,0.80)
	scene.hud._input(touch)
	var drag := InputEventScreenDrag.new()
	drag.index = 2
	drag.position = touch.position+Vector2(25,0)
	scene.hud._input(drag)
	if not check(scene.mobile_move.x>0.05, "touch joystick drag"):
		return
	var aim_touch := InputEventScreenTouch.new()
	aim_touch.index = 3
	aim_touch.pressed = true
	aim_touch.position = scene.hud.buttons()["AIM"]
	scene.hud._input(aim_touch)
	if not check(scene.player.aiming and scene.mobile_move.x>0.05, "multitouch movement plus aim"):
		return
	touch.pressed = false
	scene.hud._input(touch)
	if not check(scene.mobile_move==Vector2.ZERO, "touch release clears movement"):
		return
	# A cancelled finger must release its action even if the event was marked pressed.
	var fire_touch := InputEventScreenTouch.new()
	fire_touch.index = 4
	fire_touch.pressed = true
	fire_touch.position = scene.hud.buttons()["FIRE"]
	scene.hud._input(fire_touch)
	if not check(scene.fire and scene.hud.fire_id==4, "fire touch ownership"):
		return
	fire_touch.canceled = true
	scene.hud._input(fire_touch)
	if not check(not scene.fire and scene.hud.fire_id==-1, "cancelled fire touch releases action"):
		return
	scene.player.aiming = true
	scene.player.jump_requested = true
	scene.player.jump_buffer = 0.1
	scene.mobile_sprint = true
	scene.hud._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	if not check(not scene.player.aiming and not scene.player.jump_requested and scene.player.jump_buffer==0.0 and not scene.mobile_sprint, "pause clears transient inputs"):
		return
	var actor = scene.player.raze
	scene.player.weapon.update_pose(0.1,true,0.0)
	if not check(is_instance_valid(scene.player.weapon.right_goal) and is_instance_valid(scene.player.weapon.left_goal), "dual wrist targets"):
		return
	var right_error: float = actor.solve_arm("R",scene.player.weapon.right_goal.global_position,Vector3(1,-1,0))
	var left_error: float = actor.solve_arm("L",scene.player.weapon.left_goal.global_position,Vector3(-1,-1,0))
	if not check(is_finite(right_error) and is_finite(left_error) and right_error<0.18 and left_error<0.18, "two arm IK bounded error"):
		return
	if not check(actor.finger_axes.size()>=18, "finger articulation map"):
		return
	if not check(scene.game_audio.fire_player.stream != null and scene.game_audio.reload_player.stream != null, "synthetic game audio"):
		return
	if not check(actor.joints.size()==14 and actor.right_socket.bone_name=="R_Hand" and actor.left_socket.bone_name=="L_Hand", "locomotion joint map and sockets"):
		return
	if not check(actor.foot_ids.size()==2 and is_finite(actor.foot_rest_height), "calibrated toe contact markers"):
		return
	if not check(is_instance_valid(scene.player.contact_shadow), "lightweight contact shadow"):
		return
	if not check(actor.ankle_rest.size()==2, "ankle calibration"):
		return
	var rest_l: Vector3 = actor.ankle_rest["L"]
	var support: Vector3 = actor.gait_goal("L",0.2,Vector3.FORWARD,0.2,false)
	var swing: Vector3 = actor.gait_goal("L",0.8,Vector3.FORWARD,0.2,false)
	if not check(is_equal_approx(support.y,rest_l.y) and swing.y>rest_l.y+0.04, "stance and swing foot trajectory"):
		return
	for direction in [Vector2(0,-1),Vector2(1,0),Vector2(0,1),Vector2(-1,0)]:
		actor.locomotion(0.016,2.8,true,false,true,false,0.0,direction*2.8)
		if not check(actor.foot_ik_active and is_finite(actor.foot_ik_error) and actor.foot_ik_error<0.35, "directional leg IK "+str(direction)):
			return
	if not check(actor.ankle_basis.size()==2, "calibrated ankle orientations"):
		return
	var test_cadence: float = actor.gait_cadence(1.5,false)
	var test_step: float = actor.gait_half_step(1.5,test_cadence,false)
	if not check(absf(2.0*test_step*test_cadence/0.62-1.5)<0.001, "stance travel matches nominal speed"):
		return
	var max_ik := 0.0
	for i in range(8):
		var dir := Vector2.from_angle(float(i)*TAU/8.0)*2.8
		for tick in range(24):
			actor.locomotion(1.0/60.0,2.8,true,false,true,false,0.0,dir)
			max_ik = maxf(max_ik,actor.foot_ik_error)
	if not check(is_finite(max_ik) and max_ik<0.35, "sustained eight-direction IK"):
		return
	print("MAX EIGHT DIRECTION IK ",max_ik)
	actor.gait_heading = Vector3.FORWARD
	actor.gait_weight = 1.0
	actor.update_gait_heading(Vector3.BACK,1.0/60.0)
	if not check(actor.gait_heading.dot(Vector3.BACK)>0.99 and actor.gait_weight==0.0, "reverse direction restarts IK blend"):
		return
	actor.reset_locomotion()
	if not check(actor.motion_state=="IDLE" and actor.cycle==0.0 and actor.gait_weight==0.0 and not actor.foot_ik_active and actor.model.position.is_equal_approx(Vector3.ZERO), "reset clears procedural pose"):
		return
	var leg_id: int = actor.skeleton.find_bone("L_Thigh")
	var initial: Quaternion = actor.skeleton.get_bone_pose_rotation(leg_id)
	for i in range(12):
		actor.locomotion(1.0/60.0,3.8,true,false,false)
	if not check(actor.motion_state=="WALK" and absf(actor.skeleton.get_bone_pose_rotation(leg_id).dot(initial))<0.99999, "walk changes actual bone pose"):
		return
	actor.locomotion(0.1,6.2,true,false,false,true)
	if not check(actor.motion_state=="SPRINT", "sprint animation state"):
		return
	actor.locomotion(0.1,3.0,false,false,false,false,4.0)
	if not check(actor.motion_state=="JUMP", "jump animation state"):
		return
	actor.locomotion(0.1,3.0,false,false,false,false,-4.0)
	if not check(actor.motion_state=="FALL", "fall animation state"):
		return
	actor.locomotion(0.016,3.0,true,false,false)
	if not check(actor.motion_state=="LAND", "landing animation state"):
		return
	actor.locomotion(0.1,5.0,true,true,false)
	for i in range(15):
		actor.locomotion(1.0/60.0,5.0,true,true,false)
	if not check(actor.visual_ground_error<0.12 and actor.model.position.y< -0.15, "slide lowered with bounded toe height"):
		return
	if not check(actor.motion_state=="SLIDE", "slide animation state"):
		return
	actor.locomotion(0.3,0.0,true,false,true)
	if not check(actor.motion_state=="AIM", "aim animation state"):
		return
	if not check(actor.dance() and actor.preview_dance, "original dance plays"):
		return
	if not check(actor.dance() and not actor.preview_dance, "dance returns to rest"):
		return
	var initial_pitch: float = scene.player.pitch
	scene.player.view_recoil = 0.05
	scene.player.update_camera(0.2)
	if not check(is_equal_approx(scene.player.pitch,initial_pitch) and scene.player.view_recoil<0.001, "camera recoil returns without aim drift"):
		return
	scene.player.aiming = false
	scene.player.update_camera(1.0)
	if not check(is_equal_approx(scene.player.camera.fov,60.0) and is_equal_approx(scene.player.boom.spring_length,2.85), "normal TPS framing"):
		return
	scene.player.aiming = true
	scene.player.update_camera(1.0)
	if not check(is_equal_approx(scene.player.camera.fov,52.0) and is_equal_approx(scene.player.boom.spring_length,2.40), "aim TPS framing"):
		return
	scene.player.aiming = false
	var origin: Vector3 = scene.player.position
	scene.mobile_move = Vector2(0,-1)
	await frames(20)
	if not check(scene.player.position.distance_to(origin)>0.5 and scene.player.animation_speed>0.18, "movement drives animation from actual displacement"):
		return
	scene.player.request_slide()
	await frames(4)
	if not check(scene.player.low_stance and scene.player.capsule.height < 1.2, "slide collision"):
		return
	scene.mobile_move = Vector2.ZERO
	await frames(75)
	if not check(not scene.player.low_stance, "stand after slide"):
		return
	scene.player.jump_requested = true
	await frames(10)
	if not check(scene.player.position.y>0.3, "jump"):
		return
	scene.ammo = 12
	scene.reserve = 50
	scene.start_reload()
	await frames(100)
	if not check(scene.ammo==30 and scene.reserve==32, "reload"):
		return
	scene.next_profile()
	if not check(Engine.max_fps==45 and is_equal_approx(root.scaling_3d_scale,0.82), "graphics profile"):
		return
	scene.targets[0].take_hit(100)
	if not check(scene.eliminated==1, "target eliminated"):
		return
	scene.reset_round()
	if not check(scene.eliminated==0 and scene.ammo==30 and scene.targets[0].active and scene.player.raze.motion_state=="IDLE" and absf(scene.player.visual.rotation.y)<0.001, "reset"):
		return
	# Walk into the arena boundary, then verify actual locomotion speed settles.
	scene.player.position = Vector3(38.9,0.1,0)
	scene.player.reset_movement()
	scene.player.yaw = 0.0
	scene.mobile_move = Vector2(1,0)
	await frames(90)
	if not check(scene.player.animation_speed<0.18 and scene.player.raze.motion_state=="IDLE", "blocked movement does not walk in place"):
		return
	scene.mobile_move = Vector2.ZERO
	root.remove_child(scene)
	scene.free()
	var survival = load("res://survival.tscn").instantiate()
	root.add_child(survival)
	await frames(5)
	if not check(survival.survival_mode and survival.targets.size()==6 and survival.zone.radius>30.0 and survival.round_result=="", "survival scene starts"):
		return
	var drone_start: Vector3 = survival.targets[0].position
	await frames(24)
	if not check(survival.targets[0].position.distance_to(drone_start)>0.1, "arcade drone moves"):
		return
	survival.zone.advance(84.0)
	if not check(survival.zone.radius<34.0 and survival.zone.radius>6.0, "zone contracts"):
		return
	survival.zone.advance(200.0)
	if not check(is_equal_approx(survival.zone.radius,6.0) and survival.zone.phase==2, "zone reaches final size"):
		return
	survival.player.position = Vector3(20,0.1,20)
	var prior_health: int = survival.health
	survival.update_survival(1.0)
	if not check(survival.health<prior_health, "outside zone damages player"):
		return
	survival.armor = 10
	survival.damage_player(5)
	if not check(survival.armor==5, "shield absorbs arcade damage"):
		return
	survival.damage_player(200)
	if not check(survival.round_result=="DERROTA" and survival.health==0 and not survival.fire, "defeat stops round"):
		return
	survival.reset_round()
	if not check(survival.round_result=="" and survival.health==100 and survival.eliminated==0 and survival.zone.radius==34.0 and survival.targets[0].active, "survival reset"):
		return
	for drone in survival.targets:
		drone.take_hit(100)
	survival.update_survival(0.0)
	if not check(survival.round_result=="VICTORIA", "survival victory"):
		return
	print("LAST IMPACT R070 SMOKE PASS")
	quit(0)
