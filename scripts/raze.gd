extends Node3D
const MODEL := "res://assets/tripo/raze.glb"
var model: Node3D
var skeleton: Skeleton3D
var animator: AnimationPlayer
var base: Dictionary = {}
var ready_model := false
var preview_dance := false
var motion_state := "IDLE"
var armed := false
var cycle := 0.0
var clock := 0.0
var speed_blend := 0.0
var landing := 0.0
var was_grounded := true
var axes: Dictionary = {}
var joints: Dictionary = {}
var offsets: Dictionary = {}
var right_socket: BoneAttachment3D
var left_socket: BoneAttachment3D
const JOINTS = ["L_Thigh","R_Thigh","L_Calf","R_Calf","L_Foot","R_Foot","L_Upperarm","R_Upperarm","L_Forearm","R_Forearm","Waist","Spine01","Spine02","Head"]


func load_model() -> bool:
	if not ResourceLoader.exists(MODEL):
		return false
	var asset := load(MODEL) as PackedScene
	if asset == null:
		return false
	model = asset.instantiate() as Node3D
	if model == null:
		return false
	add_child(model)
	model.scale = Vector3.ONE * 1.8
	model.rotation.y = PI
	var skeletons := model.find_children("*","Skeleton3D",true,false)
	var animators := model.find_children("*","AnimationPlayer",true,false)
	if skeletons.is_empty():
		model.queue_free()
		return false
	skeleton = skeletons[0] as Skeleton3D
	if not animators.is_empty():
		animator = animators[0] as AnimationPlayer
		animator.stop()
	for i in range(skeleton.get_bone_count()):
		base[i] = skeleton.get_bone_pose_rotation(i)
	for child in model.find_children("*","MeshInstance3D",true,false):
		var mesh_node := child as MeshInstance3D
		for i in range(mesh_node.mesh.get_surface_count()):
			var original := mesh_node.get_active_material(i) as StandardMaterial3D
			if original != null:
				var material := original.duplicate() as StandardMaterial3D
				if OS.has_feature("android"):
					material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mesh_node.set_surface_override_material(i,material)
	for joint in JOINTS:
		var id: int = skeleton.find_bone(joint)
		if id < 0:
			push_error("RAZE missing bone: " + joint)
			return false
		joints[joint] = id
		axes[joint] = skeleton.get_bone_global_rest(id).basis.orthonormalized().inverse()
		offsets[joint] = Vector3.ZERO
	right_socket = BoneAttachment3D.new()
	right_socket.name = "RightHandSocket"
	right_socket.bone_name = "R_Hand"
	skeleton.add_child(right_socket)
	left_socket = BoneAttachment3D.new()
	left_socket.name = "LeftHandSocket"
	left_socket.bone_name = "L_Hand"
	skeleton.add_child(left_socket)
	ready_model = true
	return true

func bone_motion(joint: String, degrees: Vector3, blend: float) -> void:
	var id: int = joints[joint]
	var current: Vector3 = offsets[joint]
	current = current.lerp(degrees,blend)
	offsets[joint] = current
	var axis_map: Basis = axes[joint]
	var rest: Quaternion = base[id]
	var qx := Quaternion((axis_map * Vector3.RIGHT).normalized(),deg_to_rad(current.x))
	var qy := Quaternion((axis_map * Vector3.UP).normalized(),deg_to_rad(current.y))
	var qz := Quaternion((axis_map * Vector3.BACK).normalized(),deg_to_rad(current.z))
	skeleton.set_bone_pose_rotation(id,(rest * qx * qy * qz).normalized())

func locomotion(delta: float, speed: float, grounded: bool, low: bool, combat: bool, sprinting: bool = false, vertical_speed: float = 0.0) -> void:
	if not ready_model or preview_dance:
		return
	clock += delta
	if grounded and not was_grounded:
		landing = 0.22
	was_grounded = grounded
	landing = maxf(0.0,landing-delta)
	speed_blend = lerpf(speed_blend,clampf(speed/6.2,0.0,1.0),1.0-exp(-delta*10.0))
	var moving := speed > 0.18
	var fast := sprinting and speed > 4.2 and not combat
	var cadence := lerpf(1.25,2.25,speed_blend)
	if moving and grounded and not low:
		cycle = fposmod(cycle+delta*TAU*cadence,TAU)
	var stride := sin(cycle)
	var amplitude := minf(1.0,speed_blend*1.65)
	var flex := 28.0 if fast else 19.0
	var left := -stride*flex*amplitude
	var right := stride*flex*amplitude
	var lk := maxf(0.0,stride)*33.0*amplitude
	var rk := maxf(0.0,-stride)*33.0*amplitude
	var la := -left*0.6
	var ra := -right*0.6
	var lean := -5.0*speed_blend
	var yaw_twist := stride*4.0*amplitude
	var arm_l := right*0.65
	var arm_r := left*0.65
	var elbow_l := -8.0-maxf(0.0,-arm_l)*0.7
	var elbow_r := -8.0-maxf(0.0,-arm_r)*0.7
	var height := -0.012*amplitude+absf(cos(cycle))*0.025*amplitude
	motion_state = "SPRINT" if fast else ("WALK" if moving else "IDLE")
	if not moving:
		left = 0.0
		right = 0.0
		lk = 0.0
		rk = 0.0
		la = 0.0
		ra = 0.0
		yaw_twist = 0.0
		arm_l = 0.0
		arm_r = 0.0
		height = 0.0
	if not grounded:
		motion_state = "JUMP" if vertical_speed > 0.0 else "FALL"
		left = -22.0
		right = -12.0
		lk = 38.0
		rk = 27.0
		la = -12.0
		ra = -8.0
		arm_l = -15.0
		arm_r = -12.0
		height = 0.0
	elif low:
		motion_state = "SLIDE"
		left = -48.0
		right = -28.0
		lk = 82.0
		rk = 57.0
		la = -30.0
		ra = -24.0
		lean = -22.0
		height = -0.28
	elif landing > 0.0:
		motion_state = "LAND"
		var compress := landing/0.22
		left -= 20.0*compress
		right -= 20.0*compress
		lk += 35.0*compress
		rk += 35.0*compress
		height -= 0.10*compress
	if combat and grounded and not low and landing <= 0.0:
		motion_state = "AIM_MOVE" if moving else "AIM"
		arm_l = -38.0
		arm_r = -32.0
		elbow_l = -44.0
		elbow_r = -40.0
		yaw_twist *= 0.25
	if armed and not combat and not low:
		arm_l = -24.0
		arm_r = -20.0
		elbow_l = -30.0
		elbow_r = -35.0
	var blend := 1.0-exp(-delta*14.0)
	var breathe := sin(clock*2.2)*1.4
	bone_motion("L_Thigh",Vector3(left,0,0),blend)
	bone_motion("R_Thigh",Vector3(right,0,0),blend)
	bone_motion("L_Calf",Vector3(lk,0,0),blend)
	bone_motion("R_Calf",Vector3(rk,0,0),blend)
	bone_motion("L_Foot",Vector3(la,0,0),blend)
	bone_motion("R_Foot",Vector3(ra,0,0),blend)
	bone_motion("L_Upperarm",Vector3(arm_l,0,-7 if combat else 0),blend)
	bone_motion("R_Upperarm",Vector3(arm_r,0,7 if combat else 0),blend)
	bone_motion("L_Forearm",Vector3(elbow_l,0,0),blend)
	bone_motion("R_Forearm",Vector3(elbow_r,0,0),blend)
	bone_motion("Waist",Vector3(lean*0.5,yaw_twist,0),blend)
	bone_motion("Spine01",Vector3(lean*0.5+breathe,-yaw_twist*0.5,0),blend)
	bone_motion("Spine02",Vector3(breathe,-yaw_twist*0.5,0),blend)
	bone_motion("Head",Vector3(-lean*0.5,0,0),blend)
	model.position.y = lerpf(model.position.y,height,blend)

func dance() -> bool:
	if animator == null:
		return false
	if preview_dance:
		animator.stop()
		for i in range(skeleton.get_bone_count()):
			skeleton.reset_bone_pose(i)
		for joint in JOINTS:
			offsets[joint] = Vector3.ZERO
		model.position = Vector3.ZERO
		preview_dance = false
		motion_state = "IDLE"
		return true
	for name in animator.get_animation_list():
		if String(name).contains("dance"):
			preview_dance = true
			motion_state = "DANCE"
			animator.play(name)
			return true
	return false
