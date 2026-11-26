extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var actor = preload("res://scripts/raze.gd").new()
	root.add_child(actor)
	if not actor.load_model():
		push_error("TEST FAILED: RAZE rig cannot load")
		quit(1)
		return
	var rig: Skeleton3D = actor.skeleton
	var player: AnimationPlayer = actor.animator
	var bones: Array[Dictionary] = []
	var clips: Array[Dictionary] = []
	for i in range(rig.get_bone_count()):
		var rest := rig.get_bone_rest(i)
		bones.append({"name":rig.get_bone_name(i),"parent_index":rig.get_bone_parent(i),"rest_origin":[rest.origin.x,rest.origin.y,rest.origin.z],"rest_basis":[[rest.basis.x.x,rest.basis.x.y,rest.basis.x.z],[rest.basis.y.x,rest.basis.y.y,rest.basis.y.z],[rest.basis.z.x,rest.basis.z.y,rest.basis.z.z]]})
	if is_instance_valid(player):
		for clip_name in player.get_animation_list():
			var clip: Animation = player.get_animation(clip_name)
			var tracks: Array[Dictionary] = []
			for i in range(clip.get_track_count()):
				tracks.append({"path":str(clip.track_get_path(i)),"type":int(clip.track_get_type(i)),"keys":clip.track_get_key_count(i)})
			clips.append({"name":str(clip_name),"seconds":clip.length,"loop":int(clip.loop_mode),"tracks":tracks})
	var report := {"asset":"res://assets/tripo/raze.glb","bones":bones,"clips":clips,"model_scale":[actor.model.scale.x,actor.model.scale.y,actor.model.scale.z]}
	var file := FileAccess.open("/tmp/raze_rig_audit.json",FileAccess.WRITE)
	if file==null:
		push_error("TEST FAILED: rig report cannot be written")
		quit(1)
		return
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print("RAZE RIG AUDIT COMPLETE | bones=",bones.size()," clips=",clips.size())
	quit(0)
