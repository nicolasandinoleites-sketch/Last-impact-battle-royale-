extends SceneTree
const RefShader = preload("res://tests/storm_volume_reference.gdshader")
const NewShader = preload("res://shaders/storm_volume.gdshader")
const Telemetry = preload("res://scripts/frame_telemetry.gd")
const OUT := "/tmp/lastimpact_storm_ab"

func _initialize() -> void:
	call_deferred("run")

func capture_variant(game, shader: Shader, sample_count: int, label: String) -> Dictionary:
	var material := ShaderMaterial.new()
	material.shader = shader
	material.render_priority = 100
	material.set_shader_parameter("cloud_tex",game.zone.storm_material.get_shader_parameter("cloud_tex"))
	material.set_shader_parameter("safe_radius",game.zone.radius)
	material.set_shader_parameter("storm_center",Vector2(game.zone.global_position.x,game.zone.global_position.z))
	material.set_shader_parameter("wind_time",17.0)
	material.set_shader_parameter("sample_count",sample_count)
	game.zone.volume.material_override = material
	for i in range(24):
		await RenderingServer.frame_post_draw
	var intervals := PackedFloat64Array()
	var last := Time.get_ticks_usec()
	for i in range(60):
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		intervals.append(float(now-last)/1000.0)
		last = now
	var image := root.get_texture().get_image()
	if image==null or image.is_empty():
		return {}
	image.convert(Image.FORMAT_RGB8)
	if image.save_png(OUT+"/"+label+".png")!=OK:
		return {}
	return {"image":image,"timing":Telemetry.summarize(intervals)}

func compare_images(a: Image, b: Image) -> Dictionary:
	if a.get_size()!=b.get_size():
		return {"pass":false}
	var x := a.get_data()
	var y := b.get_data()
	var total := 0.0
	var changed := 0
	var largest := 0
	for i in range(x.size()):
		var d := absi(int(x[i])-int(y[i]))
		total += d
		largest = maxi(largest,d)
		if d>2:
			changed += 1
	var mean := total/maxi(1,x.size())
	var fraction := float(changed)/maxi(1,x.size())
	return {"mean_abs_channel_8bit":mean,"fraction_channels_over_2":fraction,"max_channel_delta":largest,"pass":mean<=0.5 and fraction<=0.001}

func run() -> void:
	root.size = Vector2i(800,450)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_size = Vector2i(800,450)
	var game = load("res://survival.tscn").instantiate()
	root.add_child(game)
	game.profile = 0
	game.apply_profile()
	for i in range(12):
		await physics_frame
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.hud.hide()
	root.content_scale_size = Vector2i(800,450)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	camera.fov = 60.0
	camera.near = 0.08
	camera.far = 110.0
	Engine.max_fps = 0
	var cases := [{"name":"center","position":Vector3(0,1.7,12),"look":Vector3(0,1.2,-45)},
		{"name":"edge","position":Vector3(0,1.7,48),"look":Vector3(8,4,69)},
		{"name":"outside","position":Vector3(0,1.7,60),"look":Vector3(0,2,10)},
		{"name":"sky","position":Vector3(0,1.7,48),"look":Vector3(0,55,80)}]
	var report: Array[Dictionary] = []
	var all_ok := true
	for view in cases:
		camera.position = view["position"]
		camera.look_at(view["look"])
		for samples in [1,2]:
			var label := str(view["name"])+"_"+str(samples)
			var baseline: Dictionary
			var candidate: Dictionary
			if samples==1:
				baseline = await capture_variant(game,RefShader,samples,label+"_reference")
				candidate = await capture_variant(game,NewShader,samples,label+"_candidate")
			else:
				candidate = await capture_variant(game,NewShader,samples,label+"_candidate")
				baseline = await capture_variant(game,RefShader,samples,label+"_reference")
			if baseline.is_empty() or candidate.is_empty():
				push_error("TEST FAILED: storm comparison capture "+label)
				quit(1)
				return
			var pixels := compare_images(baseline["image"],candidate["image"])
			var entry := {"case":label,"reference":baseline["timing"],"candidate":candidate["timing"],"pixels":pixels}
			report.append(entry)
			print("STORM SHADER AB ",JSON.stringify(entry))
			all_ok = all_ok and bool(pixels["pass"])
	var file := FileAccess.open(OUT+"/report.json",FileAccess.WRITE)
	if file==null:
		quit(1)
		return
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	if not all_ok:
		push_error("TEST FAILED: storm visual equivalence")
		quit(1)
		return
	print("STORM SHADER AB COMPLETE")
	quit(0)
