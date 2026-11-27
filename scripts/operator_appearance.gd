extends RefCounted
# Original procedural provisional armor, attached to the existing animated rig.
const COLORS={"PHANTOM":"69508c","TITAN":"427da7","SERAPH":"c4d8ce","SPECTRE":"a99a42"}
const LIGHTS={"PHANTOM":"b49aff","TITAN":"69b8ff","SERAPH":"6de3ad","SPECTRE":"f0df72"}
static func plate(actor:Node3D,bone:String,offset:Vector3,dimensions:Vector3,color:Color,glow:bool=false)->void:
 var sk:Skeleton3D=actor.skeleton
 var id:=sk.find_bone(bone)
 if id<0:return
 var anchor:=BoneAttachment3D.new()
 anchor.bone_name=bone
 sk.add_child(anchor)
 anchor.add_to_group("provisional_armor")
 var mesh:=MeshInstance3D.new()
 var shape:=BoxMesh.new()
 shape.size=dimensions/1.8
 mesh.mesh=shape
 var mat:=StandardMaterial3D.new()
 mat.albedo_color=color
 mat.roughness=.75
 if glow:mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 mesh.material_override=mat
 mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 anchor.add_child(mesh)
 var rest:=sk.get_bone_global_rest(id).basis.orthonormalized()
 mesh.basis=rest.inverse()
 mesh.position=rest.inverse()*offset/1.8
static func apply(actor:Node3D,id:String)->void:
 if not actor.ready_model:return
 for child in actor.skeleton.get_children():
  if child.is_in_group("provisional_armor"):
   actor.skeleton.remove_child(child)
   child.queue_free()
 for node in actor.model.find_children("*","MeshInstance3D",true,false):
  for i in range(node.mesh.get_surface_count()):
   var original=node.mesh.surface_get_material(i) as StandardMaterial3D
   if original==null:continue
   var mat=original.duplicate() as StandardMaterial3D
   if OS.has_feature("android") or OS.get_environment("LASTIMPACT_SAFE_RENDER")=="1":mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
   if COLORS.has(id):mat.albedo_color=Color(COLORS[id])
   node.set_surface_override_material(i,mat)
 if not COLORS.has(id):return
 var c:=Color(COLORS[id])
 var light:=Color(LIGHTS[id])
 match id:
  "PHANTOM":
   plate(actor,"Head",Vector3(0,.06,.02),Vector3(.28,.16,.28),c)
   plate(actor,"Spine02",Vector3(0,0,-.16),Vector3(.28,.35,.10),c)
  "TITAN":
   for side in ["L","R"]:
    plate(actor,side+"_Upperarm",Vector3.ZERO,Vector3(.29,.24,.28),c)
    plate(actor,side+"_Forearm",Vector3.ZERO,Vector3(.20,.24,.20),c)
   plate(actor,"Spine02",Vector3(0,0,-.17),Vector3(.38,.35,.16),c)
  "SERAPH":
   plate(actor,"Spine02",Vector3(0,0,-.18),Vector3(.31,.36,.16),c)
   plate(actor,"Spine02",Vector3(0,0,-.27),Vector3(.18,.05,.02),light,true)
   plate(actor,"Spine02",Vector3(0,0,-.27),Vector3(.05,.18,.02),light,true)
  "SPECTRE":
   plate(actor,"Head",Vector3(0,.10,0),Vector3(.24,.09,.26),c)
   plate(actor,"Spine02",Vector3(.14,.12,-.16),Vector3(.06,.42,.07),light,true)
