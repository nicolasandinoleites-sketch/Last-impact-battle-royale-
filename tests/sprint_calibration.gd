extends SceneTree
# Repeated fixed speed replay of actual actor, including the existing pose mixer.
# Ankle contact candidate is an approximation; visual acceptance is separate.
const OUT := "/tmp/lastimpact_sprint_ab"

func _initialize() -> void:
	call_deferred("run")

func measure(game, amplitude: float, cadence: float, masks: Array = [], warmup: int = 60) -> Dictionary:
	var actor = game.player.raze
	actor.reset_locomotion()
	actor.clip_motion.sprint_amplitude = amplitude
	actor.clip_motion.sprint_cadence_multiplier = cadence
	actor.clip_motion.sprint_support_masks = masks
	actor.clip_motion.sprint_lock_enabled = masks.size()==2
	actor.contact_lock_enabled = true
	game.player.position = Vector3.ZERO
	var samples: Array[PackedVector3Array] = [PackedVector3Array(),PackedVector3Array()]
	var relative: Array[PackedVector3Array] = [PackedVector3Array(),PackedVector3Array()]
	var ids: Array[int] = [actor.skeleton.find_bone("L_Foot"),actor.skeleton.find_bone("R_Foot")]
	var spreads := PackedFloat64Array()
	var height_error := 0.0
	var phases := PackedFloat32Array()
	const BINS := 32
	for tick in range(warmup+240):
		game.player.position.z -= 6.2/60.0
		actor.locomotion(1.0/60.0,6.2,true,false,false,true,0.0,Vector2(0,-6.2))
		actor.skeleton.force_update_all_bone_transforms()
		if tick<warmup:
			continue
		for side in range(2):
			var world: Vector3 = actor.skeleton.to_global(actor.skeleton.get_bone_global_pose(ids[side]).origin)
			var pts := samples[side]
			pts.append(world)
			samples[side] = pts
			var rel := relative[side]
			rel.append(actor.to_local(world))
			relative[side] = rel
		phases.append(actor.clip_motion.phase)
		var a: Vector3 = relative[0][-1]
		var b: Vector3 = relative[1][-1]
		spreads.append(Vector2(a.x-b.x,a.z-b.z).length())
		height_error = maxf(height_error,actor.visual_ground_error)
	var count := 0
	var drift := 0.0
	var learned: Array[PackedFloat32Array] = []
	for side in range(2):
		var lo := INF
		var hi := -INF
		for p in relative[side]:
			lo = minf(lo,p.y)
			hi = maxf(hi,p.y)
		var threshold := lo+maxf(0.025,(hi-lo)*0.28)
		var votes := PackedFloat32Array()
		var total := PackedFloat32Array()
		votes.resize(BINS)
		total.resize(BINS)
		for i in range(1,samples[side].size()):
			var v := relative[side][i]-relative[side][i-1]
			var bin := floori(phases[i]*BINS)%BINS
			total[bin] += 1.0
			if relative[side][i].y<=threshold and relative[side][i-1].y<=threshold and v.z>0.0025:
				votes[bin] += 1.0
				var motion := samples[side][i]-samples[side][i-1]
				drift += Vector2(motion.x,motion.z).length()*60.0
				count += 1
		for bin in range(BINS):
			votes[bin] /= maxf(1.0,total[bin])
		learned.append(votes)
	spreads.sort()
	return {"amplitude":amplitude,"cadence_multiplier":cadence,"speed_m_s":6.2,"contact_candidates":count,"slip_proxy_m_s":drift/maxi(count,1),"foot_separation_p95_m":spreads[ceili(spreads.size()*0.95)-1],"toe_height_error_max_m":height_error,"anchor_contacts":actor.foot_contact.contact_count,"anchor_ik_residual_m":actor.foot_contact.max_error,"learned_masks":learned,"warmup_ticks":warmup,"locked":masks.size()==2}

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
	# Fit on unlocked replay, evaluate on a different phase offset (83 warmup ticks).
	# Keep all runtime defaults neutral; no learned masks are packaged or activated.
	var support_trials: Array[Dictionary] = []
	var held_out_baseline := measure(game,1.0,1.0,[],83)
	for pair in [Vector2(0.7,1.0),Vector2(0.7,1.15),Vector2(0.55,1.15)]:
		var fit := measure(game,pair.x,pair.y)
		var unlocked := measure(game,pair.x,pair.y,[],83)
		var locked := measure(game,pair.x,pair.y,fit["learned_masks"],83)
		locked["eligible"] = locked["contact_candidates"]>=20 and locked["anchor_contacts"]>=2 and locked["anchor_ik_residual_m"]<=0.20 and locked["slip_proxy_m_s"]<=held_out_baseline["slip_proxy_m_s"] and locked["foot_separation_p95_m"]<=held_out_baseline["foot_separation_p95_m"]*0.9 and locked["toe_height_error_max_m"]<=maxf(0.20,held_out_baseline["toe_height_error_max_m"])
		var trial := {"fit":fit,"unlocked":unlocked,"locked":locked}
		support_trials.append(trial)
		print("SPRINT SUPPORT TRIAL ",JSON.stringify(trial))
	var output := FileAccess.open(OUT+"/report.json",FileAccess.WRITE)
	if output==null:
		quit(1)
		return
	output.store_string(JSON.stringify({"baseline":baseline,"variants":rows,"held_out_baseline":held_out_baseline,"support_trials":support_trials},"  "))
	output.close()
	game.player.raze.clip_motion.sprint_lock_enabled = false
	game.player.raze.clip_motion.sprint_support_masks.clear()
	game.player.raze.clip_motion.sprint_amplitude = 1.0
	game.player.raze.clip_motion.sprint_cadence_multiplier = 1.0
	print("SPRINT CALIBRATION COMPLETE | cases=",rows.size()," baseline=",JSON.stringify(baseline))
	quit(0)
