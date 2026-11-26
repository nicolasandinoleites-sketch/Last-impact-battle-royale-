extends SceneTree
func _initialize() -> void:
 call_deferred("run")
func capture(name: String) -> void:
 await RenderingServer.frame_post_draw
 var im := root.get_texture().get_image()
 assert(not im.is_empty())
 assert(im.save_png("user://R0783_previews/"+name+".png")==OK)
 print("CAPTURE ",name)
func run() -> void:
 DirAccess.make_dir_recursive_absolute("user://R0783_previews")
 root.size = Vector2i(800,450)
 var game = load("res://battle_royale.tscn").instantiate()
 root.add_child(game)
 for i in range(12): await physics_frame
 await capture("01_avion")
 game.request_jump()
 for i in range(10): await physics_frame
 await capture("02_cabina")
 game.request_jump()
 for i in range(65): await physics_frame
 await capture("03_rampa")
 for i in range(150):
  await physics_frame
  if game.deployment.flight.phase==2: break
 for i in range(15): await physics_frame
 await capture("04_caida")
 game.request_jump()
 for i in range(40): await physics_frame
 await capture("05_planeo")
 quit()
