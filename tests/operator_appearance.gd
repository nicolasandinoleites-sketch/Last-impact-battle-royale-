extends SceneTree
const Raze=preload("res://scripts/raze.gd")
const Appearance=preload("res://scripts/operator_appearance.gd")
func _initialize()->void:
 call_deferred("run")
func run()->void:
 var actor=Raze.new()
 root.add_child(actor)
 assert(actor.load_model())
 var bones:int=actor.skeleton.get_bone_count()
 for id in ["PHANTOM","TITAN","SERAPH","SPECTRE","RAZE"]:
  Appearance.apply(actor,id)
  var count:=0
  for child in actor.skeleton.get_children():
   if child.is_in_group("provisional_armor"):count+=1
  assert(count>0 if id!="RAZE" else count==0)
  assert(actor.skeleton.get_bone_count()==bones and is_instance_valid(actor.right_socket))
  actor.locomotion(.016,3.8,true,false,false)
 print("R0797 APPEARANCE PASS")
 actor.queue_free()
 await process_frame
 quit()
