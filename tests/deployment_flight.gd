extends SceneTree
const Flight=preload("res://scripts/deployment_flight.gd")
func _initialize():
 var f=Flight.new()
 for i in range(180):f.step(1.0/60.0,Vector2.ZERO,false,false)
 assert(f.phase==Flight.Phase.IN_PLANE and not f.jumped)
 f.step(1.0/60.0,Vector2.ZERO,true,false)
 assert(f.phase==Flight.Phase.FREEFALL and f.jumped)
 var phase_seen=[]
 for i in range(2400):
  f.step(1.0/60.0,Vector2(1,1),false,false,2.0)
  if f.phase not in phase_seen:phase_seen.append(f.phase)
  assert(absf(f.position.x)<=58.0 and absf(f.position.z)<=58.0 and f.position.y>=2.0)
  if f.phase==Flight.Phase.GROUND:break
 assert(phase_seen==[Flight.Phase.FREEFALL,Flight.Phase.GLIDE,Flight.Phase.LAND,Flight.Phase.GROUND])
 assert(f.position.y==2.0 and f.velocity==Vector3.ZERO)
 f.reset()
 for i in range(1000):
  f.step(1.0/60.0,Vector2.ZERO,false,false)
  if f.jumped:break
 assert(f.jumped and f.phase==Flight.Phase.FREEFALL)
 print("DEPLOYMENT FLIGHT PASS | auto glide, auto exit, edge clamp, terrain height, reset")
 quit()
