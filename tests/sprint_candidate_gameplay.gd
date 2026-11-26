extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> bool:
	if not ok:
		push_error("TEST FAILED: sprint candidate "+label)
		quit(1)
		return false
	return true

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	for i in range(12):
		await physics_frame
	var actor = game.player.raze
	var clips = actor.clip_motion
	if not check(clips.available and not clips.sprint_lock_enabled,"candidate opt-in only"):
		return
	clips.configure_sprint_candidate(true)
	game.reset_round()
	for i in range(8):
		await physics_frame
	game.mobile_move = Vector2(0,-1)
	game.mobile_sprint = true
	var max_grip := 0.0
	var max_toe := 0.0
	var active_support_ticks := 0
	var sprint_ticks := 0
	for i in range(100):
		await physics_frame
		if game.player.animation_speed>=5.9 and game.player.is_on_floor() and clips.speed_blend>=5.9:
			sprint_ticks += 1
			if not actor.foot_contact.anchors.is_empty():
				active_support_ticks += 1
			max_toe = maxf(max_toe,actor.visual_ground_error)
			max_grip = maxf(max_grip,maxf(game.player.weapon.left_error,game.player.weapon.right_error))
	if not check(sprint_ticks>=30 and active_support_ticks>=3 and game.player.animation_speed<=6.3,"real sprint reaches speed and support activates"):
		return
	if not check(max_grip<0.08 and max_toe<0.25 and actor.foot_contact.max_error<=0.20,"sprint grip and contact budgets"):
		return
	game.player.aiming = true
	for i in range(15):
		await physics_frame
	if not check(actor.foot_contact.anchors.is_empty() and game.player.animation_speed<=2.9,"ADS releases anchors and returns to aim speed"):
		return
	game.player.aiming = false
	for i in range(35):
		await physics_frame
	game.player.jump_requested = true
	for i in range(10):
		await physics_frame
	if not check(not game.player.is_on_floor() and actor.foot_contact.anchors.is_empty(),"airborne releases sprint anchors"):
		return
	game.mobile_move = Vector2.ZERO
	game.mobile_sprint = false
	for i in range(90):
		await physics_frame
	if not check(game.player.is_on_floor() and game.player.animation_speed<0.15 and actor.foot_contact.anchors.is_empty(),"landing and braking return to idle"):
		return
	game.reset_round()
	if not check(actor.foot_contact.anchors.is_empty() and actor.foot_contact.contact_count==0,"reset releases anchors"):
		return
	clips.configure_sprint_candidate(false)
	print("SPRINT CANDIDATE GAMEPLAY PASS | sprint_ticks=",sprint_ticks," support_ticks=",active_support_ticks," max_grip=",max_grip," max_toe=",max_toe)
	quit(0)
