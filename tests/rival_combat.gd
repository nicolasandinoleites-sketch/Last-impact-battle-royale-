extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://battle_royale.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.deployment.finish()
	game.set_physics_process(false)
	game.profile = 0
	game.apply_profile()
	game.player.set_physics_process(false)
	game.player.global_position = Vector3(40,0,40)
	for target in game.targets:
		target.set_physics_process(false)
		target.collision_layer = 0
		target.hide()
	for pickup in game.pickups: pickup.collect(pickup.quantity)
	var a = game.targets[2]
	var b = game.targets[4]
	a.reset_target()
	b.reset_target()
	a.global_position = Vector3(-20,0.01,-20)
	b.global_position = Vector3(-14,0.01,-20)
	game.hud.hide()
	var camera := Camera3D.new()
	game.add_child(camera)
	camera.position = Vector3(-21,2.0,-16)
	camera.look_at(Vector3(-18.3,1,-20))
	camera.fov = 44
	camera.current = true
	a.set_physics_process(true)
	b.set_physics_process(true)
	for frame in range(360):
		await physics_frame
		if a.rounds == 5 and b.hp == 91: break
	assert(a.enemy == b and b.hp == 91 and a.weapon.loaded and b.weapon.loaded)
	assert(not a.weapon.energy_cell.visible)
	if "preview" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://docs/previews/R0786_duelo.png") == OK)
	for frame in range(450):
		await physics_frame
		if a.reload_left > 0: break
	assert(a.reload_left > 0 and a.rounds == 0)
	b.set_physics_process(false)
	if "preview" in OS.get_cmdline_user_args():
		for frame in range(38): await physics_frame
		var focus: Vector3 = a.weapon.global_position
		camera.position = focus + a.visual.global_basis * Vector3(-1.15,0.45,-1.0)
		camera.look_at(focus)
		assert(a.weapon.energy_cell.visible)
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://docs/previews/R0787_recarga.png") == OK)
	for frame in range(130):
		await physics_frame
		if a.rounds == a.MAGAZINE: break
	assert(a.rounds == a.MAGAZINE)
	a.set_physics_process(false)
	var wall := StaticBody3D.new()
	game.add_child(wall)
	wall.position = a.position.lerp(b.position,0.5) + Vector3.UP
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.5,3,3)
	collision.shape = box
	wall.add_child(collision)
	await physics_frame
	await physics_frame
	var health: int = b.hp
	a.enemy = b
	a.ai_state = "ENGAGE"
	a.shot_left = 0.0
	a.update_combat(1.0)
	assert(b.hp == health and a.rounds == a.MAGAZINE)
	# Put a solid barrier behind the operator while the opponent remains visible.
	wall.position = a.position + Vector3(-3,1,0)
	await physics_frame
	await physics_frame
	a.hp = 25
	a.decision_left = 0
	a.decide_tactical(0.4)
	assert(a.ai_state == "COVER")
	var goal: Vector3 = a.tactical_goal
	var sight := PhysicsRayQueryParameters3D.create(b.position+Vector3.UP,goal+Vector3.UP,1)
	assert(not a.get_world_3d().direct_space_state.intersect_ray(sight).is_empty())
	assert(not game.zone.outside(goal) and not game.frontier.route(a.position,goal).is_empty())
	a.reset_target()
	assert(not a.weapon.visible and a.enemy == null)
	print("R0786 COMBAT PASS | autonomous duel, Tripo weapons, reload, blocked shot, reachable occluded cover, reset")
	for voice in game.find_children("*","AudioStreamPlayer",true,false):
		voice.stop()
	game.queue_free()
	await process_frame
	await process_frame
	# Let the audio mixer release stopped WAV voices before the test process exits.
	OS.delay_msec(180)
	quit()
