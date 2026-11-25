extends StaticBody3D
signal destroyed
var hp := 100
var body: MeshInstance3D
var active := true
var original_material: StandardMaterial3D
var flash_material: StandardMaterial3D
var hit_time := 0.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.8,1.65,0.45)
	shape.shape = box
	shape.position.y = 0.825
	add_child(shape)
	body = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box.size
	body.mesh = mesh
	body.position = shape.position
	original_material = StandardMaterial3D.new()
	original_material.albedo_color = Color("ae6844")
	flash_material = StandardMaterial3D.new()
	flash_material.albedo_color = Color("fce3ad")
	body.material_override = original_material
	add_child(body)
	var plate := MeshInstance3D.new()
	var p := BoxMesh.new()
	p.size = Vector3(0.45,0.45,0.025)
	plate.mesh = p
	plate.position = Vector3(0,1.13,0.24)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("eee1ad")
	plate.material_override = m
	add_child(plate)

func take_hit(damage: int) -> void:
	if not active:
		return
	hp -= damage
	body.material_override = flash_material
	hit_time = 0.13
	if hp <= 0:
		active = false
		visible = false
		collision_layer = 0
		destroyed.emit()

func reset_target() -> void:
	hp = 100
	active = true
	visible = true
	collision_layer = 2
	body.material_override = original_material

func _process(delta: float) -> void:
	if hit_time > 0.0:
		hit_time -= delta
		if hit_time <= 0.0:
			body.material_override = original_material
