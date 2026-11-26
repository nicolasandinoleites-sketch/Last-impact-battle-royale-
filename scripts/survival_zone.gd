extends Node3D
const START_RADIUS := 34.0
const END_RADIUS := 6.0
const GRACE := 18.0
const SHRINK_TIME := 132.0
var radius := START_RADIUS
var elapsed := 0.0
var phase := 0
var ring: MeshInstance3D

func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("5ecdf2")
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP,material)
	for i in range(97):
		var angle := float(i)*TAU/96.0
		mesh.surface_add_vertex(Vector3(cos(angle),0.0,sin(angle)))
	mesh.surface_end()
	ring = MeshInstance3D.new()
	ring.mesh = mesh
	ring.position.y = 0.065
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	reset_zone()

func reset_zone() -> void:
	elapsed = 0.0
	radius = START_RADIUS
	phase = 0
	update_ring()

func advance(delta: float) -> void:
	elapsed += maxf(delta,0.0)
	var progress := clampf((elapsed-GRACE)/SHRINK_TIME,0.0,1.0)
	radius = lerpf(START_RADIUS,END_RADIUS,progress)
	phase = 0 if elapsed<GRACE else (2 if progress>=1.0 else 1)
	update_ring()

func update_ring() -> void:
	if is_instance_valid(ring):
		ring.scale = Vector3(radius,1.0,radius)

func outside(world_position: Vector3) -> bool:
	var p := to_local(world_position)
	return Vector2(p.x,p.z).length()>radius

func seconds_remaining() -> int:
	return ceili(maxf(0.0,(GRACE if phase==0 else GRACE+SHRINK_TIME)-elapsed))
