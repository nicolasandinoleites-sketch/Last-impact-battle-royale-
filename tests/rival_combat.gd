extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://battle_royale.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.deployment.finish()
	game.set_physics_process(false)
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
	if "preview" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://docs/previews/R0786_duelo.png") == OK)
	for frame in range(450):
		await physics_frame
		if a.reload_left > 0: break
	assert(a.reload_left > 0 and a.rounds == 0)
	b.set_physics_process(false)
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
	a.reset_target()
	assert(not a.weapon.visible and a.enemy == null)
	print("R0786 COMBAT PASS | autonomous duel, Tripo weapons, reload, blocked shot, reset")
	game.queue_free()
	await process_frame
	await process_frame
	quit()
