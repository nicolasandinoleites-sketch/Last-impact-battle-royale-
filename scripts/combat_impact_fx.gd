extends Node3D
# Shared pool: gameplay never depends on cosmetic visibility.
const RANGE := 45.0
var slots: Array[Dictionary] = []
var cursor := 0
var shot_count := 0
var impact_count := 0
var last_impact := ""
var mats: Dictionary = {}

func flat(c: Color) -> StandardMaterial3D:
 var m := StandardMaterial3D.new()
 m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 m.albedo_color = c
 return m

func configure(profile: int) -> void:
 if not slots.is_empty(): return
 mats = {"BEAM":flat(Color("ffd79a")),"SHIELD":flat(Color("55dfff")),"BODY":flat(Color("bd3038")),"WORLD":flat(Color("ffb85b"))}
 var beam_mesh := BoxMesh.new()
 beam_mesh.size = Vector3(0.025,0.025,1)
 var dot_mesh := SphereMesh.new()
 dot_mesh.radius = 0.035
 dot_mesh.height = 0.07
 dot_mesh.radial_segments = 6
 dot_mesh.rings = 3
 for i in range(8 if profile==0 else 16):
  var holder := Node3D.new()
  add_child(holder)
  var beam := MeshInstance3D.new()
  beam.mesh = beam_mesh
  beam.material_override = mats.BEAM
  beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  holder.add_child(beam)
  var dots: Array[MeshInstance3D] = []
  for j in range(4 if profile==0 else 7):
   var dot := MeshInstance3D.new()
   dot.mesh = dot_mesh
   dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   holder.add_child(dot)
   dots.append(dot)
  holder.hide()
  slots.append({"holder":holder,"beam":beam,"dots":dots,"age":1.0,"impact":false,"point":Vector3.ZERO,"normal":Vector3.UP,"seed":0})

func emit_shot(start: Vector3, end: Vector3, normal: Vector3, kind: String, viewer: Vector3) -> void:
 if slots.is_empty() or start.distance_squared_to(end)<0.0001: return
 shot_count += 1
 if kind!="":
  impact_count += 1
  last_impact = kind
 if minf(start.distance_to(viewer),end.distance_to(viewer))>RANGE: return
 var slot: Dictionary = slots[cursor]
 cursor = (cursor+1)%slots.size()
 var holder: Node3D = slot.holder
 var beam: MeshInstance3D = slot.beam
 holder.global_transform = Transform3D.IDENTITY
 beam.global_position = start.lerp(end,0.5)
 beam.look_at(end,Vector3.RIGHT if absf(start.direction_to(end).dot(Vector3.UP))>0.98 else Vector3.UP)
 beam.scale = Vector3(1,1,start.distance_to(end))
 beam.show()
 slot.age = 0.0
 slot.impact = mats.has(kind) and kind!="BEAM"
 slot.point = end
 slot.normal = normal.normalized() if normal.length_squared()>0.001 else Vector3.UP
 slot.seed = shot_count
 for dot: MeshInstance3D in slot.dots:
  dot.visible = slot.impact
  if slot.impact:
   dot.material_override = mats[kind]
   dot.global_position = end
   dot.scale = Vector3.ONE
 holder.show()

func _process(delta: float) -> void:
 for slot: Dictionary in slots:
  var holder: Node3D = slot.holder
  if not holder.visible: continue
  slot.age += delta
  var age: float = slot.age
  slot.beam.visible = age<0.095
  if age>=0.26:
   holder.hide()
   continue
  if not slot.impact: continue
  var index := 0
  for dot: MeshInstance3D in slot.dots:
   var angle := float(index)*2.39996+float(slot.seed)*0.7
   var spread := Vector3(cos(angle),sin(angle*1.7),sin(angle))
   var direction: Vector3 = slot.normal*0.75+spread*0.6
   dot.global_position = slot.point+direction*age*2.6-Vector3.UP*age*age*3.2
   dot.scale = Vector3.ONE*maxf(0.15,1.0-age/0.26)
   index += 1

func reset() -> void:
 for slot: Dictionary in slots: slot.holder.hide()
 cursor = 0
 shot_count = 0
 impact_count = 0
 last_impact = ""
