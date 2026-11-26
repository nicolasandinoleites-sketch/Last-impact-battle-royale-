extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func replay(game, enabled: bool) -> Dictionary:
	game.reset_round()
	var actor = game.player.raze
	actor.air_motion.enabled = enabled
	for i in range(12):
		await physics_frame
	var origin: float = game.player.global_position.y
	game.player.jump_requested = true
	var heights := PackedFloat64Array()
	var states := {}
	var peak := 0.0
	var grip := 0.0
	var toe := 0.0
	var air_ticks := 0
	var anchor_free := true
	for tick in range(90):
		await physics_frame
		var h: float = game.player.global_position.y-origin
		heights.append(h)
		peak = maxf(peak,h)
		grip = maxf(grip,maxf(game.player.weapon.left_error,game.player.weapon.right_error))
		var state: String = actor.air_motion.state
		states[state] = int(states.get(state,0))+1
		if not game.player.is_on_floor():
			air_ticks += 1
			anchor_free = anchor_free and actor.foot_contact.anchors.is_empty()
		elif state=="LAND":
			toe = maxf(toe,actor.visual_ground_error)
	return {"heights":heights,"peak":peak,"air_ticks":air_ticks,"states":states,"grip":grip,"land_toe":toe,"anchor_free":anchor_free,"land_samples":actor.air_motion.land_samples}

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	for i in range(12):
		await physics_frame
	var actor = game.player.raze
	if not actor.air_motion.available:
		push_error("TEST FAILED: air library unavailable")
		quit(1)
		return
	var a := await replay(game,false)
	var b := await replay(game,true)
	var max_delta := 0.0
	for i in range(a["heights"].size()):
		max_delta = maxf(max_delta,absf(a["heights"][i]-b["heights"][i]))
	if max_delta>0.005 or a["air_ticks"]!=b["air_ticks"] or b["peak"]<0.6 or b["states"].get("ASCEND",0)<3 or b["states"].get("FALL",0)<3 or b["land_samples"]<3 or b["land_toe"]>0.30 or b["grip"]>0.08 or not b["anchor_free"] or actor.air_motion.state!="IDLE":
		push_error("TEST FAILED: air physics or pose regression "+str(b))
		quit(1)
		return
	game.reset_round()
	if actor.air_motion.samples!=0 or actor.air_motion.weight!=0.0:
		push_error("TEST FAILED: air reset")
		quit(1)
		return
	print("AIR MOTION PASS | physics_delta=",max_delta," peak=",b["peak"]," air_ticks=",b["air_ticks"]," states=",b["states"]," land_toe=",b["land_toe"]," grip=",b["grip"])
	quit(0)
