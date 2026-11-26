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
	var actor = scene.player.raze
	scene.player.weapon.update_pose(0.1,true,0.0)
	if not check(is_instance_valid(scene.player.weapon.right_goal) and is_instance_valid(scene.player.weapon.left_goal), "dual wrist targets"):
		return
	var right_error: float = actor.solve_arm("R",scene.player.weapon.right_goal.global_position,Vector3(1,-1,0))
	var left_error: float = actor.solve_arm("L",scene.player.weapon.left_goal.global_position,Vector3(-1,-1,0))
	if not check(is_finite(right_error) and is_finite(left_error) and right_error<0.18 and left_error<0.18, "two arm IK bounded error"):
		return
	if not check(scene.game_audio.fire_player.stream != null and scene.game_audio.reload_player.stream != null, "synthetic game audio"):
		return
	if not check(actor.joints.size()==14 and actor.right_socket.bone_name=="R_Hand" and actor.left_socket.bone_name=="L_Hand", "locomotion joint map and sockets"):
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
	if not check(actor.motion_state=="SLIDE", "slide animation state"):
		return
	actor.locomotion(0.3,0.0,true,false,true)
	if not check(actor.motion_state=="AIM", "aim animation state"):
		return
	if not check(actor.dance() and actor.preview_dance, "original dance plays"):
		return
	if not check(actor.dance() and not actor.preview_dance, "dance returns to rest"):
		return
	var origin: Vector3 = scene.player.position
	scene.mobile_move = Vector2(0,-1)
	await frames(20)
	if not check(scene.player.position.distance_to(origin)>0.5, "movement"):
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
	if not check(scene.eliminated==0 and scene.ammo==30 and scene.targets[0].active, "reset"):
		return
	print("LAST IMPACT R061 SMOKE PASS")
	quit(0)
