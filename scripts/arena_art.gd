extends Node3D
# Decorative, collision-free art on the existing arena. One shared material per batch.
var batch_count := 0
var decoration_count := 0
static func floor_texture() -> ImageTexture:
	var img := Image.create(128,128,false,Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 620
	for y in range(128):
		for x in range(128):
			var shade := 0.84+rng.randf_range(-0.035,0.035)
			if x<2 or y<2:
				shade *= 0.80
			elif x==2 or y==2:
				shade *= 1.10
			img.set_pixel(x,y,Color(shade,shade,shade))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func batch(color: String, transforms: Array[Transform3D]) -> void:
	if transforms.is_empty():
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var cube := BoxMesh.new()
	cube.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cube
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i,transforms[i])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)
	batch_count += 1
	decoration_count += transforms.size()

func piece(p: Vector3,s: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY.scaled(s),p)

func decorate(_arena: Node3D) -> void:
	var steel: Array[Transform3D] = []
	var trim: Array[Transform3D] = []
	var lines: Array[Transform3D] = []
	var pale: Array[Transform3D] = []
	for p in [Vector3(-6,0.75,1),Vector3(7,0.75,3),Vector3(4,0.75,-10),Vector3(-11,0.75,-14),Vector3(15,0.75,-4)]:
		for dx in [-1.13,1.13]:
			for dz in [-0.66,0.66]:
				steel.append(piece(p+Vector3(dx,0,dz),Vector3(0.12,1.51,0.045)))
		for dz in [-0.66,0.66]:
			trim.append(piece(p+Vector3(0,0.62,dz),Vector3(2.45,0.08,0.045)))
			steel.append(piece(p+Vector3(0,-0.58,dz),Vector3(2.45,0.17,0.045)))
		steel.append(piece(p+Vector3(0,0.76,0),Vector3(2.50,0.035,1.30)))
	for x in [-23,23]:
		for z in [-10,14]:
			var w := 7.0 if z==-10 else 5.0
			var depth := 5.0 if z==-10 else 7.0
			var p := Vector3(x,1.5,z)
			for dx in [-w*0.46,w*0.46]:
				for dz in [-depth*0.505,depth*0.505]:
					steel.append(piece(p+Vector3(dx,0,dz),Vector3(0.18,3.0,0.04)))
			for dz in [-depth*0.505,depth*0.505]:
				trim.append(piece(p+Vector3(0,0.95,dz),Vector3(w,0.12,0.045)))
				pale.append(piece(p+Vector3(0,0.45,dz),Vector3(w*0.53,0.44,0.045)))
			steel.append(piece(p+Vector3(0,1.51,0),Vector3(w,0.05,depth)))
	for x in range(-35,36,5):
		for z in [-38.9,38.9]:
			steel.append(piece(Vector3(x,1.5,z),Vector3(0.13,2.8,0.08)))
			trim.append(piece(Vector3(x,2.7,z),Vector3(0.45,0.10,0.1)))
	for z in range(-34,35,4):
		for x in [-3.0,3.0]:
			lines.append(piece(Vector3(x,0.017,z),Vector3(0.09,0.016,1.45)))
	for x in range(-30,31,6):
		lines.append(piece(Vector3(x,0.017,28),Vector3(2.3,0.016,0.09)))
	batch("34434c",steel)
	batch("d78b41",trim)
	batch("b4b7a6",lines)
	batch("728c97",pale)
