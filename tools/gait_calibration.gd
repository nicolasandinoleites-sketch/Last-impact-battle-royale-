extends RefCounted
# Offline calibration: sample the same six bones used by runtime, in actor metres.
# Contact candidates are low ankle positions travelling backwards relative to actor.
const STEPS := 120
const BONES := ["L_Thigh","R_Thigh","L_Calf","R_Calf","L_Foot","R_Foot"]

static func sample(actor: Node3D, clip: Animation) -> Dictionary:
	var rig: Skeleton3D = actor.skeleton
	rig.reset_bone_poses()
	var ids: Array[int] = []
	var tracks: Array[int] = []
	for bone in BONES:
		var id := rig.find_bone(bone)
		var track := clip.find_track(NodePath(".:"+bone),Animation.TYPE_ROTATION_3D)
		if id<0 or track<0:
			return {"valid":false}
		ids.append(id)
		tracks.append(track)
	var feet: Array[PackedVector3Array] = [PackedVector3Array(),PackedVector3Array()]
	for k in range(STEPS):
		for i in range(ids.size()):
			rig.set_bone_pose_rotation(ids[i],clip.rotation_track_interpolate(tracks[i],clip.length*float(k)/STEPS))
		rig.force_update_all_bone_transforms()
		for side in range(2):
			var p := actor.to_local(rig.to_global(rig.get_bone_global_pose(ids[4+side]).origin))
			var points := feet[side]
			points.append(p)
			feet[side] = points
	rig.reset_bone_poses()
	rig.force_update_all_bone_transforms()
	var stance := PackedFloat64Array()
	var masks: Array = []
	var offset := 0.0
	var left_contacts := 0
	for side in range(2):
		var points := feet[side]
		var min_y := INF
		var max_y := -INF
		for p in points:
			min_y = minf(min_y,p.y)
			max_y = maxf(max_y,p.y)
		var threshold := min_y+maxf(0.025,(max_y-min_y)*0.28)
		var mask := PackedFloat32Array()
		var best := INF
		for k in range(STEPS):
			var prev := points[posmod(k-1,STEPS)]
			var next := points[(k+1)%STEPS]
			var velocity := (next-prev)*float(STEPS)*0.5
			var contact := points[k].y<=threshold and velocity.z>0.15
			mask.append(1.0 if contact else 0.0)
			if contact:
				stance.append(velocity.z)
				if side==0:
					left_contacts += 1
				if side==0 and points[k].z<best:
					best = points[k].z
					offset = float(k)/STEPS
		masks.append(mask)
	if stance.size()<12 or left_contacts<6:
		return {"valid":false,"samples":stance.size()}
	stance.sort()
	var travel := stance[floori(float(stance.size())/2.0)]
	return {"valid":is_finite(travel) and travel>0.35 and travel<8.0,"phase_offset":offset,"travel_m_per_cycle":travel,"contact_samples":stance.size(),"left_mask":masks[0],"right_mask":masks[1]}
