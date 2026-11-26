extends RefCounted
# One normalized phase for all three cyclic clips, only the lower-body mask.
# Keep the gameplay velocity authoritative and preserve upper-body weapon IK.
const LIBRARY := "res://assets/animations/raze_locomotion.tres"
const CLIPS := ["Walk_Loop","Jog_Fwd_Loop","Sprint_Loop"]
const BONES := ["L_Thigh","R_Thigh","L_Calf","R_Calf","L_Foot","R_Foot"]
var library: AnimationLibrary
var ids: Array[int] = []
var tracks: Array[PackedInt32Array] = []
var phase := 0.0
var weight := 0.0
var speed_blend := 0.0
var available := false
var active_clip := ""
var sample_count := 0
var phase_offsets := PackedFloat32Array()
var stride_travel := PackedFloat32Array()
var calibrated := false
var cadence_hz := 0.0
var calibration_enabled := true

func setup(rig: Skeleton3D) -> bool:
	if not ResourceLoader.exists(LIBRARY):
		return false
	library = load(LIBRARY) as AnimationLibrary
	if library==null:
		return false
	ids.clear()
	tracks.clear()
	phase_offsets.clear()
	stride_travel.clear()
	available = false
	calibrated = true
	for name in BONES:
		var id := rig.find_bone(name)
		if id<0:
			return false
		ids.append(id)
	for name in CLIPS:
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
		var offset := float(clip.get_meta("gait_phase_offset",0.0))
		var travel := float(clip.get_meta("gait_travel_m",0.0))
		if not is_finite(offset) or not is_finite(travel) or offset<0.0 or offset>=1.0 or travel<=0.35 or travel>=8.0:
			calibrated = false
		phase_offsets.append(offset)
		stride_travel.append(travel)
	available = true
	return true

func reset() -> void:
	phase = 0.0
	weight = 0.0
	speed_blend = 0.0
	active_clip = ""
	sample_count = 0
	cadence_hz = 0.0

func update(delta: float, speed: float, eligible: bool, local_motion: Vector2) -> void:
	if not available:
		return
	# Keep procedural directional animation for sharp turns, combat and backwards travel.
	var alignment := -local_motion.y/maxf(local_motion.length(),0.001)
	var desired := smoothstep(0.55,0.9,alignment)*smoothstep(0.25,1.0,speed) if eligible else 0.0
	weight = lerpf(weight,desired,1.0-exp(-delta*(10.0 if desired>weight else 18.0)))
	if weight<0.005:
		weight = 0.0
		active_clip = ""
		return
	speed_blend = lerpf(speed_blend,speed,1.0-exp(-delta*12.0))
	var cadence := 0.75*clampf(speed_blend/1.8,0.35,1.3) if speed_blend<2.4 else lerpf(0.9,1.5,clampf((speed_blend-2.4)/3.8,0.0,1.0))
	if calibrated and calibration_enabled:
		var segment := 0 if speed_blend<=3.8 else 1
		var mix_amount := smoothstep(1.8,3.8,speed_blend) if segment==0 else smoothstep(3.8,6.2,speed_blend)
		var travel := lerpf(stride_travel[segment],stride_travel[segment+1],mix_amount)
		# Clamp extreme cadence estimates; a calibrated stride still has a physical reach limit.
		var measured := clampf(speed_blend/maxf(travel,0.35),0.35,2.8)
		cadence = lerpf(cadence,measured,0.8)
	cadence_hz = cadence if cadence_hz<=0.0 else lerpf(cadence_hz,cadence,1.0-exp(-delta*10.0))
	phase = fposmod(phase+delta*cadence_hz,1.0)

func apply(rig: Skeleton3D) -> void:
	if not available or weight<=0.0:
		return
	var segment := 0 if speed_blend<=3.8 else 1
	var mix_amount := smoothstep(1.8,3.8,speed_blend) if segment==0 else smoothstep(3.8,6.2,speed_blend)
	var a := library.get_animation(CLIPS[segment])
	var b := library.get_animation(CLIPS[segment+1])
	active_clip = CLIPS[segment] if mix_amount<0.5 else CLIPS[segment+1]
	for i in range(ids.size()):
		var pa := fposmod(phase+phase_offsets[segment],1.0) if calibrated and calibration_enabled else phase
		var pb := fposmod(phase+phase_offsets[segment+1],1.0) if calibrated and calibration_enabled else phase
		var qa := a.rotation_track_interpolate(tracks[segment][i],pa*a.length)
		var qb := b.rotation_track_interpolate(tracks[segment+1][i],pb*b.length)
		var goal := qa.slerp(qb,mix_amount).normalized()
		var current := rig.get_bone_pose_rotation(ids[i])
		rig.set_bone_pose_rotation(ids[i],current.slerp(goal,weight).normalized())
	sample_count += 1
