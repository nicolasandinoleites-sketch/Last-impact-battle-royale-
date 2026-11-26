extends Node3D
# Independent interior set. Source exterior GLB has a fused cargo door.
# Coordinates: +Z toward the rear ramp, floor Y=0, metres.
const EXIT_Z := 6.0
const EXIT_Y := -0.58
var ramp: Node3D
var signal_material: StandardMaterial3D
var opening := 0.0
var cabin_ready := false
var steel: StandardMaterial3D
var trim: StandardMaterial3D
var rubber: StandardMaterial3D
var amber: StandardMaterial3D
var strips: StandardMaterial3D

func material(color: Color, emissive: bool = false) -> StandardMaterial3D:
 var m := StandardMaterial3D.new()
 m.albedo_color = color
 m.roughness = 0.72
 if emissive:
  m.emission_enabled = true
  m.emission = color
  m.emission_energy_multiplier = 1.3
 return m

func block(parent: Node3D, label: String, p: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
 var node := MeshInstance3D.new()
 node.name = label
 var mesh := BoxMesh.new()
 mesh.size = size
 node.mesh = mesh
 node.material_override = mat
 node.position = p
 parent.add_child(node)
 return node

func build() -> void:
 if cabin_ready: return
 steel = material(Color(0.13,0.17,0.21))
 trim = material(Color(0.27,0.33,0.38))
 rubber = material(Color(0.075,0.09,0.105))
 amber = material(Color(0.80,0.44,0.075))
 strips = material(Color(0.57,0.79,0.98),true)
 signal_material = material(Color(0.94,0.12,0.07),true)
 block(self,"Floor",Vector3(0,-0.11,-0.5),Vector3(3.8,0.22,9.0),steel)
 block(self,"Ceiling",Vector3(0,2.87,-0.5),Vector3(3.8,0.25,9.0),steel)
 block(self,"Forward_bulkhead",Vector3(0,1.4,-4.9),Vector3(3.8,2.8,0.18),steel)
 for side in [-1.0,1.0]:
  block(self,"Hull_wall",Vector3(side*1.91,1.4,-0.5),Vector3(0.18,2.8,9.0),steel)
  block(self,"Floor_track",Vector3(side*0.62,0.015,-0.6),Vector3(0.045,0.025,8.5),amber)
  block(self,"Overhead_light",Vector3(side*1.15,2.72,-0.5),Vector3(0.09,0.04,7.8),strips)
  block(self,"Upper_duct",Vector3(side*1.55,2.57,-0.5),Vector3(0.38,0.32,8.6),trim)
  for i in range(6):
   var z: float = -3.7+i*1.34
   block(self,"Wall_rib",Vector3(side*1.77,1.43,z),Vector3(0.14,2.72,0.13),trim)
   block(self,"Ceiling_rib",Vector3(side*0.93,2.68,z),Vector3(1.75,0.12,0.13),trim)
   block(self,"Seat_base",Vector3(side*1.49,0.48,z+0.4),Vector3(0.55,0.11,0.71),rubber)
   block(self,"Seat_back",Vector3(side*1.73,0.90,z+0.4),Vector3(0.10,0.74,0.69),rubber)
   block(self,"Seat_support",Vector3(side*1.5,0.23,z+0.4),Vector3(0.13,0.43,0.11),trim)
   block(self,"Harness",Vector3(side*1.66,0.98,z+0.22),Vector3(0.035,0.67,0.07),amber)
   block(self,"Harness",Vector3(side*1.66,0.98,z+0.58),Vector3(0.035,0.67,0.07),amber)
  block(self,"Rear_jamb",Vector3(side*1.79,1.4,3.93),Vector3(0.23,2.8,0.22),trim)
  block(self,"Low_guide_strip",Vector3(side*1.78,0.22,-0.55),Vector3(0.035,0.06,8.3),strips)
  block(self,"Jump_signal",Vector3(side*1.51,2.36,3.77),Vector3(0.19,0.16,0.10),signal_material)
 for i in range(15):
  block(self,"Deck_seam",Vector3(0,0.009,-4.65+i*0.58),Vector3(3.55,0.017,0.018),rubber)
 block(self,"Rear_header",Vector3(0,2.72,3.93),Vector3(3.6,0.26,0.23),trim)
 block(self,"Upper_transom",Vector3(0,2.48,3.97),Vector3(3.35,0.49,0.16),trim)
 ramp = Node3D.new()
 ramp.name = "RearRamp_Hinge"
 ramp.position = Vector3(0,0.02,3.95)
 add_child(ramp)
 block(ramp,"Ramp_deck",Vector3(0,-0.065,1.12),Vector3(3.34,0.13,2.24),trim)
 for i in range(7):
  block(ramp,"Grip_bar",Vector3(0,0.012,0.14+i*0.31),Vector3(3.0,0.024,0.044),rubber)
 for side in [-1.0,1.0]:
  block(ramp,"Ramp_edge",Vector3(side*1.59,0.02,1.12),Vector3(0.095,0.04,2.18),amber)
 var lamp := OmniLight3D.new()
 lamp.position=Vector3(0,2.25,-0.8)
 lamp.light_color=Color(0.72,0.83,1.0)
 lamp.light_energy=2.1
 lamp.omni_range=7.0
 lamp.shadow_enabled=false
 add_child(lamp)
 var label := Label3D.new()
 label.text="FRONTIER  /  DROP BAY 01"
 label.position=Vector3(0,2.39,-4.77)
 label.font_size=54
 label.pixel_size=0.005
 label.modulate=Color(0.9,0.79,0.50)
 add_child(label)
 cabin_ready=true
 set_opening(0.0)

func set_opening(value: float) -> void:
 opening=clampf(value,0.0,1.0)
 if not cabin_ready: return
 ramp.rotation.x=lerpf(-PI*0.5,deg_to_rad(15.8),smoothstep(0.0,1.0,opening))
 var ready:=opening>=0.99
 signal_material.albedo_color=Color(0.10,1.0,0.36) if ready else Color(0.94,0.12,0.07)
 signal_material.emission=signal_material.albedo_color

func ramp_height(z:float) -> float:
 return minf(0.0,-maxf(0.0,z-3.95)*tan(deg_to_rad(15.8)))
