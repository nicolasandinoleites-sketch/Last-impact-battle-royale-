extends Node3D
const Raze = preload("res://scripts/raze.gd")
var actors: Array[Node3D] = []
var ticks := 0.0

func build(profile: int) -> void:
 if not actors.is_empty(): return
 # Two seated operators on low; up to four on higher profiles. Shared textures.
 var seats := [Vector2(-1,0.72),Vector2(1,2.06),Vector2(1,-0.62),Vector2(-1,3.4)]
 for i in range(2 if profile==0 else 4):
  var seat: Vector2 = seats[i]
  var actor := Raze.new()
  add_child(actor)
  actor.position = Vector3(seat.x*1.49,-0.40,seat.y)
  actor.rotation.y = seat.x*PI*0.5
  if not actor.load_model():
   actor.queue_free()
   continue
  # Pose using existing skeleton; actual foot targets on cabin floor.
  for side in ["L","R"]:
   actor.bone_motion(side+"_Upperarm",Vector3(-25,0,0),1.0)
   actor.bone_motion(side+"_Forearm",Vector3(-55,0,0),1.0)
   var lateral := -0.16 if side=="L" else 0.16
   var goal: Vector3 = actor.to_global(Vector3(lateral,0.47,-0.53))
   actor.solve_leg(side,goal,-actor.global_transform.basis.z)
  actor.skeleton.force_update_all_bone_transforms()
  actors.append(actor)
 hide()

func set_active(value: bool) -> void:
 visible = value
 if not value: ticks = 0.0

func step(delta: float) -> void:
 if not visible: return
 ticks += delta
 # At most 10 pose updates/s for each static extra; no weapons, AI or physics.
 if ticks<0.1: return
 ticks = 0.0
 for i in range(actors.size()):
  var actor = actors[i]
  actor.bone_motion("Head",Vector3(2.0*sin(Time.get_ticks_msec()*0.002+i),4.0*sin(Time.get_ticks_msec()*0.001+i),0),0.35)
