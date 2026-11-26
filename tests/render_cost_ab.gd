extends SceneTree
const Telemetry = preload("res://scripts/frame_telemetry.gd")
const OUT := "/tmp/lastimpact_render_ab"

func _initialize() -> void:
	call_deferred("run")

func measure(game, camera: Camera3D, view_name: String, base_size: Vector2i, storm: bool) -> Dictionary:
	root.content_scale_size = base_size
	game.zone.volume.visible = storm
	if view_name=="center":
		camera.position = Vector3(0,1.7,12)
		camera.look_at(Vector3(0,1.2,-45))
	else:
		camera.position = Vector3(0,1.7,game.zone.radius-6.0)
		camera.look_at(Vector3(8,4.0,game.zone.radius+15.0))
	for i in range(24):
		await RenderingServer.frame_post_draw
	var samples := PackedFloat64Array()
	var draws := 0.0
	var last := Time.get_ticks_usec()
	for i in range(60):
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		samples.append(float(now-last)/1000.0)
		last = now
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var result := Telemetry.summarize(samples)
	result["view"] = view_name
	result["base_width"] = base_size.x
	result["base_height"] = base_size.y
	result["storm_volume"] = storm
	result["draw_calls_mean"] = draws/60.0
	var image := root.get_texture().get_image()
	if image==null or image.is_empty():
		push_error("TEST FAILED: render AB image absent")
		return {}
	var name := "%s_%d_%s" % [view_name,base_size.x,"storm" if storm else "reference"]
	if image.save_png(OUT+"/"+name+".png")!=OK:
		push_error("TEST FAILED: render AB image save")
		return {}
	result["capture_width"] = image.get_width()
	result["capture_height"] = image.get_height()
	print("RENDER AB ",JSON.stringify(result))
	return result

func run() -> void:
	root.size = Vector2i(960,540)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	var game = load("res://survival.tscn").instantiate()
	root.add_child(game)
	game.profile = 0
	game.apply_profile()
	for i in range(12):
		await physics_frame
	game.process_mode = Node.PROCESS_MODE_DISABLED
	# Freeze seed, scene, weather time and AI. Hide HUD in every case.
	game.hud.hide()
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	camera.fov = 60.0
	camera.near = 0.08
	camera.far = 110.0
	Engine.max_fps = 0
	var results: Array[Dictionary] = []
	# Alternating order reduces (but does not eliminate) cache/order effects.
	for view_name in ["center","edge"]:
		for base_size in [Vector2i(800,450),Vector2i(640,360)]:
			var order := [true,false] if base_size.x==800 else [false,true]
			for storm in order:
				var result := await measure(game,camera,view_name,base_size,storm)
				if result.is_empty() or result.get("frames",0)!=60 or result.get("median_ms",0.0)<=0.0:
					push_error("TEST FAILED: invalid render AB metrics")
					quit(1)
					return
				results.append(result)
	var file := FileAccess.open(OUT+"/report.json",FileAccess.WRITE)
	if file==null:
		quit(1)
		return
	file.store_string(JSON.stringify(results,"  "))
	file.close()
	print("RENDER AB COMPLETE")
	quit(0)
