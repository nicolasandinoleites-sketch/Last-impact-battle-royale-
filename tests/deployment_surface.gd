extends SceneTree
const Flight = preload("res://scripts/deployment_flight.gd")
const Surface = preload("res://scripts/deployment_surface.gd")
var world: Node3D

func _initialize() -> void:
 call_deferred("run")

func block(at: Vector3, dimensions: Vector3) -> void:
 var body := StaticBody3D.new()
 body.position = at
 body.collision_layer = 1
 var collision := CollisionShape3D.new()
 var box := BoxShape3D.new()
 box.size = dimensions
 collision.shape = box
 body.add_child(collision)
 world.add_child(body)

func run() -> void:
 world = Node3D.new()
 root.add_child(world)
 block(Vector3(0,-0.3,0),Vector3(120,0.6,120))
 block(Vector3(0,3.8,0),Vector3(10,0.4,10))
 await physics_frame
 await physics_frame
 var sampler = Surface.new()
 sampler.configure(world.get_world_3d().direct_space_state)
 assert(absf(sampler.height_below(Vector3(0,20,0))-4.0)<0.01)
 assert(absf(sampler.height_below(Vector3(15,20,0)))<0.01)
 assert(absf(sampler.height_below(Vector3(0,2,0)))<0.01)
 assert(sampler.standing_clear(Vector3(0,4,0)))
 assert(not sampler.standing_clear(Vector3(0,2.5,0)))
 assert(is_nan(sampler.height_below(Vector3(80,20,0))))
 var f = Flight.new()
 for point in [Vector3(0,10,0),Vector3(15,10,0)]:
  f.reset()
  f.position = point
  f.phase = Flight.Phase.GLIDE
  for i in range(600):
   f.step(1.0/60.0,Vector2.ZERO,false,false,0.0,Callable(sampler,"height_below"))
   if f.phase==Flight.Phase.GROUND:
    break
  assert(f.phase==Flight.Phase.GROUND)
  var expected := 4.0 if point.x==0.0 else 0.0
  assert(absf(f.position.y-expected)<0.01)
  assert(sampler.standing_clear(f.position))
 print("DEPLOYMENT SURFACE PASS | roof, ground, under roof, capsule clearance, no hit")
 quit()
