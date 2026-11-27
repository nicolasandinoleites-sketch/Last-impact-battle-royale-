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
var sprint_pose := 0.0
var carry_sway := Vector3.ZERO
var carry_roll := 0.0
var right_error := 0.0
var left_error := 0.0
var energy_cell: Node3D
var cell_stage := "DOCKED"
var cell_dock := Vector3(-0.075,-0.035,0.015)
var cell_path := Vector3.ZERO
var reload_progress := 0.0
var base_tints: Dictionary = {}
var accessories: Dictionary = {}
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
				if OS.has_feature("android") or OS.get_environment("LASTIMPACT_SAFE_RENDER")=="1":
					mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				mesh.set_surface_override_material(i,mat)
				base_tints[mat] = mat.albedo_color
	build_energy_cell()
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
	build_accessories()
	loaded = true
	return true

func update_pose(delta: float, aiming: bool, reload: float, low: bool = false, pitch: float = 0.0) -> void:
	if not loaded:
		return
	kick = move_toward(kick,0.0,delta*1.4)
	flash_left = maxf(0.0,flash_left-delta)
	flash.visible = flash_left > 0.0
	reload_phase = reload
	update_reload_cell(reload)
	var frame := facing.global_transform.basis.orthonormalized()
	var body_origin := facing.global_position
	var lower := -0.48 if low else 0.0
	if is_instance_valid(actor):
		lower = actor.model.position.y if low else actor.model.position.y*0.55
	# Sway only during free locomotion; ADS, shots and reload use the stable pose.
	var free_carry: bool = is_instance_valid(actor) and not aiming and reload<=0.0 and not low and actor.clip_motion.available and actor.clip_motion.weight>0.05
	var sway_target := Vector3.ZERO
	var roll_target := 0.0
	if free_carry:
		var angle: float = actor.clip_motion.phase*TAU
		var amount: float = actor.clip_motion.weight*clampf(actor.speed_blend,0.0,1.0)
		sway_target = Vector3(sin(angle)*0.018,cos(angle*2.0)*0.015,sin(angle+PI*0.25)*0.012)*amount
		roll_target = sin(angle)*0.035*amount
	if aiming or reload>0.0 or low:
		carry_sway = Vector3.ZERO
		carry_roll = 0.0
	else:
		carry_sway = carry_sway.lerp(sway_target,1.0-exp(-delta*16.0))
		carry_roll = lerpf(carry_roll,roll_target,1.0-exp(-delta*16.0))
	var desired := body_origin + frame * (Vector3(0.065,1.33+lower,-0.19+kick)+carry_sway)
	var tilt := sin(reload*PI) if reload>0.0 else 0.0
	aim_pitch = lerpf(aim_pitch,clampf(pitch,-0.48,0.40) if aiming else -0.18,1.0-exp(-delta*16.0))
	var sprint_target := 1.0 if is_instance_valid(actor) and actor.motion_state=="SPRINT" and not aiming and reload<=0.0 else 0.0
	sprint_pose = lerpf(sprint_pose,sprint_target,1.0-exp(-delta*10.0))
	var sprint_tilt := -0.24*sprint_pose
	var local_basis := Basis.from_euler(Vector3(aim_pitch-tilt*0.15+sprint_tilt,0.0,tilt*0.50+carry_roll))
	global_transform = Transform3D(frame*local_basis,desired)
	flash.position = Vector3(0,0.045,-0.34)
	if is_instance_valid(actor):
		var support := left_goal.global_position
		if reload>0.0:
			var cell_goal := to_global(cell_path+Vector3(-0.025,-0.025,0.0))
			var influence := smoothstep(0.0,0.16,reload_progress)*(1.0-smoothstep(0.83,1.0,reload_progress))
			support = support.lerp(cell_goal,influence)
		# Shift the shared cosmetic pose minimally toward reachable wrist targets.
		for pass_index in range(2):
			var correction: Vector3 = actor.arm_reach_correction("L",support)
			if correction.length() < 0.002:
				break
			global_position += correction.limit_length(0.045)
			support += correction.limit_length(0.045)
		right_error = actor.solve_arm("R",right_goal.global_position,frame*Vector3(0.65,-0.7,0.25))
		left_error = actor.solve_arm("L",support,frame*Vector3(-0.65,-0.7,0.10))
		# The right hand retains its cosmetic grip while the left animates the energy cell.
		actor.close_fingers(1.0,clampf(1.0-0.45*sin(reload_progress*PI),0.0,1.0))

func accessory_piece(parent: Node3D, size: Vector3, offset: Vector3, color: Color) -> void:
	var part := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	part.mesh = shape
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	part.material_override = mat
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	part.position = offset

func build_accessories() -> void:
	# Cosmetic parts only: original Tripo model and wrist targets stay intact.
	for key in ["HOLO","MAG","RELOAD"]:
		var group := Node3D.new()
		group.name = "Accessory_"+key
		add_child(group)
		accessories[key] = group
		group.hide()
	var scope: Node3D = accessories.HOLO
	accessory_piece(scope,Vector3(0.105,0.035,0.14),Vector3(0,0.12,-0.035),Color("26333e"))
	for x in [-0.05,0.05]:
		accessory_piece(scope,Vector3(0.018,0.105,0.045),Vector3(x,0.185,-0.045),Color("3c515e"))
	accessory_piece(scope,Vector3(0.116,0.018,0.045),Vector3(0,0.24,-0.045),Color("3c515e"))
	accessory_piece(scope,Vector3(0.012,0.012,0.012),Vector3(0,0.185,-0.045),Color("58f0dc"))
	var mag: Node3D = accessories.MAG
	accessory_piece(mag,Vector3(0.105,0.09,0.13),Vector3(0,-0.14,0.015),Color("26333e"))
	accessory_piece(mag,Vector3(0.11,0.018,0.14),Vector3(0,-0.185,0.015),Color("7ec8d0"))
	var quick: Node3D = accessories.RELOAD
	accessory_piece(quick,Vector3(0.035,0.075,0.10),Vector3(0.085,0,0.035),Color("eaad58"))

func set_accessories(mods: Dictionary) -> void:
	for key in accessories:
		accessories[key].visible = bool(mods.get(key,false))

func set_variant(tint: Color) -> void:
	for material: StandardMaterial3D in base_tints:
		material.albedo_color = base_tints[material]*tint

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
	aim_pitch = 0.0
	sprint_pose = 0.0
	carry_sway = Vector3.ZERO
	carry_roll = 0.0
	pose_initialized = false
	right_error = 0.0
	left_error = 0.0
	update_reload_cell(0.0)
	if is_instance_valid(flash):
		flash.hide()

# Purely fictional visual energy module, distinct from the fused source mesh.
func cell_piece(pos: Vector3,dimensions: Vector3,color: Color) -> void:
	var part := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	part.mesh = box
	part.position = pos
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	part.material_override = mat
	energy_cell.add_child(part)

func build_energy_cell() -> void:
	energy_cell = Node3D.new()
	energy_cell.name = "IgnisVisualEnergyCell"
	add_child(energy_cell)
	cell_piece(Vector3.ZERO,Vector3(0.044,0.074,0.085),Color("28343b"))
	cell_piece(Vector3(-0.024,0,0),Vector3(0.007,0.052,0.064),Color("ff9b43"))
	cell_piece(Vector3(0,0.037,0),Vector3(0.046,0.008,0.088),Color("727d83"))
	cell_piece(Vector3(0,-0.037,0),Vector3(0.046,0.008,0.088),Color("727d83"))
	update_reload_cell(0.0)

func update_reload_cell(remaining: float) -> void:
	if not is_instance_valid(energy_cell):
		return
	reload_progress = 1.0-clampf(remaining,0.0,1.0) if remaining>0.0 else 0.0
	var p := reload_progress
	var out := cell_dock+Vector3(-0.055,-0.060,-0.025)
	var exchange := cell_dock+Vector3(-0.080,-0.12,-0.075)
	cell_stage = "DOCKED"
	cell_path = cell_dock
	if remaining>0.0:
		if p<0.22:
			cell_stage = "REMOVE"
			cell_path = cell_dock.lerp(out,smoothstep(0.0,0.22,p))
		elif p<0.52:
			cell_stage = "EXCHANGE"
			cell_path = out.lerp(exchange,smoothstep(0.22,0.52,p))
		elif p<0.84:
			cell_stage = "INSERT"
			cell_path = exchange.lerp(cell_dock,smoothstep(0.52,0.84,p))
		else:
			cell_stage = "LOCK"
	energy_cell.position = cell_path
	energy_cell.rotation.z = -0.22*sin(p*PI) if remaining>0.0 else 0.0
