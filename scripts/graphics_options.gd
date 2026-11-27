extends RefCounted
var profile := 0
var fps := 30
var resolution := 65
var shadows := false
var dynamic := true
var distance := 175
func path() -> String:
 var override := OS.get_environment("LASTIMPACT_GRAPHICS_PATH")
 return override if not override.is_empty() else "user://lastimpact.cfg"
func preset(i: int) -> void:
 profile=clampi(i,0,3)
 fps=[30,45,60,60][profile]
 resolution=[65,80,90,100][profile]
 shadows=profile>=2
 dynamic=profile==0
 distance=[175,200,250,300][profile]
func load_options() -> void:
 var c:=ConfigFile.new()
 if c.load(path())!=OK: return
 preset(int(c.get_value("graphics","profile",0)))
 fps=int(c.get_value("graphics","fps",fps))
 if fps not in [30,45,60,90]: fps=30
 resolution=clampi(int(c.get_value("graphics","resolution",resolution)),50,100)
 shadows=bool(c.get_value("graphics","shadows",shadows))
 dynamic=bool(c.get_value("graphics","dynamic",dynamic))
 distance=clampi(int(c.get_value("graphics","distance",distance)),175,300)
func save_options() -> Error:
 var c:=ConfigFile.new()
 c.load(path())
 for k in ["profile","fps","resolution","shadows","dynamic","distance"]: c.set_value("graphics",k,get(k))
 return c.save(path())
func apply(window: Window) -> void:
 Engine.max_fps=fps
 if OS.has_feature("android"):
  window.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
  window.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_EXPAND
  window.content_scale_size=Vector2i(roundi(1280.0*resolution/100),roundi(720.0*resolution/100))
  window.scaling_3d_scale=1.0
 else:
  window.scaling_3d_scale=resolution/100.0
