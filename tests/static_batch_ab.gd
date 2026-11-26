extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func capture_case(legacy: bool) -> Dictionary:
	OS.set_environment("LASTIMPACT_LEGACY_BLOCKS","1" if legacy else "0")
	var game = load("res://survival.tscn").instantiate()
	root.add_child(game)
	game.profile = 0
	game.apply_profile()
	for i in range(10):
		await physics_frame
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.hud.hide()
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(0,42,48)
	camera.look_at(Vector3(0,0,-15))
	camera.current = true
	Engine.max_fps = 0
	for i in range(12):
		await RenderingServer.frame_post_draw
	var tag := "legacy" if legacy else "batched"
	var samples := PackedFloat64Array()
	var draws := 0.0
	var primitives := 0.0
	for i in range(24):
		var start := Time.get_ticks_usec()
		await RenderingServer.frame_post_draw
		samples.append(float(Time.get_ticks_usec()-start)/1000.0)
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		primitives += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var result: Dictionary = preload("res://scripts/frame_telemetry.gd").summarize(samples)
	result["draw_calls_mean"] = draws/24.0
	result["primitives_mean"] = primitives/24.0
	result["variant"] = tag
	result["blocks"] = game.frontier.batched_blocks
	result["groups"] = game.frontier.batch_draw_groups
	var physics_count := 0
	for child in game.get_children():
		if child is StaticBody3D:
			physics_count += 1
	result["static_bodies"] = physics_count
	var image := root.get_texture().get_image()
	if image==null or image.is_empty() or image.save_png("/tmp/lastimpact_batch_ab/"+tag+".png")!=OK:
		push_error("TEST FAILED: A/B capture "+tag)
		quit(1)
	print("STATIC BATCH AB ",JSON.stringify(result))
	root.remove_child(camera)
	camera.free()
	root.remove_child(game)
	game.free()
	await process_frame
	return result

func run() -> void:
	root.size = Vector2i(960,540)
	var legacy := await capture_case(true)
	var batched := await capture_case(false)
	if legacy["static_bodies"]!=batched["static_bodies"] or batched["blocks"]!=49 or batched["groups"]!=19:
		push_error("TEST FAILED: batch structure/collision parity")
		quit(1)
		return
	print("STATIC BATCH AB COMPLETE")
	quit(0)
