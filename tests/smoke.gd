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
	print("LAST IMPACT R04 SMOKE PASS")
	quit(0)
