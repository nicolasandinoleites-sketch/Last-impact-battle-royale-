extends SceneTree
const Options=preload("res://scripts/graphics_options.gd")
func _initialize()->void:
 OS.set_environment("LASTIMPACT_GRAPHICS_PATH","user://r0795_test.cfg")
 var a:=Options.new()
 a.preset(3)
 a.fps=90
 a.resolution=80
 assert(a.save_options()==OK)
 var b:=Options.new()
 b.load_options()
 assert(b.profile==3 and b.fps==90 and b.resolution==80 and b.shadows)
 b.apply(root)
 assert(Engine.max_fps==90)
 DirAccess.remove_absolute("user://r0795_test.cfg")
 print("R0795 GRAPHICS PASS")
 quit()
