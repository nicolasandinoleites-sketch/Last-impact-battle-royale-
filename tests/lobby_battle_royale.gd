extends SceneTree
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 change_scene_to_file("res://lobby.tscn")
 await scene_changed
 await process_frame
 var lobby = current_scene
 lobby.activate(lobby.point(810,411))
 await scene_changed
 await physics_frame
 assert(current_scene.scene_file_path=="res://battle_royale.tscn")
 assert(current_scene.survival_mode and current_scene.deployment_active() and current_scene.deployment.assets.available)
 print("BATTLE ROYALE LOBBY PASS | actual menu activation and complete assets")
 current_scene.deployment.finish()
 await create_timer(0.2).timeout
 quit()
