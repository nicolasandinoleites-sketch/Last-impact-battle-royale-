extends SceneTree
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 DirAccess.make_dir_recursive_absolute("user://R0790_previews")
 root.size=Vector2i(960,540)
 var game=load("res://battle_royale.tscn").instantiate()
 root.add_child(game)
 for i in range(5): await physics_frame
 game.deployment.finish()
 game.set_physics_process(false)
 game.player.set_physics_process(false)
 for t in game.targets:
  t.set_physics_process(false)
  t.hide()
 game.player.global_position=game.supplies.station.global_position+Vector3(0,0,2.6)
 game.player.yaw=0.0
 game.player.pitch=-0.12
 game.player.update_camera(1.0)
 for i in range(15): await physics_frame
 await RenderingServer.frame_post_draw
 assert(root.get_texture().get_image().save_png("user://R0790_previews/shop.png")==OK)
 game.supplies.spawn_airdrop()
 game.supplies.step(2.5)
 var camera := Camera3D.new()
 game.add_child(camera)
 camera.position=game.supplies.crate.position+Vector3(8,3,10)
 camera.look_at(game.supplies.crate.position+Vector3.UP)
 camera.make_current()
 await RenderingServer.frame_post_draw
 assert(root.get_texture().get_image().save_png("user://R0790_previews/airdrop.png")==OK)
 print("R0790 PREVIEW PASS")
 game.queue_free()
 await process_frame
 await process_frame
 quit()
