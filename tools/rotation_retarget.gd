extends RefCounted
# Offline rotation retargeting. No changes to bone rest, translations, scale or skin.
# Skeleton coordinates differ by an explicitly calibrated proper rotation.
# Godot 4 pose rotations include the bone's rest rotation.
static func retarget_rotation(source_rest: Quaternion, source_pose: Quaternion,
		target_rest: Quaternion, source_to_target: Quaternion) -> Quaternion:
	var change := (source_pose*source_rest.inverse()).normalized()
	return (source_to_target*change*source_to_target.inverse()*target_rest).normalized()

static func rig_basis(rig: Skeleton3D, roles: Dictionary) -> Basis:
	# Infer a right-handed anatomical frame from named shoulders and vertical torso.
	for key in ["left_upperarm","right_upperarm","hips","head"]:
		if not roles.has(key) or rig.find_bone(str(roles[key]))<0:
			return Basis(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO)
	var left := rig.get_bone_global_rest(rig.find_bone(str(roles["left_upperarm"]))).origin
	var right := rig.get_bone_global_rest(rig.find_bone(str(roles["right_upperarm"]))).origin
	var hips := rig.get_bone_global_rest(rig.find_bone(str(roles["hips"]))).origin
	var head := rig.get_bone_global_rest(rig.find_bone(str(roles["head"]))).origin
	var x := (right-left).normalized()
	var up := head-hips
	var y := (up-x*x.dot(up)).normalized()
	var z := x.cross(y).normalized()
	if minf(x.length_squared(),minf(y.length_squared(),z.length_squared()))<0.9:
		return Basis(Vector3.ZERO,Vector3.ZERO,Vector3.ZERO)
	return Basis(x,y,z)

static func calibrate(source: Skeleton3D, target: Skeleton3D, source_roles: Dictionary, target_roles: Dictionary) -> Dictionary:
	var source_frame := rig_basis(source,source_roles)
	var target_frame := rig_basis(target,target_roles)
	if absf(source_frame.determinant()-1.0)>0.01 or absf(target_frame.determinant()-1.0)>0.01:
		return {"ok":false,"error":"Missing or degenerate anatomical frame"}
	var alignment := (target_frame*source_frame.inverse()).orthonormalized().get_rotation_quaternion()
	var pairs: Dictionary = {}
	for role in source_roles:
		if not target_roles.has(role):
			continue
		var from := source.find_bone(str(source_roles[role]))
		var to := target.find_bone(str(target_roles[role]))
		if from<0 or to<0 or pairs.has(to):
			return {"ok":false,"error":"Unknown or duplicate target bone: "+str(role)}
		pairs[to] = from
	return {"ok":true,"alignment":alignment,"pairs":pairs}

static func apply_rotations(source: Skeleton3D, target: Skeleton3D, calibration: Dictionary) -> bool:
	if not calibration.get("ok",false):
		return false
	var alignment: Quaternion = calibration["alignment"]
	var pairs: Dictionary = calibration["pairs"]
	# Parent-first ordering independent of index order; unmapped bones retain rest.
	source.force_update_all_bone_transforms()
	var globals: Dictionary = {}
	var remaining: Array[int] = []
	for i in range(target.get_bone_count()):
		remaining.append(i)
	while not remaining.is_empty():
		var progressed := false
		for i in remaining.duplicate():
			var parent := target.get_bone_parent(i)
			if parent>=0 and not globals.has(parent):
				continue
			var parent_rotation: Quaternion = globals.get(parent,Quaternion.IDENTITY)
			var local := target.get_bone_rest(i).basis.orthonormalized().get_rotation_quaternion()
			if pairs.has(i):
				var j: int = pairs[i]
				var from_rest := source.get_bone_global_rest(j).basis.orthonormalized().get_rotation_quaternion()
				var from_pose := source.get_bone_global_pose(j).basis.orthonormalized().get_rotation_quaternion()
				var to_rest := target.get_bone_global_rest(i).basis.orthonormalized().get_rotation_quaternion()
				var desired := retarget_rotation(from_rest,from_pose,to_rest,alignment)
				local = (parent_rotation.inverse()*desired).normalized()
			target.set_bone_pose_rotation(i,local)
			globals[i] = (parent_rotation*local).normalized()
			remaining.erase(i)
			progressed = true
		if not progressed:
			return false
	target.force_update_all_bone_transforms()
	return true
