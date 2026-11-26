extends SceneTree
const Transfer = preload("res://tools/rotation_retarget.gd")
const GaitCalibration = preload("res://tools/gait_calibration.gd")
const SOURCE := "/tmp/ual_source.glb"
const OUT := "/tmp/lastimpact_retarget"
const SOURCE_ROLES := {"hips":"pelvis","spine1":"spine_01","spine2":"spine_02","spine3":"spine_03","neck":"neck_01","head":"Head","left_upperarm":"upperarm_l","right_upperarm":"upperarm_r","left_forearm":"lowerarm_l","right_forearm":"lowerarm_r","left_hand":"hand_l","right_hand":"hand_r","left_shoulder":"clavicle_l","right_shoulder":"clavicle_r","left_thigh":"thigh_l","right_thigh":"thigh_r","left_calf":"calf_l","right_calf":"calf_r","left_foot":"foot_l","right_foot":"foot_r","left_toe":"ball_l","right_toe":"ball_r"}
# Hip is the common ancestor of Pelvis and Waist in the audited RAZE hierarchy.
const TARGET_ROLES := {"hips":"Hip","spine1":"Waist","spine2":"Spine01","spine3":"Spine02","neck":"NeckTwist01","head":"Head","left_upperarm":"L_Upperarm","right_upperarm":"R_Upperarm","left_forearm":"L_Forearm","right_forearm":"R_Forearm","left_hand":"L_Hand","right_hand":"R_Hand","left_shoulder":"L_Clavicle","right_shoulder":"R_Clavicle","left_thigh":"L_Thigh","right_thigh":"R_Thigh","left_calf":"L_Calf","right_calf":"R_Calf","left_foot":"L_Foot","right_foot":"R_Foot","left_toe":"L_ToeBase","right_toe":"R_ToeBase"}
const CLIPS := ["Idle_Loop","Walk_Loop","Jog_Fwd_Loop","Sprint_Loop","Crouch_Idle_Loop","Crouch_Fwd_Loop","Jump_Start","Jump_Loop","Jump_Land"]

func _initialize() -> void:
	call_deferred("run")

func fail(message: String) -> void:
	push_error("TEST FAILED: retarget preview "+message)
	quit(1)

func run() -> void:
	root.size = Vector2i(960,540)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(SOURCE,state)!=OK:
		fail("cannot import audited source")
		return
	var source_model := document.generate_scene(state) as Node3D
	if source_model==null:
		fail("source scene absent")
		return
	root.add_child(source_model)
	source_model.hide()
	var rigs := source_model.find_children("*","Skeleton3D",true,false)
	var players := source_model.find_children("*","AnimationPlayer",true,false)
	if rigs.is_empty() or players.is_empty():
		fail("missing source rig or player")
		return
	var source := rigs[0] as Skeleton3D
	var source_player := players[0] as AnimationPlayer
	source_player.stop()
	source.reset_bone_poses()
	var actor = preload("res://scripts/raze.gd").new()
	root.add_child(actor)
	if not actor.load_model():
		fail("RAZE failed to load")
		return
	var target: Skeleton3D = actor.skeleton
	target.reset_bone_poses()
	var calibration := Transfer.calibrate(source,target,SOURCE_ROLES,TARGET_ROLES)
	if not calibration["ok"]:
		fail(str(calibration))
		return
	if not Transfer.apply_rotations(source,target,calibration):
		fail("neutral transfer")
		return
	for i in range(target.get_bone_count()):
		if absf(target.get_bone_pose_rotation(i).dot(target.get_bone_rest(i).basis.orthonormalized().get_rotation_quaternion()))<0.999:
			fail("neutral pose "+target.get_bone_name(i))
			return
	var library := AnimationLibrary.new()
	var report: Array[Dictionary] = []
	for clip_name in CLIPS:
		if not source_player.has_animation(clip_name):
			fail("missing audited clip "+clip_name)
			return
		var original := source_player.get_animation(clip_name)
		var result := Animation.new()
		result.length = original.length
		result.loop_mode = Animation.LOOP_LINEAR if clip_name.ends_with("_Loop") else Animation.LOOP_NONE
		var tracks: Dictionary = {}
		for i in calibration["pairs"]:
			var track := result.add_track(Animation.TYPE_ROTATION_3D)
			result.track_set_path(track,NodePath(".:"+target.get_bone_name(i)))
			tracks[i] = track
		var count := maxi(2,ceili(original.length*30.0))
		source_player.play(clip_name)
		for tick in range(count+1):
			var t := original.length*float(tick)/float(count)
			source_player.seek(minf(t,maxf(0.0,original.length-0.0001)),true)
			if not Transfer.apply_rotations(source,target,calibration):
				fail("sample "+clip_name)
				return
			for i in tracks:
				var q := target.get_bone_pose_rotation(i)
				if not q.is_finite():
					fail("nonfinite rotation "+clip_name)
					return
				result.rotation_track_insert_key(tracks[i],t,q)
		source_player.stop()
		library.add_animation(clip_name,result)
		report.append({"clip":clip_name,"seconds":original.length,"rotation_tracks":tracks.size(),"samples":count+1})
	# Align the clips using measured ankle trajectories on the actual retargeted rig.
	var gait_report: Dictionary = {}
	for clip_name in ["Walk_Loop","Jog_Fwd_Loop","Sprint_Loop"]:
		var clip := library.get_animation(clip_name)
		var data := GaitCalibration.sample(actor,clip)
		gait_report[clip_name] = data
		if data.get("valid",false):
			clip.set_meta("gait_phase_offset",data["phase_offset"])
			clip.set_meta("gait_travel_m",data["travel_m_per_cycle"])
			clip.set_meta("gait_contact_samples",data["contact_samples"])
			clip.set_meta("gait_left_mask",data["left_mask"])
			clip.set_meta("gait_right_mask",data["right_mask"])
		print("GAIT CALIBRATION ",clip_name," | ",JSON.stringify(data))
	var gait_file := FileAccess.open(OUT+"/gait_calibration.json",FileAccess.WRITE)
	if gait_file==null:
		fail("gait calibration report")
		return
	gait_file.store_string(JSON.stringify(gait_report,"  "))
	gait_file.close()
	# Experimental library only. No imported asset or runtime code is overwritten.
	if ResourceSaver.save(library,OUT+"/raze_experimental.tres")!=OK:
		fail("cannot save library")
		return
	var output := FileAccess.open(OUT+"/bake_report.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"source_bones":source.get_bone_count(),"target_bones":target.get_bone_count(),"clips":report},"  "))
	output.close()
	var preview_player := AnimationPlayer.new()
	target.add_child(preview_player)
	preview_player.root_node = NodePath("..")
	preview_player.add_animation_library("",library)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("24323a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 1.0
	world.environment = environment
	root.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45,-35,0)
	root.add_child(light)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(2.7,1.4,-2.7)
	camera.look_at(Vector3(0,0.92,0))
	camera.fov = 40.0
	camera.current = true
	for clip_name in CLIPS:
		preview_player.play(clip_name)
		preview_player.pause()
		for frame in range(4):
			preview_player.seek(library.get_animation(clip_name).length*float(frame)/4.0,true)
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			if image==null or image.is_empty() or image.save_png(OUT+"/"+clip_name+"_%d.png" % frame)!=OK:
				fail("capture "+clip_name)
				return
	print("RAZE RETARGET PREVIEW COMPLETE | clips=",report.size()," mapped=",calibration["pairs"].size())
	quit(0)
