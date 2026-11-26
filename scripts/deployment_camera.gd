extends RefCounted
# Additive camera targets, never root motion. Retain user look input.
var fov := 60.0
var distance := 2.85
var shoulder := 0.64
var pitch_offset := 0.0
var roll := 0.0
var height := 1.36

func reset() -> void:
 fov = 60.0
 distance = 2.85
 shoulder = 0.64
 pitch_offset = 0.0
 roll = 0.0
 height = 1.36

func step(delta: float, phase: int, steer: Vector2, landing_progress: float) -> void:
 var goal_fov := 60.0
 var goal_distance := 2.85
 var goal_shoulder := 0.64
 var goal_pitch := 0.0
 var goal_roll := 0.0
 var goal_height := 1.36
 var settle := 7.0
 match phase:
  0,1:
   goal_fov = 68.0
   goal_distance = 3.7
   goal_shoulder = 0.12
   goal_pitch = -0.06
  2:
   goal_fov = 78.0
   goal_distance = 4.5
   goal_shoulder = 0.0
   goal_pitch = -0.24
   goal_roll = -steer.x*0.055
  3:
   goal_fov = 72.0
   goal_distance = 4.0
   goal_shoulder = 0.0
   goal_pitch = -0.12
   goal_roll = -steer.x*0.035
  4:
   var p := clampf(landing_progress,0.0,1.0)
   var impact := smoothstep(0.0,0.2,p)*(1.0-smoothstep(0.2,0.7,p))
   goal_height -= 0.12*impact
   settle = 14.0
  5:
   settle = 18.0
 var blend := 1.0-exp(-clampf(delta,0.0,0.05)*settle)
 fov = lerpf(fov,goal_fov,blend)
 distance = lerpf(distance,goal_distance,blend)
 shoulder = lerpf(shoulder,goal_shoulder,blend)
 pitch_offset = lerpf(pitch_offset,goal_pitch,blend)
 roll = lerpf(roll,goal_roll,blend)
 height = lerpf(height,goal_height,blend)
