extends SceneTree
const Layout=preload("res://scripts/hud_layout.gd")
func _initialize()->void:
 OS.set_environment("LASTIMPACT_HUD_PATH","user://r0796_test.cfg")
 var a:=Layout.new()
 a.set_control("FIRE",Vector2(.7,.4),1.4,.5)
 assert(a.save_layout()==OK)
 var b:=Layout.new()
 b.load_layout()
 assert(b.position("FIRE",Vector2.ZERO).is_equal_approx(Vector2(.7,.4)))
 assert(is_equal_approx(b.scale("FIRE"),1.4) and is_equal_approx(b.opacity("FIRE"),.5))
 DirAccess.remove_absolute("user://r0796_test.cfg")
 print("R0796 HUD PASS")
 quit()
