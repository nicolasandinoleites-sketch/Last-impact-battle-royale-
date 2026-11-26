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
	print("VISUAL CAPTURE COMPLETE")
	quit(0)
