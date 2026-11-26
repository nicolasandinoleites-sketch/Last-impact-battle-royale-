extends SceneTree
# Repeated fixed speed replay of actual actor, including the existing pose mixer.
# Ankle contact candidate is an approximation; visual acceptance is separate.
const OUT := "/tmp/lastimpact_sprint_ab"

func _initialize() -> void:
	call_deferred("run")

func measure(game, amplitude: float, cadence: float) -> Dictionary:
	var actor = game.player.raze
	actor.reset_locomotion()
	actor.clip_motion.sprint_amplitude = amplitude
	actor.clip_motion.sprint_cadence_multiplier = cadence
	game.player.position = Vector3.ZERO
	var samples: Array[PackedVector3Array] = [PackedVector3Array(),PackedVector3Array()]
	var relative: Array[PackedVector3Array] = [PackedVector3Array(),PackedVector3Array()]
	var ids: Array[int] = [actor.skeleton.find_bone("L_Foot"),actor.skeleton.find_bone("R_Foot")]
	var spreads := PackedFloat64Array()
	var height_error := 0.0
	for tick in range(300):
		game.player.position.z -= 6.2/60.0
		actor.locomotion(1.0/60.0,6.2,true,false,false,true,0.0,Vector2(0,-6.2))
		actor.skeleton.force_update_all_bone_transforms()
		if tick<60:
			continue
		for side in range(2):
			var world: Vector3 = actor.skeleton.to_global(actor.skeleton.get_bone_global_pose(ids[side]).origin)
			var pts := samples[side]
			pts.append(world)
			samples[side] = pts
			var rel := relative[side]
			rel.append(actor.to_local(world))
			relative[side] = rel
		var a: Vector3 = relative[0][-1]
		var b: Vector3 = relative[1][-1]
		spreads.append(Vector2(a.x-b.x,a.z-b.z).length())
		height_error = maxf(height_error,actor.visual_ground_error)
	var count := 0
	var drift := 0.0
	for side in range(2):
		var lo := INF
		var hi := -INF
		for p in relative[side]:
			lo = minf(lo,p.y)
			hi = maxf(hi,p.y)
		var threshold := lo+maxf(0.025,(hi-lo)*0.28)
		for i in range(1,samples[side].size()):
			var v := relative[side][i]-relative[side][i-1]
			if relative[side][i].y<=threshold and relative[side][i-1].y<=threshold and v.z>0.0025:
				var motion := samples[side][i]-samples[side][i-1]
				drift += Vector2(motion.x,motion.z).length()*60.0
				count += 1
	spreads.sort()
	return {"amplitude":amplitude,"cadence_multiplier":cadence,"speed_m_s":6.2,"contact_candidates":count,"slip_proxy_m_s":drift/maxi(count,1),"foot_separation_p95_m":spreads[ceili(spreads.size()*0.95)-1],"toe_height_error_max_m":height_error}

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await physics_frame
	game.process_mode = Node.PROCESS_MODE_DISABLED
	if not game.player.raze.clip_motion.available:
		push_error("TEST FAILED: missing sprint library")
		quit(1)
		return
	var baseline := measure(game,1.0,1.0)
	var rows: Array[Dictionary] = [baseline]
	if baseline["contact_candidates"]<20 or baseline["foot_separation_p95_m"]<=0.0:
		push_error("TEST FAILED: invalid sprint baseline")
		quit(1)
		return
	for amplitude in [0.85,0.7,0.55]:
		for cadence in [1.0,1.15,1.3,1.45]:
			var row := measure(game,amplitude,cadence)
			row["eligible"] = row["contact_candidates"]>=20 and row["slip_proxy_m_s"]<=baseline["slip_proxy_m_s"] and row["foot_separation_p95_m"]<=baseline["foot_separation_p95_m"]*0.9 and row["toe_height_error_max_m"]<=maxf(0.20,baseline["toe_height_error_max_m"])
			rows.append(row)
			print("SPRINT CANDIDATE ",JSON.stringify(row))
	var output := FileAccess.open(OUT+"/report.json",FileAccess.WRITE)
	if output==null:
		quit(1)
		return
	output.store_string(JSON.stringify({"baseline":baseline,"variants":rows},"  "))
	output.close()
	game.player.raze.clip_motion.sprint_amplitude = 1.0
	game.player.raze.clip_motion.sprint_cadence_multiplier = 1.0
	print("SPRINT CALIBRATION COMPLETE | cases=",rows.size()," baseline=",JSON.stringify(baseline))
	quit(0)
