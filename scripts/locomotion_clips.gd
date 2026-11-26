extends RefCounted
# One normalized phase for all three cyclic clips, only the lower-body mask.
# Keep the gameplay velocity authoritative and preserve upper-body weapon IK.
const LIBRARY := "res://assets/animations/raze_locomotion.tres"
const CLIPS := ["Walk_Loop","Jog_Fwd_Loop","Sprint_Loop"]
const BONES := ["L_Thigh","R_Thigh","L_Calf","R_Calf","L_Foot","R_Foot"]
# Spine descendants only: do not rotate Hip or Pelvis and disturb foot calibration.
const TORSO_BONES := ["Spine01","Spine02","Head"]
var torso_ids: Array[int] = []
var torso_tracks: Array[PackedInt32Array] = []
var torso_weight := 0.0
var torso_enabled := true
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
var support_masks: Array = []
# Experimental parameters; neutral defaults preserve the approved gait.
var sprint_amplitude := 1.0
var sprint_cadence_multiplier := 1.0
# Experimental support masks learned from replayed candidate poses, not the source clip.
var sprint_support_masks: Array = []
var sprint_lock_enabled := false

func setup(rig: Skeleton3D) -> bool:
	if not ResourceLoader.exists(LIBRARY):
		return false
	library = load(LIBRARY) as AnimationLibrary
	if library==null:
		return false
	ids.clear()
	tracks.clear()
	torso_ids.clear()
	torso_tracks.clear()
	phase_offsets.clear()
	stride_travel.clear()
	support_masks.clear()
	available = false
	calibrated = true
	for name in BONES:
		var id := rig.find_bone(name)
		if id<0:
			return false
		ids.append(id)
	for bone in TORSO_BONES:
		var id := rig.find_bone(bone)
		if id<0:
			return false
		torso_ids.append(id)
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
		var torso_row := PackedInt32Array()
		for bone in TORSO_BONES:
			var track := clip.find_track(NodePath(".:"+bone),Animation.TYPE_ROTATION_3D)
			if track<0 or clip.track_get_key_count(track)<2:
				return false
			torso_row.append(track)
		torso_tracks.append(torso_row)
		var offset := float(clip.get_meta("gait_phase_offset",0.0))
		var travel := float(clip.get_meta("gait_travel_m",0.0))
		if not is_finite(offset) or not is_finite(travel) or offset<0.0 or offset>=1.0 or travel<=0.35 or travel>=8.0:
			calibrated = false
		phase_offsets.append(offset)
		stride_travel.append(travel)
		var left: PackedFloat32Array = clip.get_meta("gait_left_mask",PackedFloat32Array())
		var right: PackedFloat32Array = clip.get_meta("gait_right_mask",PackedFloat32Array())
		support_masks.append([left,right])
	available = true
	return true

func reset() -> void:
	phase = 0.0
	weight = 0.0
	torso_weight = 0.0
	speed_blend = 0.0
	active_clip = ""
	sample_count = 0
	cadence_hz = 0.0

func calibration_strength(speed: float) -> float:
	# CI 122 found a sprint slip regression; preserve calibrated walk/jog,
	# but return smoothly to the R0762 cadence and phase at sprint speed.
	return 1.0-smoothstep(4.2,5.8,speed) if calibrated and calibration_enabled else 0.0

func update(delta: float, speed: float, eligible: bool, local_motion: Vector2) -> void:
	if not available:
		return
	# Keep procedural directional animation for sharp turns, combat and backwards travel.
	var alignment := -local_motion.y/maxf(local_motion.length(),0.001)
	var desired := smoothstep(0.55,0.9,alignment)*smoothstep(0.25,1.0,speed) if eligible else 0.0
	weight = lerpf(weight,desired,1.0-exp(-delta*(10.0 if desired>weight else 18.0)))
	var torso_target := desired*lerpf(0.25,0.40,smoothstep(3.8,6.2,speed)) if torso_enabled else 0.0
	torso_weight = lerpf(torso_weight,torso_target,1.0-exp(-delta*16.0))
	if torso_weight<0.005:
		torso_weight = 0.0
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
		cadence = lerpf(cadence,measured,0.8*calibration_strength(speed_blend))
	cadence *= lerpf(1.0,sprint_cadence_multiplier,smoothstep(4.4,6.0,speed_blend))
	cadence_hz = cadence if cadence_hz<=0.0 else lerpf(cadence_hz,cadence,1.0-exp(-delta*10.0))
	phase = fposmod(phase+delta*cadence_hz,1.0)

func mask_at(clip_index: int, side_index: int) -> float:
	if clip_index>=support_masks.size():
		return 0.0
	var mask: PackedFloat32Array = support_masks[clip_index][side_index]
	if mask.is_empty():
		return 0.0
	var p := fposmod(phase+phase_offsets[clip_index]*calibration_strength(speed_blend),1.0)*mask.size()
	var i := floori(p)
	return lerpf(mask[i%mask.size()],mask[(i+1)%mask.size()],p-float(i))

func support_confidence(side: String) -> float:
	if sprint_lock_enabled and speed_blend>=5.9 and sprint_support_masks.size()==2:
		var mask: PackedFloat32Array = sprint_support_masks[0 if side=="L" else 1]
		if not mask.is_empty():
			var p := fposmod(phase,1.0)*mask.size()
			var i := floori(p)
			return lerpf(mask[i%mask.size()],mask[(i+1)%mask.size()],p-float(i))
	if not calibrated or not calibration_enabled or not available:
		return 0.0
	var segment := 0 if speed_blend<=3.8 else 1
	var mix_amount := smoothstep(1.8,3.8,speed_blend) if segment==0 else smoothstep(3.8,6.2,speed_blend)
	var side_index := 0 if side=="L" else 1
	return lerpf(mask_at(segment,side_index),mask_at(segment+1,side_index),mix_amount)*calibration_strength(speed_blend)

func apply(rig: Skeleton3D) -> void:
	if not available or weight<=0.0:
		return
	var segment := 0 if speed_blend<=3.8 else 1
	var mix_amount := smoothstep(1.8,3.8,speed_blend) if segment==0 else smoothstep(3.8,6.2,speed_blend)
	var a := library.get_animation(CLIPS[segment])
	var b := library.get_animation(CLIPS[segment+1])
	active_clip = CLIPS[segment] if mix_amount<0.5 else CLIPS[segment+1]
	for i in range(ids.size()):
		var pa := fposmod(phase+phase_offsets[segment]*calibration_strength(speed_blend),1.0) if calibrated and calibration_enabled else phase
		var pb := fposmod(phase+phase_offsets[segment+1]*calibration_strength(speed_blend),1.0) if calibrated and calibration_enabled else phase
		var qa := a.rotation_track_interpolate(tracks[segment][i],pa*a.length)
		var qb := b.rotation_track_interpolate(tracks[segment+1][i],pb*b.length)
		var goal := qa.slerp(qb,mix_amount).normalized()
		var amplitude := lerpf(1.0,sprint_amplitude,smoothstep(4.4,6.0,speed_blend))
		if amplitude<0.999:
			var neutral := rig.get_bone_rest(ids[i]).basis.orthonormalized().get_rotation_quaternion()
			goal = neutral.slerp(goal,amplitude).normalized()
		var current := rig.get_bone_pose_rotation(ids[i])
		rig.set_bone_pose_rotation(ids[i],current.slerp(goal,weight).normalized())
	if torso_weight>0.0:
		var pa := fposmod(phase+phase_offsets[segment]*calibration_strength(speed_blend),1.0)
		var pb := fposmod(phase+phase_offsets[segment+1]*calibration_strength(speed_blend),1.0)
		for i in range(torso_ids.size()):
			var qa := a.rotation_track_interpolate(torso_tracks[segment][i],pa*a.length)
			var qb := b.rotation_track_interpolate(torso_tracks[segment+1][i],pb*b.length)
			var goal := qa.slerp(qb,mix_amount).normalized()
			var current := rig.get_bone_pose_rotation(torso_ids[i])
			var influence := torso_weight*0.5 if i==2 else torso_weight
			rig.set_bone_pose_rotation(torso_ids[i],current.slerp(goal,influence).normalized())
	sample_count += 1
