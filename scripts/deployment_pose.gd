extends RefCounted
# Presentation-only deployment pose in the RAZE source skeleton axes.
# A full authored skydiving clip can replace these provisional poses later.
const JOINTS := ["L_Upperarm","R_Upperarm","L_Forearm","R_Forearm","L_Thigh","R_Thigh","L_Calf","R_Calf","Spine01","Spine02","Head"]
var ids: Array[int] = []
var base: Array[Quaternion] = []
var axes: Array[Basis] = []
func setup(s: Skeleton3D) -> bool:
 ids.clear();base.clear();axes.clear()
 for name in JOINTS:
  var id:=s.find_bone(name)
  if id<0:return false
  ids.append(id);base.append(s.get_bone_pose_rotation(id));axes.append(s.get_bone_global_rest(id).basis.orthonormalized().inverse())
 return true
func update(s:Skeleton3D,delta:float,phase:int,steering:Vector2,clock:float) -> void:
 var fall:=phase==2;var glide:=phase==3
 var active:=fall or glide
 var left:=58.0 if fall else (38.0 if glide else 0.0)
 var flex:=18.0 if fall else (8.0 if glide else 0.0)
 var sway:=sin(clock*3.0)*3.0 if active else 0.0
 var goals: Array[Vector3]=[Vector3(-9,0,left+sway),Vector3(-9,0,-left+sway),Vector3(-flex,0,0),Vector3(-flex,0,0),Vector3(12 if active else 0,0,7 if active else 0),Vector3(8 if active else 0,0,-7 if active else 0),Vector3(22 if fall else (12 if glide else 0),0,0),Vector3(18 if fall else (10 if glide else 0),0,0),Vector3(4 if active else 0,0,steering.x*5 if active else 0),Vector3(3 if active else 0,0,steering.x*3 if active else 0),Vector3(-10 if fall else 0,0,0)]
 var blend:=1.0-exp(-maxf(delta,0.0)*12.0)
 for i in range(ids.size()):
  var d:=goals[i] if active else Vector3.ZERO
  var a:=axes[i]
  var q:=base[i]*Quaternion((a*Vector3.RIGHT).normalized(),deg_to_rad(d.x))*Quaternion((a*Vector3.UP).normalized(),deg_to_rad(d.y))*Quaternion((a*Vector3.BACK).normalized(),deg_to_rad(d.z))
  s.set_bone_pose_rotation(ids[i],s.get_bone_pose_rotation(ids[i]).slerp(q.normalized(),blend).normalized())
