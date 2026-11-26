extends RefCounted
# Coordinates in source RAZE skeleton space (front +Z, height approximately 1 unit).
# Desired pose calibrated against the actual source mesh, independent of world yaw.
const BONE := "Spine02"
static func attach(skeleton: Skeleton3D, rig: Node3D) -> BoneAttachment3D:
 var index := skeleton.find_bone(BONE)
 if index<0 or rig.get_parent()!=null:
  return null
 var socket := BoneAttachment3D.new()
 socket.name = "Deployment_BackSocket"
 socket.bone_name = BONE
 skeleton.add_child(socket)
 socket.add_child(rig)
 var desired := Transform3D(Basis(Vector3.UP,PI).scaled(Vector3.ONE*0.68),Vector3(0,0.765,-0.235))
 rig.transform = skeleton.get_bone_global_rest(index).affine_inverse()*desired
 return socket
