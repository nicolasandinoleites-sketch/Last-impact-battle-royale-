extends CharacterBody3D
# Arcade ground vehicles with actual world collision. Visual prototype; no weapon turret.
var model_id := "VELOCITY"
var spawn_point := Vector3.ZERO
var speed := 0.0
var hp := 100
var max_hp := 100
var occupied := false
var max_speed := 17.0
var acceleration := 11.0
var turn_rate := 1.9
var visual: Node3D
var thrusters: Array[MeshInstance3D] = []
var wheels: Array[MeshInstance3D] = []

func material(color: Color, luminous: bool = false) -> StandardMaterial3D:
 var m := StandardMaterial3D.new()
 m.albedo_color = color
 m.roughness = 0.66
 if luminous: m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 return m

func part(shape: Mesh, offset: Vector3, mat: Material) -> MeshInstance3D:
 var mesh := MeshInstance3D.new()
 mesh.mesh = shape
 mesh.material_override = mat
 mesh.position = offset
 mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 visual.add_child(mesh)
 return mesh

func box(size: Vector3, offset: Vector3, mat: Material) -> MeshInstance3D:
 var mesh := BoxMesh.new()
 mesh.size = size
 return part(mesh,offset,mat)

func _ready() -> void:
 spawn_point = position
 var bike := model_id=="VELOCITY"
 max_hp = 100 if bike else 180
 max_speed = 17.0 if bike else 12.0
 acceleration = 11.0 if bike else 7.0
 turn_rate = 1.9 if bike else 1.2
 collision_layer = 1
 collision_mask = 1
 var collider := CollisionShape3D.new()
 var shape := BoxShape3D.new()
 shape.size = Vector3(1.05,1.0,2.35) if bike else Vector3(2.1,1.4,3.7)
 collider.shape = shape
 collider.position.y = shape.size.y*0.5
 add_child(collider)
 visual = Node3D.new()
 add_child(visual)
 var shell := material(Color("3e5664") if bike else Color("46535d"))
 var dark := material(Color("17232b"))
 var glow := material(Color("54ddff") if bike else Color("e6a64b"),true)
 if bike:
  box(Vector3(0.56,0.42,2.2),Vector3(0,0.62,0),shell)
  box(Vector3(0.58,0.23,0.85),Vector3(0,0.91,0.32),dark)
  box(Vector3(0.55,0.35,0.5),Vector3(0,1.0,-0.73),shell)
  for side in [-1.0,1.0]:
   box(Vector3(0.26,0.27,1.62),Vector3(side*0.40,0.35,0.08),dark)
   thrusters.append(box(Vector3(0.21,0.08,1.25),Vector3(side*0.40,0.19,0.08),glow))
 else:
  box(Vector3(1.8,0.72,3.35),Vector3(0,0.78,0),shell)
  box(Vector3(1.45,0.64,1.35),Vector3(0,1.36,-0.4),dark)
  box(Vector3(1.24,0.28,0.035),Vector3(0,1.45,-1.085),glow)
  for side in [-1.0,1.0]:
   for z in [-1.12,0.0,1.12]:
    var tire := CylinderMesh.new()
    tire.top_radius=0.39
    tire.bottom_radius=0.39
    tire.height=0.28
    tire.radial_segments=10
    var wheel := part(tire,Vector3(side*0.98,0.41,z),dark)
    wheel.rotation.z=PI*0.5
    wheels.append(wheel)
   thrusters.append(box(Vector3(0.10,0.08,0.33),Vector3(side*0.72,0.8,1.70),glow))
 reset_vehicle()

func reset_vehicle() -> void:
 position = spawn_point
 rotation = Vector3.ZERO
 velocity = Vector3.ZERO
 speed = 0.0
 hp = max_hp
 occupied = false
 collision_layer = 1
 show()
 reset_physics_interpolation()

func take_hit(amount: int) -> void:
 if hp<=0: return
 hp = maxi(0,hp-maxi(0,amount))
 if hp==0:
  speed=0.0
  velocity=Vector3.ZERO
  visual.hide()
  collision_layer=0

func drive(delta: float, input: Vector2) -> void:
 if hp<=0 or not occupied: return
 var throttle := clampf(-input.y,-0.45,1.0)
 var wanted := throttle*max_speed
 speed = move_toward(speed,wanted,delta*(acceleration if absf(throttle)>0.05 else acceleration*1.6))
 if absf(speed)>0.15:
  rotation.y -= input.x*turn_rate*delta*clampf(absf(speed)/4.0,0.25,1.0)*signf(speed)
 var heading := -global_basis.z
 velocity.x = heading.x*speed
 velocity.z = heading.z*speed
 velocity.y = -0.1 if is_on_floor() else velocity.y-delta*18.0
 move_and_slide()
 for i in range(get_slide_collision_count()):
  if absf(get_slide_collision(i).get_normal().y)<0.5:
   speed *= 0.25
   break
 for wheel in wheels: wheel.rotate_object_local(Vector3.UP,speed*delta/0.39)
 for light in thrusters: light.scale.y = 1.0+absf(speed)/max_speed*1.6
