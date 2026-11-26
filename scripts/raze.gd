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
var finger_axes: Dictionary = {}
var foot_ids: Array[int] = []
var foot_rest_height := 0.0
var ankle_rest: Dictionary = {}
var foot_ik_active := false
var foot_ik_error := 0.0
var gait_heading := Vector3.FORWARD
var gait_weight := 0.0
var ankle_basis: Dictionary = {}
var visual_ground_error := 0.0
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
				if OS.has_feature("android") or OS.get_environment("LASTIMPACT_SAFE_RENDER")=="1":
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
	prepare_fingers()
	for name in ["L_ToeBase","R_ToeBase"]:
		var id := skeleton.find_bone(name)
		if id>=0:
			foot_ids.append(id)
	skeleton.force_update_all_bone_transforms()
	foot_rest_height = foot_height()
	for side in ["L","R"]:
		var id := skeleton.find_bone(side+"_Foot")
		if id>=0:
			ankle_rest[side] = to_local(skeleton.to_global(skeleton.get_bone_global_pose(id).origin))
			ankle_basis[side] = global_transform.basis.orthonormalized().inverse()*skeleton.global_transform.basis.orthonormalized()*skeleton.get_bone_global_pose(id).basis.orthonormalized()
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

func reset_locomotion() -> void:
	if not ready_model:
		return
	if preview_dance:
		dance()
	cycle = 0.0
	clock = 0.0
	speed_blend = 0.0
	landing = 0.0
	was_grounded = true
	gait_heading = Vector3.FORWARD
	gait_weight = 0.0
	foot_ik_active = false
	foot_ik_error = 0.0
	visual_ground_error = 0.0
	motion_state = "IDLE"
	model.position = Vector3.ZERO
	for joint in JOINTS:
		offsets[joint] = Vector3.ZERO
		var id: int = joints[joint]
		skeleton.set_bone_pose_rotation(id,base[id])
	skeleton.force_update_all_bone_transforms()

# Re-enter leg IK gradually when movement reverses rather than dragging a planted
# foot through the opposite stride. Ordinary directional changes stay continuous.
func update_gait_heading(heading: Vector3, delta: float) -> void:
	if heading.length_squared()<0.01:
		return
	var next := heading.normalized()
	if gait_weight<=0.0 or gait_heading.dot(next)<-0.35:
		gait_heading = next
		gait_weight = 0.0
	else:
		var smoothed := gait_heading.lerp(next,1.0-exp(-delta*18.0))
		gait_heading = smoothed.normalized() if smoothed.length_squared()>0.01 else next

func locomotion(delta: float, speed: float, grounded: bool, low: bool, combat: bool, sprinting: bool = false, vertical_speed: float = 0.0, local_motion: Vector2 = Vector2.ZERO) -> void:
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
	var cadence := gait_cadence(speed,fast)
	if moving and grounded and not low:
		cycle = fposmod(cycle+delta*TAU*cadence,TAU)
	var stride := sin(cycle)
	var strafe := 0.0
	var backward := 1.0
	if local_motion.length()>0.18:
		strafe = clampf(local_motion.x/local_motion.length(),-1.0,1.0)
		backward = -1.0 if local_motion.y>0.2 else 1.0
	var amplitude := minf(1.0,speed_blend*1.65)
	var flex := 38.0 if fast else 24.0
	var left := -stride*flex*amplitude*backward*(1.0-0.45*absf(strafe))
	var right := stride*flex*amplitude*backward*(1.0-0.45*absf(strafe))
	var lk := maxf(0.0,stride)*(54.0 if fast else 37.0)*amplitude
	var rk := maxf(0.0,-stride)*(54.0 if fast else 37.0)*amplitude
	var la := -left*0.6
	var ra := -right*0.6
	var lean := (15.0 if fast else 5.0)*speed_blend
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
		left = -70.0
		right = -78.0
		lk = 25.0
		rk = 98.0
		la = 27.0
		ra = -12.0
		lean = -31.0
		height = -0.54
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
	bone_motion("L_Thigh",Vector3(left,0,strafe*stride*10.0*amplitude if grounded and not low else 0.0),blend)
	bone_motion("R_Thigh",Vector3(right,0,-strafe*stride*10.0*amplitude if grounded and not low else 0.0),blend)
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
	# Align the lowest toe marker to its calibrated rest height on flat training ground.
	if grounded and not foot_ids.is_empty():
		skeleton.force_update_all_bone_transforms()
		var measured := foot_height()
		height = clampf(model.position.y+foot_rest_height-measured,-0.72,0.20)
	model.position.y = lerpf(model.position.y,height,blend)
	foot_ik_active = grounded and not low and landing<=0.0 and moving and local_motion.length()>0.18 and ankle_rest.size()==2
	foot_ik_error = 0.0
	if foot_ik_active:
		var heading := Vector3(local_motion.x,0.0,local_motion.y).normalized()
		update_gait_heading(heading,delta)
		gait_weight = minf(1.0,gait_weight+delta*9.0)
		var half_step := gait_half_step(speed,cadence,fast)
		# Maintain a small knee reserve rather than asking both legs to fully extend.
		model.position.y = lerpf(model.position.y,minf(model.position.y,-0.035),blend)
		for side in ["L","R"]:
			var p := fposmod(cycle/TAU+(0.5 if side=="R" else 0.0),1.0)
			var goal := gait_goal(side,p,gait_heading,half_step,fast)
			var id := skeleton.find_bone(side+"_Foot")
			var current := skeleton.to_global(skeleton.get_bone_global_pose(id).origin)
			var blended_goal := current.lerp(to_global(goal),gait_weight)
			foot_ik_error = maxf(foot_ik_error,solve_leg(side,blended_goal,global_transform.basis*Vector3.FORWARD))
			align_ankle(side,gait_weight*(1.0 if p<(0.54 if fast else 0.62) else 0.65))
	else:
		gait_weight = 0.0
	visual_ground_error = absf(foot_height()-foot_rest_height) if grounded else 0.0

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

# Analytical two-bone positional IK in skeleton coordinates, preserving segment lengths.
func rotate_bone_toward(id: int, from: Vector3, to: Vector3) -> void:
	if from.length_squared()<0.000001 or to.length_squared()<0.000001:
		return
	var change := Quaternion(from.normalized(),to.normalized())
	var parent_id := skeleton.get_bone_parent(id)
	var parent_rot := Quaternion.IDENTITY
	if parent_id>=0:
		parent_rot = skeleton.get_bone_global_pose(parent_id).basis.orthonormalized().get_rotation_quaternion()
	var current := skeleton.get_bone_pose_rotation(id)
	skeleton.set_bone_pose_rotation(id,(parent_rot.inverse()*change*parent_rot*current).normalized())
	skeleton.force_update_all_bone_transforms()

func solve_arm(side: String, world_goal: Vector3, world_pole: Vector3) -> float:
	if not ready_model:
		return 0.0
	var upper := skeleton.find_bone(side+"_Upperarm")
	var fore := skeleton.find_bone(side+"_Forearm")
	var hand := skeleton.find_bone(side+"_Hand")
	if mini(upper,mini(fore,hand))<0:
		return 999.0
	skeleton.force_update_all_bone_transforms()
	var goal := skeleton.to_local(world_goal)
	var a := skeleton.get_bone_global_pose(upper).origin
	var b := skeleton.get_bone_global_pose(fore).origin
	var c := skeleton.get_bone_global_pose(hand).origin
	var l1 := a.distance_to(b)
	var l2 := b.distance_to(c)
	var dir := (goal-a).normalized()
	if dir.length_squared()<0.5 or minf(l1,l2)<0.001:
		return 999.0
	var d := clampf(a.distance_to(goal),absf(l1-l2)+0.001,l1+l2-0.001)
	var pole := skeleton.global_transform.basis.inverse()*world_pole
	pole = pole-dir*dir.dot(pole)
	if pole.length_squared()<0.0001:
		pole = dir.cross(Vector3.RIGHT)
	if pole.length_squared()<0.0001:
		pole = dir.cross(Vector3.UP)
	pole = pole.normalized()
	var along := (l1*l1+d*d-l2*l2)/(2.0*d)
	var elbow := a+dir*along+pole*sqrt(maxf(0.0,l1*l1-along*along))
	rotate_bone_toward(upper,b-a,elbow-a)
	b = skeleton.get_bone_global_pose(fore).origin
	c = skeleton.get_bone_global_pose(hand).origin
	rotate_bone_toward(fore,c-b,a+dir*d-b)
	return skeleton.to_global(skeleton.get_bone_global_pose(hand).origin).distance_to(world_goal)

func arm_reach_correction(side: String, world_goal: Vector3) -> Vector3:
	var upper := skeleton.find_bone(side+"_Upperarm")
	var fore := skeleton.find_bone(side+"_Forearm")
	var hand := skeleton.find_bone(side+"_Hand")
	if mini(upper,mini(fore,hand))<0:
		return Vector3.ZERO
	var a := skeleton.to_global(skeleton.get_bone_global_pose(upper).origin)
	var b := skeleton.to_global(skeleton.get_bone_global_pose(fore).origin)
	var c := skeleton.to_global(skeleton.get_bone_global_pose(hand).origin)
	var reach := a.distance_to(b)+b.distance_to(c)-0.012
	var diff := world_goal-a
	return -diff.normalized()*maxf(0.0,diff.length()-reach)

func prepare_fingers() -> void:
	# Infer the natural flexion plane from each finger's existing rest curvature.
	for side in ["L","R"]:
		for digit in ["Index","Mid","Ring","Pinky"]:
			var one := skeleton.find_bone(side+"_"+digit+"1")
			var two := skeleton.find_bone(side+"_"+digit+"2")
			var three := skeleton.find_bone(side+"_"+digit+"3")
			if mini(one,mini(two,three))<0:
				continue
			var a := skeleton.get_bone_global_rest(one).origin
			var b := skeleton.get_bone_global_rest(two).origin
			var c := skeleton.get_bone_global_rest(three).origin
			var bend := (b-a).cross(c-b)
			if bend.length_squared()<0.0000000001:
				continue
			for id in [one,two,three]:
				finger_axes[id] = skeleton.get_bone_global_rest(id).basis.orthonormalized().inverse()*bend.normalized()

func close_fingers(strength: float, left_strength: float = -1.0) -> void:
	if preview_dance:
		return
	for id in finger_axes:
		var axis: Vector3 = finger_axes[id]
		var rest: Quaternion = base[id]
		var name := skeleton.get_bone_name(id)
		var angle := 0.14 if name.ends_with("3") else 0.20
		var grip := left_strength if name.begins_with("L_") and left_strength>=0.0 else strength
		skeleton.set_bone_pose_rotation(id,(rest*Quaternion(axis.normalized(),angle*clampf(grip,0.0,1.0))).normalized())

func foot_height() -> float:
	if foot_ids.is_empty():
		return 0.0
	var result := INF
	for id in foot_ids:
		var p := to_local(skeleton.to_global(skeleton.get_bone_global_pose(id).origin))
		result = minf(result,p.y)
	return result

# Direction-aware foot trajectory: stance moves backward relative to body, swing lifts.
func gait_goal(side: String,p: float,heading: Vector3,half_step: float,fast: bool) -> Vector3:
	var rest: Vector3 = ankle_rest[side]
	var duty := 0.54 if fast else 0.62
	var travel: float
	var lift := 0.0
	if p<duty:
		travel = lerpf(half_step,-half_step,p/duty)
	else:
		var swing := (p-duty)/(1.0-duty)
		travel = lerpf(-half_step,half_step,smoothstep(0.0,1.0,swing))
		lift = sin(swing*PI)*(0.15 if fast else 0.09)
	return rest+heading*travel+Vector3.UP*lift

func solve_leg(side: String,world_goal: Vector3,world_pole: Vector3) -> float:
	var thigh := skeleton.find_bone(side+"_Thigh")
	var calf := skeleton.find_bone(side+"_Calf")
	var foot := skeleton.find_bone(side+"_Foot")
	if mini(thigh,mini(calf,foot))<0:
		return 1.0
	skeleton.force_update_all_bone_transforms()
	var a := skeleton.get_bone_global_pose(thigh).origin
	var b := skeleton.get_bone_global_pose(calf).origin
	var c := skeleton.get_bone_global_pose(foot).origin
	var goal := skeleton.to_local(world_goal)
	var l1 := a.distance_to(b)
	var l2 := b.distance_to(c)
	var dir := (goal-a).normalized()
	if minf(l1,l2)<0.001 or dir.length_squared()<0.5:
		return 1.0
	var d := clampf(a.distance_to(goal),absf(l1-l2)+0.001,l1+l2-0.001)
	var pole := skeleton.global_transform.basis.inverse()*world_pole
	pole -= dir*dir.dot(pole)
	if pole.length_squared()<0.0001:
		pole = dir.cross(Vector3.RIGHT)
	if pole.length_squared()<0.0001:
		pole = dir.cross(Vector3.UP)
	var along := (l1*l1+d*d-l2*l2)/(2.0*d)
	var knee := a+dir*along+pole.normalized()*sqrt(maxf(0.0,l1*l1-along*along))
	rotate_bone_toward(thigh,b-a,knee-a)
	b = skeleton.get_bone_global_pose(calf).origin
	c = skeleton.get_bone_global_pose(foot).origin
	rotate_bone_toward(calf,c-b,a+dir*d-b)
	return skeleton.to_global(skeleton.get_bone_global_pose(foot).origin).distance_to(world_goal)

# For unclamped strides, the stance trajectory cancels the actor's nominal travel.
# Cadence is a complete stride cycle; stance distance must fit within the leg reach budget.
const GAIT_MAX_HALF_STEP := 0.36
func gait_cadence(speed: float,fast: bool) -> float:
	var duty := 0.54 if fast else 0.62
	var nominal := speed/(2.0*GAIT_MAX_HALF_STEP/duty)
	return clampf(nominal,1.15 if fast else 0.85,3.2 if fast else 2.8)

func gait_half_step(speed: float,cadence: float,fast: bool) -> float:
	var duty := 0.54 if fast else 0.62
	return clampf(speed*duty/(2.0*maxf(cadence,0.01)),0.0,GAIT_MAX_HALF_STEP)

func align_ankle(side: String,weight: float) -> void:
	if not ankle_basis.has(side):
		return
	var id := skeleton.find_bone(side+"_Foot")
	var parent_id := skeleton.get_bone_parent(id)
	if parent_id<0:
		return
	var rest_basis: Basis = ankle_basis[side]
	var world_basis := global_transform.basis.orthonormalized()*rest_basis
	var local_basis := skeleton.global_transform.basis.orthonormalized().inverse()*world_basis
	var parent_basis := skeleton.get_bone_global_pose(parent_id).basis.orthonormalized()
	var goal := (parent_basis.inverse()*local_basis).get_rotation_quaternion()
	var current := skeleton.get_bone_pose_rotation(id)
	skeleton.set_bone_pose_rotation(id,current.slerp(goal,clampf(weight,0.0,1.0)).normalized())
