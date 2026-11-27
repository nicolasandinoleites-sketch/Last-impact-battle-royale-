extends RefCounted
# Pure timing for the independent cargo bay set. Aircraft travels along +X.
const OPEN_SECONDS := 0.86
const WALK_START := 0.86
const EXIT_SECONDS := 2.45
const AUTO_REQUEST_X := 8.0
const CABIN_FLOOR_OFFSET := -2.0
const EXIT_LOCAL := Vector3(0,-0.58,6)
var auto_request_x := AUTO_REQUEST_X
var requested := false
var ready_to_exit := false
var elapsed := 0.0
var opening := 0.0
var walking := false
var actor_local := Vector3(0,0,-0.8)
var actor_speed := 0.0

func reset() -> void:
 requested = false
 ready_to_exit = false
 elapsed = 0.0
 opening = 0.0
 walking = false
 actor_local = Vector3(0,0,-0.8)
 actor_speed = 0.0

func step(delta: float, plane_x: float, request: bool) -> bool:
 if ready_to_exit:
  return true
 requested = requested or request or plane_x>=auto_request_x
 if not requested:
  return false
 var dt := clampf(delta,0.0,0.05)
 elapsed = minf(EXIT_SECONDS,elapsed+dt)
 opening = clampf(elapsed/OPEN_SECONDS,0.0,1.0)
 var previous_z := actor_local.z
 var walk := clampf((elapsed-WALK_START)/(EXIT_SECONDS-WALK_START),0.0,1.0)
 actor_local.z = lerpf(-0.8,EXIT_LOCAL.z,smoothstep(0.0,1.0,walk))
 actor_local.y = minf(0.0,-maxf(0.0,actor_local.z-3.95)*tan(deg_to_rad(15.8)))
 actor_speed = (actor_local.z-previous_z)/maxf(dt,0.001)
 walking = elapsed>=WALK_START and elapsed<EXIT_SECONDS
 ready_to_exit = elapsed>=EXIT_SECONDS
 if ready_to_exit:
  actor_local = EXIT_LOCAL
  actor_speed = 0.0
 return ready_to_exit

func world_point(plane_position: Vector3, local_point: Vector3) -> Vector3:
 return plane_position+Vector3(-local_point.z,CABIN_FLOOR_OFFSET+local_point.y,local_point.x)

func exit_world(plane_position: Vector3) -> Vector3:
 return world_point(plane_position,EXIT_LOCAL)
