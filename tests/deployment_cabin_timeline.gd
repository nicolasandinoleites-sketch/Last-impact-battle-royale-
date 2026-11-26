extends SceneTree
const Timeline = preload("res://scripts/deployment_cabin_timeline.gd")
const Cabin = preload("res://scripts/deployment_cabin.gd")
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var cabin := Cabin.new()
 root.add_child(cabin)
 cabin.build()
 var t := Timeline.new()
 assert(not t.step(1.0/60.0,-50.0,false))
 assert(not t.requested and t.opening==0.0)
 assert(absf(cabin.ramp.rotation.x+PI*0.5)<0.001)
 var done := false
 for i in range(160):
  done = t.step(1.0/60.0,-30.0,i==0)
  cabin.set_opening(t.opening)
  if t.opening<1.0:
   assert(t.actor_local.z==-0.8)
  if done: break
 assert(done and absf(t.elapsed-2.45)<0.001)
 assert(absf(cabin.ramp.rotation.x-deg_to_rad(15.8))<0.001)
 assert(t.exit_world(Vector3(20,78,4)).distance_to(Vector3(14,75.42,4))<0.001)
 assert(t.actor_local==Timeline.EXIT_LOCAL)
 t.reset()
 assert(not t.step(1.0/60.0,7.99,false))
 assert(not t.step(1.0/60.0,8.0,false) and t.requested)
 for i in range(150):
  t.step(1.0/60.0,8.0+float(i)*0.25,false)
 assert(t.ready_to_exit)
 assert(8.0+15.0*t.elapsed<50.0)
 t.reset()
 cabin.set_opening(0.0)
 assert(not t.requested and not t.ready_to_exit and cabin.opening==0.0)
 print("CABIN TIMELINE PASS | manual, automatic, ramp, exact exit, reset")
 quit()
