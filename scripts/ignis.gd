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
	model.scale = Vector3.ONE*0.78
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
	flash.position = Vector3(0,0.05,-0.44)
	add_child(flash)
	flash.hide()
	loaded = true
	return true

func update_pose(delta: float, aiming: bool, reload: float) -> void:
	if not loaded:
		return
	kick = move_toward(kick,0.0,delta*1.4)
	flash_left = maxf(0.0,flash_left-delta)
	flash.visible = flash_left > 0.0
	reload_phase = reload
	var frame := facing.global_transform.basis.orthonormalized()
	global_transform = Transform3D(frame, anchor.global_position)
	# Cosmetic placement follows the animated right hand; final offsets need a visual test.
	model.position = Vector3(0,0.09,-0.13+kick)
	model.rotation = Vector3(-0.12 if aiming else -0.28,0,0.35*sin(reload*PI) if reload>0.0 else 0.0)
	flash.position = model.position + model.basis.orthonormalized()*Vector3(0,0.06,-0.39)

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
