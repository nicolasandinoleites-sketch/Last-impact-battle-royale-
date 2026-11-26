extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> bool:
	if not ok:
		push_error("TEST FAILED: clips "+label)
		quit(1)
		return false
	print("PASS: clips "+label)
	return true

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	for i in range(15):
		await physics_frame
	var actor = game.player.raze
	var clips = actor.clip_motion
	if not check(clips.available,"packaged library loads all three lower-body cycles"):
		return
	actor.reset_locomotion()
	var original_hand: Vector3 = actor.skeleton.get_bone_pose_position(actor.skeleton.find_bone("R_Hand"))
	var max_error := 0.0
	for speed in [1.8,3.8,6.2]:
		for i in range(72):
			actor.locomotion(1.0/60.0,speed,true,false,false,speed>4.2,0.0,Vector2(0,-speed))
			max_error = maxf(max_error,actor.visual_ground_error)
		if not check(clips.weight>0.9 and clips.sample_count>0 and actor.skeleton.get_bone_pose_rotation(actor.skeleton.find_bone("L_Thigh")).is_finite(),"clip sampled at speed "+str(speed)):
			return
		if not check(clips.active_clip==clips.CLIPS[0 if speed<2.0 else (1 if speed<4.0 else 2)],"correct speed-dependent animation"):
			return
	if not check(max_error<0.35,"bounded contact height"):
		return
	for i in range(45):
		actor.locomotion(1.0/60.0,2.8,true,false,true,false,0.0,Vector2(2.8,0))
	if not check(clips.weight==0.0 and actor.foot_ik_active,"aimed strafe returns to directional procedural IK"):
		return
	if not check(actor.skeleton.get_bone_pose_position(actor.skeleton.find_bone("R_Hand")).is_equal_approx(original_hand),"hand translation preserved"):
		return
	game.reset_round()
	game.mobile_move = Vector2(0,-1)
	for i in range(45):
		await physics_frame
	if not check(clips.weight>0.5 and clips.sample_count>0,"real player movement invokes imported clip mixer"):
		return
	if not check(maxf(game.player.weapon.right_error,game.player.weapon.left_error)<0.08,"weapon grip remains within 8 cm during walk"):
		return
	if not check(clips.torso_weight>0.20 and clips.torso_weight<=0.40,"imported spine layer active during walk"):
		return
	var weapon = game.player.weapon
	var min_y := INF
	var max_y := -INF
	var max_grip := 0.0
	for i in range(60):
		await physics_frame
		min_y = minf(min_y,weapon.carry_sway.y)
		max_y = maxf(max_y,weapon.carry_sway.y)
		max_grip = maxf(max_grip,maxf(weapon.left_error,weapon.right_error))
	if not check(max_y-min_y>0.002 and max_grip<0.08,"phase-linked carry motion with bounded grip error"):
		return
	game.player.aiming = true
	for i in range(45):
		await physics_frame
	if not check(clips.torso_weight==0.0 and weapon.carry_sway==Vector3.ZERO and is_zero_approx(weapon.carry_roll),"ADS disables imported torso and cosmetic carry sway"):
		return
	game.reset_round()
	if not check(clips.torso_weight==0.0 and weapon.carry_sway==Vector3.ZERO,"reset clears torso and carry"):
		return
	# Exercise the new stance through the real HUD command and physics.
	for i in range(8):
		await physics_frame
	game.hud.press_button("CROUCH",0)
	for i in range(45):
		await physics_frame
	if not check(actor.crouch_motion.available and actor.crouch_motion.weight>0.95 and game.player.crouched and game.player.capsule.height<1.2 and actor.motion_state=="CROUCH","crouch button lowers collision and activates idle clip"):
		return
	game.mobile_move = Vector2(0,-1)
	game.mobile_sprint = true
	for i in range(45):
		await physics_frame
	if not check(actor.motion_state=="CROUCH_MOVE" and actor.crouch_motion.stride_blend>0.8 and game.player.animation_speed<=2.05,"crouch walk clip and speed cap"):
		return
	if not check(actor.visual_ground_error<0.15 and maxf(weapon.right_error,weapon.left_error)<0.08,"crouch toe and grip budgets"):
		return
	game.mobile_move = Vector2.ZERO
	game.mobile_sprint = false
	for i in range(20):
		await physics_frame
	var roof := StaticBody3D.new()
	roof.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0,0.2,3.0)
	shape.shape = box
	roof.add_child(shape)
	game.add_child(roof)
	roof.global_position = game.player.global_position+Vector3.UP*1.45
	for i in range(4):
		await physics_frame
	game.hud.press_button("CROUCH",0)
	for i in range(15):
		await physics_frame
	if not check(game.player.crouched and not game.player.crouch_requested,"low ceiling prevents standing"):
		return
	roof.queue_free()
	for i in range(45):
		await physics_frame
	if not check(not game.player.low_stance and actor.crouch_motion.weight==0.0,"standing resumes when ceiling clears"):
		return
	game.reset_round()
	if not check(not game.player.crouched and actor.crouch_motion.samples==0,"round reset clears crouch"):
		return
	print("CROUCH GAMEPLAY PASS")
	print("UPPER BODY PASS | carry_y_range=",max_y-min_y," max_grip=",max_grip)
	print("RAZE CLIP GAMEPLAY PASS | max_toe_error=",max_error," grip=",game.player.weapon.right_error,"/",game.player.weapon.left_error)
	quit(0)
