extends SceneTree
const Motion = preload("res://scripts/deployment_camera.gd")
const Flight = preload("res://scripts/deployment_flight.gd")

func _initialize() -> void:
 var cam = Motion.new()
 var max_step := 0.0
 for phase in [0,1,2,3,4,5]:
  for i in range(39 if phase==4 else 180):
   var previous: float = cam.fov
   cam.step(1.0/60.0,phase,Vector2(1,-1),float(i)/38.0)
   max_step = maxf(max_step,absf(cam.fov-previous))
   assert(cam.fov>=59.9 and cam.fov<=78.1)
   assert(cam.distance>=2.84 and cam.distance<=4.51)
   assert(absf(cam.roll)<=0.056)
  if phase==2:
   assert(cam.fov>77.0 and cam.pitch_offset< -0.2)
  if phase==3:
   assert(cam.fov>71.0 and cam.fov<73.0)
  if phase==4:
   assert(absf(cam.fov-60.0)<0.1 and absf(cam.pitch_offset)<0.01)
 assert(max_step<2.1)
 cam.reset()
 assert(cam.fov==60.0 and cam.roll==0.0 and cam.pitch_offset==0.0)
 print("DEPLOYMENT CAMERA PASS | bounded FOV, bank, phase smoothing and landing settle")
 quit()
