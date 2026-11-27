extends Node3D
const Vehicle = preload("res://scripts/frontier_vehicle.gd")
var game
var vehicles: Array[CharacterBody3D] = []
var mounted: CharacterBody3D
var saved_mask := 1

func configure(owner_game) -> void:
 game = owner_game
 for data in [["VELOCITY",Vector3(58,0.02,12)],["BASTION",Vector3(-58,0.02,-12)]]:
  var vehicle := Vehicle.new()
  vehicle.model_id = data[0]
  vehicle.position = data[1]
  add_child(vehicle)
  vehicles.append(vehicle)

func nearest():
 if not is_instance_valid(game.player) or game.deployment_active() or game.round_result!="": return null
 var best: CharacterBody3D = null
 var dist := 3.3
 for v in vehicles:
  if v.hp<=0 or v.occupied: continue
  var gap: float = game.player.global_position.distance_to(v.global_position)
  if gap<dist:
   best = v
   dist = gap
 return best

func toggle() -> bool:
 if is_instance_valid(mounted): return exit_vehicle()
 var v = nearest()
 if not is_instance_valid(v): return false
 var p: CharacterBody3D = game.player
 mounted = v
 mounted.occupied = true
 saved_mask = p.collision_mask
 p.reset_movement()
 p.set_physics_process(false)
 p.collision_mask = 0
 p.visual.hide()
 p.contact_shadow.hide()
 if p.weapon_loaded: p.weapon.hide()
 p.boom.add_excluded_object(v.get_rid())
 game.reload_left = 0.0
 game.hud.clear_controls()
 game.message = "CONDUCIENDO "+str(v.model_id)
 sync_driver(1.0)
 return true

func sync_driver(delta: float) -> void:
 var p = game.player
 p.global_position = mounted.global_position+Vector3.UP*(0.80 if mounted.model_id=="VELOCITY" else 1.10)
 p.yaw = lerp_angle(p.yaw,mounted.rotation.y,1.0-exp(-delta*9.0))
 p.pitch = -0.16
 p.update_camera(delta)
 p.boom.spring_length = 5.2 if mounted.model_id=="BASTION" else 4.3
 p.boom.position.x = 0.0

func clear_exit(point: Vector3) -> bool:
 var shape := CapsuleShape3D.new()
 shape.radius = 0.36
 shape.height = 1.76
 var query := PhysicsShapeQueryParameters3D.new()
 query.shape=shape
 query.transform=Transform3D(Basis.IDENTITY,point+Vector3.UP*0.94)
 query.collision_mask=1
 query.exclude=[game.player.get_rid()]
 return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func exit_vehicle(force: bool = false) -> bool:
 if not is_instance_valid(mounted): return false
 var v := mounted
 if not force and absf(v.speed)>2.0:
  game.message = "FRENA PARA BAJAR"
  return false
 var exit_point := Vector3.INF
 for offset in [Vector3(2.5,0,0),Vector3(-2.5,0,0),Vector3(0,0,3.0),Vector3(0,0,-3.0)]:
  var point: Vector3 = v.global_position+v.global_basis*offset
  point.y = 0.03
  if absf(point.x)>game.frontier.half_extent-2.0 or absf(point.z)>game.frontier.half_extent-2.0: continue
  if clear_exit(point):
   exit_point=point
   break
 if not exit_point.is_finite():
  if not force: return false
  exit_point=Vector3(0,0.1,12)
 var p = game.player
 p.boom.remove_excluded_object(v.get_rid())
 p.collision_mask=saved_mask
 p.global_position=exit_point
 p.reset_movement()
 p.visual.show()
 p.contact_shadow.show()
 if p.weapon_loaded: p.weapon.show()
 p.set_physics_process(true)
 p.reset_physics_interpolation()
 v.occupied=false
 v.speed=0.0
 v.velocity=Vector3.ZERO
 mounted=null
 game.hud.clear_controls()
 game.message="VEHICULO ABANDONADO"
 return true

func step(delta: float,input: Vector2) -> void:
 if not is_instance_valid(mounted): return
 if mounted.hp<=0:
  exit_vehicle(true)
  return
 mounted.drive(delta,input)
 sync_driver(delta)

func reset() -> void:
 if is_instance_valid(mounted): exit_vehicle(true)
 for v in vehicles:
  v.reset_vehicle()
  v.visual.show()
