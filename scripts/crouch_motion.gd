extends RefCounted
# Dedicated grounded stance layer. Uses audited CC0 rotations, not root motion.
const NAMES := ["Crouch_Idle_Loop","Crouch_Fwd_Loop"]
const BONES := ["L_Thigh","R_Thigh","L_Calf","R_Calf","L_Foot","R_Foot","Waist","Spine01","Spine02","Head"]
var library: AnimationLibrary
var ids: Array[int] = []
var tracks: Array[PackedInt32Array] = []
var available := false
var weight := 0.0
var phase := 0.0
var stride_blend := 0.0
var samples := 0

func setup(rig: Skeleton3D, source: AnimationLibrary) -> bool:
	library = source
	available = false
	ids.clear()
	tracks.clear()
	if library==null:
		return false
	for name in BONES:
		var id := rig.find_bone(name)
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
	phase = 0.0
	stride_blend = 0.0
	samples = 0

func update(rig: Skeleton3D, delta: float, active: bool, grounded: bool, combat: bool, speed: float, local_motion: Vector2) -> void:
	if not available:
		return
	if not grounded:
		weight = 0.0
		return
	weight = lerpf(weight,1.0 if active else 0.0,1.0-exp(-delta*14.0))
	if weight<0.005:
		weight = 0.0
		return
	var alignment := -local_motion.y/maxf(local_motion.length(),0.001)
	# No sideways or backward authored crouch clips yet. Blend forward cycle only
	# for forward travel; the neutral pose is the safe fallback for other directions.
	var target := smoothstep(0.15,1.6,speed)*smoothstep(0.15,0.85,alignment) if active else 0.0
	stride_blend = lerpf(stride_blend,target,1.0-exp(-delta*10.0))
	phase = fposmod(phase+delta*lerpf(0.32,1.10,clampf(speed/2.0,0.0,1.0)),1.0)
	var a := library.get_animation(NAMES[0])
	var b := library.get_animation(NAMES[1])
	for i in range(ids.size()):
		var qa := a.rotation_track_interpolate(tracks[0][i],phase*a.length)
		var qb := b.rotation_track_interpolate(tracks[1][i],phase*b.length)
		var goal := qa.slerp(qb,stride_blend).normalized()
		var influence := weight if i<6 else weight*(0.18 if combat else 0.65)
		var q := rig.get_bone_pose_rotation(ids[i])
		rig.set_bone_pose_rotation(ids[i],q.slerp(goal,influence).normalized())
	samples += 1
