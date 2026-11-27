extends RefCounted
# Flight prototype; ground sampler is a caller-provided terrain height, not root motion.
enum Phase { INTRO, IN_PLANE, FREEFALL, GLIDE, LAND, GROUND }
const EDGE := 58.0
const ALTITUDE := 78.0
const LAND_DURATION := 0.65
var edge := EDGE
var altitude := ALTITUDE
var start_x := -50.0
var phase: int = Phase.INTRO
var elapsed := 0.0
var plane_position := Vector3(-50,ALTITUDE,0)
var position := Vector3.ZERO
var velocity := Vector3.ZERO
var jumped := false
var ground_y := 0.0
var time_in_phase := 0.0
func configure_expanded() -> void:
 edge = 122.0
 altitude = 104.0
 start_x = -104.0

func reset() -> void:
 phase = Phase.INTRO
 elapsed = 0.0
 time_in_phase = 0.0
 plane_position = Vector3(start_x,altitude,0)
 position = Vector3.ZERO
 velocity = Vector3.ZERO
 jumped = false
 ground_y = 0.0
func transition(next: int) -> void:
 phase = next
 time_in_phase = 0.0
func step(delta: float, input: Vector2, request_jump: bool, request_glide: bool, terrain_y: float = 0.0, surface_sampler: Callable = Callable(), horizontal_filter: Callable = Callable()) -> void:
 var dt := clampf(delta,0.0,0.05)
 elapsed += dt
 time_in_phase += dt
 ground_y = terrain_y
 if phase==Phase.INTRO:
  if time_in_phase>=2.8 or request_jump:
   transition(Phase.IN_PLANE)
  return
 if phase==Phase.IN_PLANE:
  plane_position.x += dt*15.0
  if request_jump or plane_position.x>=edge-8.0:
   jumped = true
   position = plane_position+Vector3(-6,-2.58,0)
   velocity = Vector3(9,-4,0)
   transition(Phase.FREEFALL)
  return
 if phase==Phase.FREEFALL or phase==Phase.GLIDE:
  plane_position.x += dt*15.0
  # Sample beneath the current feet for auto-glide, not the highest surface on the map.
  if surface_sampler.is_valid():
   var sampled: float = surface_sampler.call(position)
   if is_finite(sampled):
    ground_y = sampled
  var altitude := position.y-ground_y
  if phase==Phase.FREEFALL and (request_glide or altitude<=16.0):
   transition(Phase.GLIDE)
  var steering := input.limit_length(1.0)
  var max_speed := 8.0 if phase==Phase.GLIDE else 12.0
  var desired := Vector3(steering.x*max_speed,0,steering.y*max_speed)
  velocity.x = move_toward(velocity.x,desired.x,dt*12.0)
  velocity.z = move_toward(velocity.z,desired.z,dt*12.0)
  velocity.y = move_toward(velocity.y,-5.5 if phase==Phase.GLIDE else -23.0,dt*(30.0 if phase==Phase.GLIDE else 14.0))
  var next := position+velocity*dt
  next.x = clampf(next.x,-edge,edge)
  next.z = clampf(next.z,-edge,edge)
  if horizontal_filter.is_valid():
   next = horizontal_filter.call(position,next)
  # Sample again at the proposed horizontal destination before touchdown.
  var touchdown_y := terrain_y
  if surface_sampler.is_valid():
   touchdown_y = surface_sampler.call(Vector3(next.x,position.y,next.z))
  if is_finite(touchdown_y) and next.y<=touchdown_y:
   ground_y = touchdown_y
   next.y = touchdown_y
   velocity = Vector3.ZERO
   transition(Phase.LAND)
  position = next
 elif phase==Phase.LAND and time_in_phase>=LAND_DURATION:
  transition(Phase.GROUND)
