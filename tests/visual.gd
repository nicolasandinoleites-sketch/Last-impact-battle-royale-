extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func wait_frames(n: int) -> void:
	for i in range(n):
		await process_frame
func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("VISUAL CAPTURE FAILED: "+name)
		quit(1)
		return
	image.save_png("/tmp/lastimpact_visual/"+name+".png")
	print("VISUAL CAPTURE: "+name)
func run() -> void:
	root.size = Vector2i(960,540)
	var lobby = load("res://lobby.tscn").instantiate()
	root.add_child(lobby)
	await wait_frames(30)
	if not is_instance_valid(lobby.preview) or not lobby.preview.loaded:
		push_error("VISUAL CAPTURE FAILED: actual lobby character")
		quit(1)
		return
	await capture("01_lobby")
	root.remove_child(lobby)
	lobby.free()
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await wait_frames(30)
	await capture("02_training")
	scene.player.aiming = true
	await wait_frames(30)
	await capture("03_aim")
	scene.ammo = 12
	scene.start_reload()
	await wait_frames(15)
	await capture("04_reload")
	# Independent inspection camera, not the playable TPS camera.
	scene.reload_left = 0.0
	scene.player.aiming = true
	var inspection := Camera3D.new()
	scene.add_child(inspection)
	inspection.fov = 38.0
	inspection.current = true
	var body: Vector3 = scene.player.global_position
	inspection.position = body+Vector3(2.4,1.6,-1.4)
	inspection.look_at(body+Vector3(0,1.2,-0.12))
	scene.hud.hide()
	await wait_frames(30)
	await capture("05_grip_right")
	inspection.position = body+Vector3(-2.4,1.6,-1.4)
	inspection.look_at(body+Vector3(0,1.2,-0.12))
	await wait_frames(20)
	await capture("06_grip_left")
	print("GRIP DIAGNOSTIC ",scene.player.weapon.right_error," / ",scene.player.weapon.left_error)
	if maxf(scene.player.weapon.right_error,scene.player.weapon.left_error)>0.025:
		push_error("VISUAL CAPTURE FAILED: grip distance exceeds 25 mm")
		quit(1)
		return
	# Inspect the isolated imported cosmetic asset at full render resolution.
	root.scaling_3d_scale = 1.0
	scene.player.visual.hide()
	var center: Vector3 = scene.player.weapon.global_position
	var side: Vector3 = scene.player.weapon.global_transform.basis.x.normalized()
	inspection.position = center+side*1.05+Vector3(0,0.13,0)
	inspection.look_at(center)
	inspection.fov = 42.0
	await wait_frames(20)
	await capture("07_weapon_isolated")
	scene.player.visual.show()
	inspection.position = body+Vector3(-1.45,1.47,-0.8)
	inspection.look_at(body+Vector3(0,1.30,-0.18))
	inspection.fov = 39.0
	scene.ammo = 12
	scene.reserve = 50
	scene.start_reload()
	# Fixed physics checkpoints keep the capture independent of software-renderer FPS.
	for i in range(30):
		await physics_frame
	await capture("08_reload_exchange")
	for i in range(24):
		await physics_frame
	await capture("09_reload_insert")
	for i in range(48):
		await physics_frame
	await capture("10_reload_complete")
	# Consecutive samples during actual physics simulation, using a tracking inspection camera.
	scene.player.aiming = false
	scene.mobile_move = Vector2(0,-1)
	for sample in range(8):
		for tick in range(5):
			await physics_frame
		var follow: Vector3 = scene.player.global_position
		inspection.position = follow+Vector3(2.6,1.45,-1.2)
		inspection.look_at(follow+Vector3(0,0.90,0))
		inspection.fov = 45.0
		await capture("motion_walk_%02d" % sample)
	scene.mobile_sprint = true
	for sample in range(8):
		for tick in range(5):
			await physics_frame
		var follow: Vector3 = scene.player.global_position
		inspection.position = follow+Vector3(2.6,1.45,-1.2)
		inspection.look_at(follow+Vector3(0,0.90,0))
		await capture("motion_sprint_%02d" % sample)
	scene.player.request_slide()
	for sample in range(5):
		for tick in range(5):
			await physics_frame
		var follow: Vector3 = scene.player.global_position
		inspection.position = follow+Vector3(2.6,1.45,-1.2)
		inspection.look_at(follow+Vector3(0,0.90,0))
		await capture("motion_slide_%02d" % sample)
	scene.mobile_move = Vector2.ZERO
	scene.mobile_sprint = false
	for tick in range(60):
		await physics_frame
	scene.ammo = 12
	scene.reserve = 50
	scene.start_reload()
	for sample in range(12):
		for tick in range(7):
			await physics_frame
		var follow: Vector3 = scene.player.global_position
		inspection.position = follow+Vector3(-1.60,1.45,-0.85)
		inspection.look_at(follow+Vector3(0,1.28,-0.18))
		inspection.fov = 42.0
		await capture("motion_reload_%02d" % sample)
	print("VISUAL MOTION COMPLETE")
	print("VISUAL CAPTURE COMPLETE")
	quit(0)
