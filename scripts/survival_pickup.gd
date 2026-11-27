extends Node3D
var kind := "MED"
var quantity := 1
var initial_quantity := 1
var body: Node3D
var glow: MeshInstance3D
var phase := 0.0
var active := true

func _ready() -> void:
	initial_quantity = quantity
	body = Node3D.new()
	body.position.y = 0.32
	add_child(body)
	var box := BoxMesh.new()
	box.size = Vector3(0.58,0.29,0.42)
	part(box,Vector3.ZERO,Color("263d49"))
	var cover := BoxMesh.new()
	cover.size = Vector3(0.55,0.04,0.39)
	part(cover,Vector3(0,0.16,0),item_color())
	for x in [-0.22,0.22]:
		var trim := BoxMesh.new()
		trim.size = Vector3(0.07,0.31,0.43)
		part(trim,Vector3(x,0,0),Color("607783"))
	if kind.begins_with("WEAPON_"):
		var beacon := BoxMesh.new()
		beacon.size = Vector3(0.48,0.12,0.12)
		part(beacon,Vector3(0,0.30,0),item_color())
	var marker := TorusMesh.new()
	marker.inner_radius = 0.40
	marker.outer_radius = 0.47
	marker.rings = 16
	marker.ring_segments = 6
	glow = part(marker,Vector3(0,0.035,0),item_color())
	body.remove_child(glow)
	add_child(glow)

func item_color() -> Color:
	match kind:
		"WEAPON_VOLTAR","AMMO_LIGHT": return Color("7ad8e8")
		"WEAPON_ARC","AMMO_PLASMA": return Color("bc91f8")
		"WEAPON_HELIOS","AMMO_HEAVY": return Color("f4c378")
		"MED": return Color("68d9a4")
		"SHIELD": return Color("63bde8")
		_: return Color("ffae58")

func part(mesh: Mesh, offset: Vector3, color: Color) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.position = offset
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	n.material_override = mat
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(n)
	return n

func _process(delta: float) -> void:
	if not active:
		return
	phase += delta
	body.rotation.y += delta*0.55
	body.position.y = 0.32+sin(phase*2.2)*0.04

func collect(amount: int) -> void:
	quantity = maxi(0,quantity-maxi(0,amount))
	active = quantity>0
	visible = active

func reset_pickup() -> void:
	quantity = initial_quantity
	active = true
	visible = true
	phase = 0.0
