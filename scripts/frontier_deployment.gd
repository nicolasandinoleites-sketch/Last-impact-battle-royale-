extends Node3D
# Experimental integration using the existing FRONTIER and actual RAZE player.
# Does not render a substitute aircraft or backpack when those assets are absent.
const Flight = preload("res://scripts/deployment_flight.gd")
const Surface = preload("res://scripts/deployment_surface.gd")
const Pose = preload("res://scripts/deployment_pose.gd")
var flight := Flight.new()
var surface := Surface.new()
var pose := Pose.new()
var player
var pose_ready := false
var active := false
var landing_clear := false
var action_requested := false
var saved_camera_far := 110.0
var saved_weapon_visibility := true
var last_phase := Flight.Phase.INTRO

func begin(actor) -> void:
 player = actor
 player.reset_movement()
 player.set_physics_process(false)
 player.contact_shadow.hide()
 saved_camera_far = player.camera.far
 player.camera.far = 220.0
 if player.weapon_loaded:
  saved_weapon_visibility = player.weapon.visible
  player.weapon.hide()
 if player.model_loaded:
  pose_ready = pose.setup(player.raze.skeleton)
 flight.reset()
 active = true
 landing_clear = false
 action_requested = false
 last_phase = flight.phase
 player.position = flight.plane_position
 player.yaw = -PI*0.5
 player.pitch = -0.38
 player.visual.rotation.y = player.yaw
 player.update_camera(1.0)
 player.reset_physics_interpolation()

func request_action() -> void:
 if active:
  action_requested = true

func filter_horizontal(from: Vector3, to: Vector3) -> Vector3:
 var horizontal := Vector3(to.x-from.x,0,to.z-from.z)
 if horizontal.length_squared()>0.000001 and player.test_move(player.global_transform,horizontal):
  to.x = from.x
  to.z = from.z
  flight.velocity.x = 0.0
  flight.velocity.z = 0.0
 return to

func step(delta: float, stick: Vector2) -> void:
 if not active:
  return
 var ids: Array[RID] = [player.get_rid()]
 surface.configure(player.get_world_3d().direct_space_state,ids)
 var steering3: Vector3 = Basis(Vector3.UP,player.yaw)*Vector3(stick.x,0,stick.y)
 var steering := Vector2(steering3.x,steering3.z)
 var previous: int = flight.phase
 var old_position: Vector3 = player.global_position
 flight.step(delta,steering,action_requested,action_requested,0.0,Callable(surface,"height_below"),Callable(self,"filter_horizontal"))
 action_requested = false
 if flight.phase in [Flight.Phase.INTRO,Flight.Phase.IN_PLANE]:
  player.global_position = flight.plane_position
 elif previous==Flight.Phase.IN_PLANE:
  player.global_position = flight.position
  player.reset_physics_interpolation()
 elif previous in [Flight.Phase.FREEFALL,Flight.Phase.GLIDE]:
  # The real character capsule is swept along the planned displacement.
  var planned := flight.position
  var collision: KinematicCollision3D = player.move_and_collide(planned-old_position)
  if collision!=null:
   var reached: Vector3 = player.global_position
   var floor_hit := collision.get_normal().y>=0.7
   if floor_hit and surface.standing_clear(reached):
    flight.position = reached
    flight.velocity = Vector3.ZERO
    flight.transition(Flight.Phase.LAND)
   else:
    # Reject unsafe touchdown; return to airborne control, never enable walking inside a wall.
    flight.position = reached
    flight.velocity.x = 0.0
    flight.velocity.z = 0.0
    if flight.phase==Flight.Phase.LAND:
     flight.transition(Flight.Phase.GLIDE)
  else:
   flight.position = player.global_position
  if flight.phase==Flight.Phase.LAND:
   landing_clear = surface.standing_clear(player.global_position)
   if not landing_clear:
    flight.transition(Flight.Phase.GLIDE)
 elif flight.phase==Flight.Phase.LAND:
  player.global_position = flight.position
 if pose_ready:
  pose.update(player.raze.skeleton,delta,flight.phase,stick,flight.elapsed)
 player.visual.rotation.y = lerp_angle(player.visual.rotation.y,player.yaw,1.0-exp(-delta*8.0))
 player.update_camera(delta)
 if previous!=flight.phase:
  print("LAST IMPACT DEPLOYMENT PHASE ",Flight.Phase.keys()[flight.phase])
 last_phase = flight.phase
 if flight.phase==Flight.Phase.GROUND:
  if landing_clear and surface.standing_clear(player.global_position):
   finish()
  else:
   flight.transition(Flight.Phase.GLIDE)

func finish() -> void:
 active = false
 action_requested = false
 player.reset_movement()
 player.camera.far = saved_camera_far
 if player.weapon_loaded:
  player.weapon.visible = saved_weapon_visibility
 player.pitch = -0.13
 player.update_camera(1.0)
 player.reset_physics_interpolation()
 player.set_physics_process(true)

func status_text() -> String:
 match flight.phase:
  Flight.Phase.INTRO: return "DESPLIEGUE EXPERIMENTAL"
  Flight.Phase.IN_PLANE: return "PULSA SALTAR"
  Flight.Phase.FREEFALL: return "CAIDA LIBRE · ABRIR ALAS"
  Flight.Phase.GLIDE: return "PLANEO · ELIGE TU DESTINO"
  Flight.Phase.LAND: return "ATERRIZANDO"
 return ""
