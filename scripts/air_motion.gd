extends RefCounted
# Cosmetic in-place air layer. CharacterBody3D owns takeoff, apex and contact.
const NAMES := ["Jump_Start","Jump_Loop","Jump_Land"]
const BONES := ["L_Thigh","R_Thigh","L_Calf","R_Calf","L_Foot","R_Foot","Waist","Spine01","Spine02","Head"]
const LAND_DURATION := 0.22
var library: AnimationLibrary
var ids: Array[int] = []
var tracks: Array[PackedInt32Array] = []
var available := false
var enabled := true
var weight := 0.0
var state := "IDLE"
var elapsed := 0.0
var was_grounded := true
var samples := 0
var land_samples := 0

func setup(rig: Skeleton3D, source: AnimationLibrary) -> bool:
	library = source
	available = false
	ids.clear()
	tracks.clear()
	if library==null:
		return false
	for bone in BONES:
		var id := rig.find_bone(bone)
		if id<0:
			return false
		ids.append(id)
	for name in NAMES:
		if not library.has_animation(name):
			return false
		var clip := library.get_animation(name)
		if clip.length<=0.0:
			return false
		var row := PackedInt32Array()
		for bone in BONES:
			var track := clip.find_track(NodePath(".:"+bone),Animation.TYPE_ROTATION_3D)
			if track<0 or clip.track_get_key_count(track)<2:
				return false
			row.append(track)
		tracks.append(row)
	available = true
	return true

func reset() -> void:
	weight = 0.0
	state = "IDLE"
	elapsed = 0.0
	was_grounded = true
	samples = 0
	land_samples = 0

func update(rig: Skeleton3D, delta: float, grounded: bool, low: bool, combat: bool, vertical_speed: float) -> void:
	if not available or not enabled or low:
		weight = 0.0
		state = "IDLE"
		elapsed = 0.0
		was_grounded = grounded
		return
	if not grounded:
		var next := "ASCEND" if vertical_speed>0.0 else "FALL"
		if state!=next:
			elapsed = 0.0
		state = next
	elif not was_grounded:
		state = "LAND"
		elapsed = 0.0
	elif state=="LAND" and elapsed>=LAND_DURATION:
		state = "IDLE"
		elapsed = 0.0
	was_grounded = grounded
	elapsed += delta
	var desired := 1.0 if not grounded else (1.0-smoothstep(0.10,LAND_DURATION,elapsed) if state=="LAND" else 0.0)
	weight = lerpf(weight,desired,1.0-exp(-delta*20.0))
	if state=="IDLE":
		# The procedural locomotion layer owns the grounded recovery pose.
		weight = 0.0
		return
	var index := 0 if state=="ASCEND" else (1 if state=="FALL" else 2)
	var clip := library.get_animation(NAMES[index])
	# Start past the deep pre-takeoff crouch; collision already left the ground.
	var phase := lerpf(0.42,1.0,clampf(elapsed/0.33,0.0,1.0)) if index==0 else (fposmod(elapsed*0.65,1.0) if index==1 else clampf(elapsed/LAND_DURATION,0.0,1.0))
	for i in range(ids.size()):
		var q := rig.get_bone_pose_rotation(ids[i])
		var target := clip.rotation_track_interpolate(tracks[index][i],minf(clip.length-0.0001,phase*clip.length))
		var influence := weight*0.82 if i<6 else weight*(0.15 if combat else 0.48)
		rig.set_bone_pose_rotation(ids[i],q.slerp(target,influence).normalized())
	samples += 1
	if state=="LAND":
		land_samples += 1
