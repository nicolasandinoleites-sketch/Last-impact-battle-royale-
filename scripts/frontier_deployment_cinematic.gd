extends Node3D
# The GLB exterior cargo door is fused; use an independent interior set and deliberate shot cut.
const Cabin = preload("res://scripts/deployment_cabin.gd")
const Timeline = preload("res://scripts/deployment_cabin_timeline.gd")
const Flight = preload("res://scripts/deployment_flight.gd")
var timeline := Timeline.new()
var cabin: Node3D
var shot: Camera3D
var actor
var active := false
var interior := false

func configure(player) -> void:
 actor = player
 cabin = Cabin.new()
 add_child(cabin)
 cabin.build()
 cabin.rotation.y = -PI*0.5
 cabin.hide()
 shot = Camera3D.new()
 shot.far = 240.0
 shot.near = 0.05
 shot.fov = 68.0
 add_child(shot)

func reset() -> void:
 timeline.reset()
 active = true
 interior = false
 cabin.set_opening(0.0)
 cabin.hide()

func request_exit(delta: float, plane_x: float, action: bool) -> bool:
 return timeline.step(delta,plane_x,action)

func show_aboard(phase: int, plane_position: Vector3, clock: float, delta: float) -> void:
 interior = phase==Flight.Phase.IN_PLANE
 cabin.global_position = plane_position+Vector3(0,Timeline.CABIN_FLOOR_OFFSET,0)
 cabin.visible = interior
 cabin.set_opening(timeline.opening)
 if not shot.current:
  shot.make_current()
 if not interior:
  actor.visual.hide()
  var p := clampf(clock/2.8,0.0,1.0)
  shot.global_position = plane_position+Vector3(lerpf(-14.0,-8.0,p),6.5,lerpf(14.0,12.0,p))
  shot.look_at(plane_position+Vector3(0,0.5,0))
  return
 actor.visual.show()
 actor.global_position = timeline.world_point(plane_position,timeline.actor_local)
 actor.visual.rotation = Vector3(0,PI*0.5,0)
 if actor.model_loaded:
  # Use the existing sprint blend above the terrestrial sprint threshold.
  var sprinting: bool = timeline.actor_speed>4.2
  actor.raze.locomotion(delta,timeline.actor_speed,true,false,false,sprinting,0.0,Vector2(0,-timeline.actor_speed),Vector2.ZERO,false)
 # Camera stays inside the cabin and follows the player until the intentional exterior cut.
 var z := clampf(timeline.actor_local.z-2.25,-4.4,2.6)
 shot.global_position = timeline.world_point(plane_position,Vector3(0.35,1.64,z))
 var look := timeline.world_point(plane_position,Vector3(0,1.15,minf(6.4,timeline.actor_local.z+2.0)))
 shot.look_at(look)

func release() -> void:
 active = false
 interior = false
 cabin.hide()
 actor.visual.show()
 actor.camera.make_current()

func status_text() -> String:
 if not timeline.requested: return "PULSA SALTAR · PREPARADO"
 if timeline.opening<1.0: return "ABRIENDO RAMPA"
 return "SALIDA AUTORIZADA"
