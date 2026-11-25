extends Node3D
const MODEL := "res://assets/tripo/raze.glb"
var model: Node3D
var skeleton: Skeleton3D
var animator: AnimationPlayer
var base: Dictionary = {}
var ready_model := false
var preview_dance := false

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
	ready_model = true
	return true

func bone_motion(name: String,angle: float) -> void:
	var id := skeleton.find_bone(name)
	if id < 0:
		return
	var axis := skeleton.get_bone_global_rest(id).basis.orthonormalized().inverse() * Vector3.RIGHT
	var rest: Quaternion = base[id]
	skeleton.set_bone_pose_rotation(id,rest * Quaternion(axis.normalized(),angle))

func locomotion(phase: float, strength: float, grounded: bool, low: bool, combat: bool) -> void:
	if not ready_model or preview_dance:
		return
	var swing := sin(phase) * 0.35 * strength if grounded else 0.0
	bone_motion("L_Thigh",swing - (0.35 if low else 0.0))
	bone_motion("R_Thigh",-swing - (0.35 if low else 0.0))
	bone_motion("L_Calf",maxf(0.0,-swing)*0.7 + (0.65 if low else 0.0))
	bone_motion("R_Calf",maxf(0.0,swing)*0.7 + (0.65 if low else 0.0))
	bone_motion("L_Upperarm",0.0 if combat else -swing*0.55)
	bone_motion("R_Upperarm",0.0 if combat else swing*0.55)
	model.position.y = -0.25 if low else absf(swing)*0.025

func dance() -> bool:
	if animator == null:
		return false
	for name in animator.get_animation_list():
		if String(name).contains("dance"):
			preview_dance = true
			animator.play(name)
			return true
	return false
