extends SceneTree
const Transfer = preload("res://tools/rotation_retarget.gd")

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> bool:
	if not ok:
		push_error("TEST FAILED: retarget "+label)
		quit(1)
		return false
	print("PASS: retarget "+label)
	return true

func synthetic(prefix: String, angle: float, size: float) -> Skeleton3D:
	var rig := Skeleton3D.new()
	root.add_child(rig)
	var rotation := Basis(Vector3.UP,angle)
	for name in ["hips","head","left_upperarm","right_upperarm","left_forearm"]:
		rig.add_bone(prefix+name)
	for i in range(1,4):
		rig.set_bone_parent(i,0)
	rig.set_bone_parent(4,2)
	rig.set_bone_rest(0,Transform3D(rotation,Vector3.ZERO))
	rig.set_bone_rest(1,Transform3D(Basis.IDENTITY,Vector3(0,size,0)))
	rig.set_bone_rest(2,Transform3D(Basis.IDENTITY,Vector3(-size*0.3,size*0.7,0)))
	rig.set_bone_rest(3,Transform3D(Basis.IDENTITY,Vector3(size*0.3,size*0.7,0)))
	rig.set_bone_rest(4,Transform3D(Basis.IDENTITY,Vector3(-size*0.4,0,0)))
	rig.reset_bone_poses()
	rig.force_update_all_bone_transforms()
	return rig

func roles(prefix: String) -> Dictionary:
	var result := {}
	for name in ["hips","head","left_upperarm","right_upperarm","left_forearm"]:
		result[name]=prefix+name
	return result

func run() -> void:
	var source := synthetic("s_",0.0,1.0)
	var target := synthetic("t_",PI*0.5,1.4)
	var calibration := Transfer.calibrate(source,target,roles("s_"),roles("t_"))
	if not check(calibration["ok"],"different facing and body size"):
		return
	if not check(Transfer.apply_rotations(source,target,calibration),"neutral transfer"):
		return
	for i in range(target.get_bone_count()):
		var q := target.get_bone_pose_rotation(i)
		var rest := target.get_bone_rest(i).basis.get_rotation_quaternion()
		if not check(absf(q.dot(rest))>0.99999,"neutral preserves rest "+str(i)):
			return
	var p := target.get_bone_pose_position(4)
	var scale_before := target.get_bone_pose_scale(4)
	var source_q := Quaternion(Vector3.FORWARD,0.6)
	source.set_bone_pose_rotation(2,source_q)
	if not check(Transfer.apply_rotations(source,target,calibration),"upper arm rotation"):
		return
	var expected: Quaternion = calibration["alignment"]
	var actual := target.get_bone_global_pose(2).basis.get_rotation_quaternion()
	var reference := target.get_bone_global_rest(2).basis.get_rotation_quaternion()
	var goal := expected*source_q*expected.inverse()*reference
	if not check(absf(actual.dot(goal.normalized()))>0.99999,"global rotation matches calibrated motion"):
		return
	if not check(target.get_bone_pose_position(4).is_equal_approx(p) and target.get_bone_pose_scale(4).is_equal_approx(scale_before),"translation and scale preserved"):
		return
	var bad := Transfer.calibrate(source,target,{},roles("t_"))
	if not check(not bad["ok"],"reject missing mapping"):
		return
	print("RETARGET ROTATION FIXTURES PASS")
	quit(0)
