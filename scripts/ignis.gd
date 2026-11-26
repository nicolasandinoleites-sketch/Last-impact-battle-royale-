extends Node3D
const ASSET := "res://assets/tripo/ignis_x1.glb"
var model: Node3D
var anchor: Node3D
var flash: MeshInstance3D
var flash_left := 0.0
var kick := 0.0
var loaded := false
var pulse_count := 0
var reload_phase := 0.0
var facing: Node3D
var actor: Node3D
var right_goal: Marker3D
var left_goal: Marker3D
var aim_pitch := 0.0
var pose_initialized := false
var right_error := 0.0
var left_error := 0.0
func equip(hand: Node3D, body_visual: Node3D) -> bool:
	anchor = hand
	facing = body_visual
	if not ResourceLoader.exists(ASSET):
		return false
	var asset := load(ASSET) as PackedScene
	if asset == null:
		return false
	model = asset.instantiate() as Node3D
	if model == null:
		return false
	add_child(model)
	model.scale = Vector3.ONE
	right_goal = Marker3D.new()
	right_goal.position = Vector3(0,-0.075,0.12)
	model.add_child(right_goal)
	left_goal = Marker3D.new()
	left_goal.position = Vector3(-0.025,-0.045,-0.065)
	model.add_child(left_goal)
	for child in model.find_children("*","MeshInstance3D",true,false):
		var mesh := child as MeshInstance3D
		for i in range(mesh.mesh.get_surface_count()):
			var original := mesh.get_active_material(i) as StandardMaterial3D
			if original != null:
				var mat := original.duplicate() as StandardMaterial3D
				if OS.has_feature("android"):
					mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mesh.set_surface_override_material(i,mat)
	flash = MeshInstance3D.new()
	var shape := SphereMesh.new()
	shape.radius = 0.045
	shape.height = 0.09
	shape.radial_segments = 6
	shape.rings = 3
	flash.mesh = shape
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color("ffd38b")
	flash.material_override = glow
	flash.position = Vector3(0,0.045,-0.34)
	add_child(flash)
	flash.hide()
	loaded = true
	return true

func update_pose(delta: float, aiming: bool, reload: float, low: bool = false, pitch: float = 0.0) -> void:
	if not loaded:
		return
	kick = move_toward(kick,0.0,delta*1.4)
	flash_left = maxf(0.0,flash_left-delta)
	flash.visible = flash_left > 0.0
	reload_phase = reload
	var frame := facing.global_transform.basis.orthonormalized()
	var body_origin := facing.global_position
	var lower := -0.29 if low else 0.0
	var desired := body_origin + frame * Vector3(0.065,1.33+lower,-0.19+kick)
	var tilt := sin(reload*PI) if reload>0.0 else 0.0
	aim_pitch = lerpf(aim_pitch,clampf(pitch,-0.48,0.40) if aiming else -0.18,1.0-exp(-delta*16.0))
	var local_basis := Basis.from_euler(Vector3(aim_pitch,0.0,tilt*0.34))
	global_transform = Transform3D(frame*local_basis,desired)
	flash.position = Vector3(0,0.045,-0.34)
	if is_instance_valid(actor):
		var support := left_goal.global_position
		if reload>0.0:
			support += frame*Vector3(-0.045,-0.10*tilt,0.09*tilt)
		# Shift the shared cosmetic pose minimally toward reachable wrist targets.
		for pass_index in range(2):
			var correction: Vector3 = actor.arm_reach_correction("L",support)
			if correction.length() < 0.002:
				break
			global_position += correction.limit_length(0.045)
			support += correction.limit_length(0.045)
		right_error = actor.solve_arm("R",right_goal.global_position,frame*Vector3(0.65,-0.7,0.25))
		left_error = actor.solve_arm("L",support,frame*Vector3(-0.65,-0.7,0.10))
		actor.close_fingers(clampf(1.0-reload*0.45,0.0,1.0))

func pulse() -> void:
	if not loaded:
		return
	pulse_count += 1
	kick = 0.05
	flash_left = 0.055
	flash.show()

func clear_effects() -> void:
	kick = 0.0
	flash_left = 0.0
	reload_phase = 0.0
	if is_instance_valid(flash):
		flash.hide()
