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
	print("VISUAL CAPTURE COMPLETE")
	quit(0)
