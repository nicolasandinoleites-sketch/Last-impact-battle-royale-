extends SceneTree

func _initialize() -> void:
	call_deferred("run")

# Isolated constant-speed replay; not a physical foot pressure measurement.
# Ankle trajectories are a stance-slip proxy, not actual sole contact.
func measure(game, speed: float, calibrated: bool) -> Dictionary:
	var actor = game.player.raze
	actor.reset_locomotion()
	actor.clip_motion.calibration_enabled = calibrated
	game.player.position = Vector3.ZERO
	var points: Array[PackedVector3Array] = [PackedVector3Array(),PackedVector3Array()]
	var relative: Array[PackedVector3Array] = [PackedVector3Array(),PackedVector3Array()]
	var ids: Array[int] = [actor.skeleton.find_bone("L_Foot"),actor.skeleton.find_bone("R_Foot")]
	for tick in range(240):
		game.player.position.z -= speed/60.0
		actor.locomotion(1.0/60.0,speed,true,false,false,speed>4.2,0.0,Vector2(0,-speed))
		actor.skeleton.force_update_all_bone_transforms()
		if tick<60:
			continue
		for side in range(2):
			var world: Vector3 = actor.skeleton.to_global(actor.skeleton.get_bone_global_pose(ids[side]).origin)
			var a := points[side]
			a.append(world)
			points[side] = a
			var b := relative[side]
			b.append(actor.to_local(world))
			relative[side] = b
	var drift := 0.0
	var count := 0
	for side in range(2):
		var lo := INF
		var hi := -INF
		for p in relative[side]:
			lo = minf(lo,p.y)
			hi = maxf(hi,p.y)
		var threshold := lo+maxf(0.025,(hi-lo)*0.28)
		for i in range(1,points[side].size()):
			var v := relative[side][i]-relative[side][i-1]
			if relative[side][i].y<=threshold and relative[side][i-1].y<=threshold and v.z>0.0025:
				var step := points[side][i]-points[side][i-1]
				drift += Vector2(step.x,step.z).length()*60.0
				count += 1
	return {"speed":speed,"calibrated":calibrated,"samples":count,"stance_slip_proxy_m_s":drift/maxi(count,1),"cadence_hz":actor.clip_motion.cadence_hz}

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var clips = game.player.raze.clip_motion
	if not clips.available:
		push_error("TEST FAILED: gait library unavailable")
		quit(1)
		return
	print("GAIT METADATA | calibrated=",clips.calibrated," offsets=",clips.phase_offsets," travel=",clips.stride_travel)
	for speed in [1.8,3.8,6.2]:
		var baseline := measure(game,speed,false)
		var candidate := measure(game,speed,true)
		print("GAIT AB ",JSON.stringify({"baseline":baseline,"candidate":candidate}))
		if baseline["samples"]<1 or candidate["samples"]<1 or not is_finite(candidate["stance_slip_proxy_m_s"]):
			push_error("TEST FAILED: insufficient gait samples")
			quit(1)
			return
	print("GAIT AB COMPLETE")
	quit(0)
