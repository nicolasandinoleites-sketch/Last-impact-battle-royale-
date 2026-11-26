extends RefCounted
# Presentation only: poses are authored in RAZE source skeleton axes.
const JOINTS := ["L_Upperarm","R_Upperarm","L_Forearm","R_Forearm","L_Thigh","R_Thigh","L_Calf","R_Calf","Spine01","Spine02","Head"]
var ids: Array[int] = []
var base: Array[Quaternion] = []
var axes: Array[Basis] = []
var filtered_steering := Vector2.ZERO
var landing_weight := 0.0
func setup(s: Skeleton3D) -> bool:
 ids.clear()
 base.clear()
 axes.clear()
 filtered_steering = Vector2.ZERO
 landing_weight = 0.0
 for name in JOINTS:
  var id:=s.find_bone(name)
  if id<0:
   ids.clear()
   return false
  ids.append(id)
  base.append(s.get_bone_pose_rotation(id))
  axes.append(s.get_bone_global_rest(id).basis.orthonormalized().inverse())
 return true

func update(s:Skeleton3D,delta:float,phase:int,steering:Vector2,clock:float,phase_progress:float=0.0) -> void:
 var dt := clampf(delta,0.0,0.05)
 filtered_steering = filtered_steering.lerp(steering.limit_length(1.0),1.0-exp(-dt*6.0))
 var fall := phase==2
 var glide := phase==3
 var active := fall or glide
 var bank := filtered_steering.x
 var dive := -filtered_steering.y
 var breathe := sin(clock*2.6)*2.3 if active else 0.0
 var flutter := sin(clock*5.0)*2.5 if fall else 0.0
 var spread := 68.0 if fall else 39.0
 var elbow := 20.0 if fall else 10.0
 var goals: Array[Vector3] = []
 landing_weight = 0.0
 if active:
  goals = [Vector3(-12+dive*7,0,spread+bank*11+breathe),Vector3(-12+dive*7,0,-spread+bank*11-breathe),Vector3(-elbow-flutter,0,0),Vector3(-elbow+flutter,0,0),Vector3(15+dive*8+flutter,0,8+bank*3),Vector3(12+dive*8-flutter,0,-8+bank*3),Vector3(26+flutter if fall else 14,0,0),Vector3(23-flutter if fall else 12,0,0),Vector3(7+dive*5,0,bank*7),Vector3(5+dive*4,bank*3,bank*6),Vector3(-12 if fall else -5,-bank*5,0)]
 elif phase==4:
  # Brief impact absorption, then return to neutral before the ground controller resumes.
  var p := clampf(phase_progress,0.0,1.0)
  landing_weight = smoothstep(0.0,0.23,p)*(1.0-smoothstep(0.23,0.95,p))
  var w := landing_weight
  goals = [Vector3(-15*w,0,18*w),Vector3(-15*w,0,-18*w),Vector3(-22*w,0,0),Vector3(-22*w,0,0),Vector3(-24*w,0,3*w),Vector3(-24*w,0,-3*w),Vector3(42*w,0,0),Vector3(42*w,0,0),Vector3(13*w,0,0),Vector3(8*w,0,0),Vector3(-7*w,0,0)]
 else:
  for i in range(ids.size()):
   goals.append(Vector3.ZERO)
 var blend := 1.0-exp(-dt*(20.0 if phase==4 or phase==5 else 10.0))
 for i in range(ids.size()):
  var d := goals[i]
  var a := axes[i]
  var q := base[i]*Quaternion((a*Vector3.RIGHT).normalized(),deg_to_rad(d.x))*Quaternion((a*Vector3.UP).normalized(),deg_to_rad(d.y))*Quaternion((a*Vector3.BACK).normalized(),deg_to_rad(d.z))
  s.set_bone_pose_rotation(ids[i],s.get_bone_pose_rotation(ids[i]).slerp(q.normalized(),blend).normalized())

func restore(s: Skeleton3D) -> void:
 for i in range(ids.size()):
  s.set_bone_pose_rotation(ids[i],base[i])
 landing_weight = 0.0
 filtered_steering = Vector2.ZERO
