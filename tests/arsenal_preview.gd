extends SceneTree
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 DirAccess.make_dir_recursive_absolute("user://R0789_previews")
 root.size=Vector2i(960,540)
 var game=load("res://battle_royale.tscn").instantiate()
 root.add_child(game)
 for i in range(5): await physics_frame
 game.deployment.finish()
 game.set_physics_process(false)
 for t in game.targets:
  t.set_physics_process(false)
  t.hide()
 var item=game.pickups[9]
 game.player.global_position=item.global_position+Vector3(0,0.03,1.4)
 game.player.yaw=0.0
 game.player.pitch=-0.15
 game.player.update_camera(1.0)
 for i in range(15): await physics_frame
 await RenderingServer.frame_post_draw
 assert(root.get_texture().get_image().save_png("user://R0789_previews/loot.png")==OK)
 assert(game.collect_nearby())
 for i in range(15): await physics_frame
 await RenderingServer.frame_post_draw
 assert(root.get_texture().get_image().save_png("user://R0789_previews/arsenal.png")==OK)
 print("R0789 PREVIEW PASS")
 game.queue_free()
 await process_frame
 await process_frame
 quit()
