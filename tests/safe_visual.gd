extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280,570)
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	scene.profile = 0
	scene.apply_profile()
	for i in range(45):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image==null or image.is_empty():
		push_error("VISUAL CAPTURE FAILED: safe material path")
		quit(1)
		return
	image.save_png("/tmp/lastimpact_visual_safe/01_safe_idle.png")
	scene.player.aiming = true
	for i in range(30):
		await process_frame
	await RenderingServer.frame_post_draw
	image = root.get_texture().get_image()
	image.save_png("/tmp/lastimpact_visual_safe/02_safe_aim.png")
	root.remove_child(scene)
	scene.free()
	var survival = load("res://survival.tscn").instantiate()
	root.add_child(survival)
	survival.profile = 0
	survival.apply_profile()
	for i in range(45):
		await process_frame
	await RenderingServer.frame_post_draw
	image = root.get_texture().get_image()
	if image==null or image.is_empty() or image.save_png("/tmp/lastimpact_visual_safe/03_safe_frontier.png")!=OK:
		push_error("VISUAL CAPTURE FAILED: safe frontier")
		quit(1)
		return
	print("SAFE MATERIAL CAPTURE COMPLETE")
	quit(0)
