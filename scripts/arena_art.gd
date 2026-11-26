extends Node3D
# Decorative, collision-free art on the existing arena. One shared material per batch.
var batch_count := 0
var decoration_count := 0
# Shared deterministic tile textures, generated once per process.
static var floor_cache: ImageTexture
static var panel_cache: ImageTexture

static func floor_texture() -> ImageTexture:
	if is_instance_valid(floor_cache):
		return floor_cache
	var img := Image.create(256,256,false,Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 620
	for y in range(256):
		for x in range(256):
			var coarse := sin(float(x)*TAU/128.0)*cos(float(y)*TAU/128.0)*0.025
			var shade := 0.84+coarse+rng.randf_range(-0.028,0.028)
			if x<4 or y<4:
				shade *= 0.72
			elif x==4 or y==4:
				shade *= 1.10
			elif (x<18 or x>237) and (y<18 or y>237):
				var dx := float(x-12 if x<18 else x-244)
				var dy := float(y-12 if y<18 else y-244)
				if dx*dx+dy*dy<12.0:
					shade *= 0.72
			img.set_pixel(x,y,Color(shade,shade,shade))
	img.generate_mipmaps()
	floor_cache = ImageTexture.create_from_image(img)
	return floor_cache

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
	# Distant industrial skyline outside the playable boundary, no new collisions.
	for x in range(-36,37,12):
		var h := 6.4+float(posmod(int(x/12.0),3))*1.2
		steel.append(piece(Vector3(x,h*0.5,-43),Vector3(8,h,3)))
		trim.append(piece(Vector3(x,h-0.05,-43),Vector3(8.1,0.16,3.1)))
		steel.append(piece(Vector3(x+1.7,h+0.55,-43),Vector3(2.4,1.1,1.8)))
		for dx in [-2.5,0.0,2.5]:
			pale.append(piece(Vector3(x+dx,4.5,-41.48),Vector3(1.2,0.65,0.045)))
	for z in range(-30,31,12):
		for x in [-43,43]:
			steel.append(piece(Vector3(x,2.8,z),Vector3(3,5.6,7)))
			pale.append(piece(Vector3(x-signf(x)*1.52,3.6,z),Vector3(0.045,0.55,3.0)))
	batch("34434c",steel)
	batch("d78b41",trim)
	batch("b4b7a6",lines)
	batch("728c97",pale)

static func panel_texture() -> ImageTexture:
	if is_instance_valid(panel_cache):
		return panel_cache
	var img := Image.create(256,256,false,Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 921
	for y in range(256):
		for x in range(256):
			var value := 0.91+rng.randf_range(-0.022,0.022)
			var edge := mini(mini(x,255-x),mini(y,255-y))
			if edge<4:
				value *= 0.72
			elif edge<7:
				value *= 1.055
			elif edge<10:
				value *= 0.93
			if y>220:
				value *= lerpf(1.0,0.84,float(y-220)/35.0)
			# Recessed decorative vents on the panel, not geometry.
			if x>25 and x<231 and y>184 and y<212 and posmod(y-184,7)<2:
				value *= 0.78
			var bolt_x := mini(absi(x-15),absi(x-240))
			var bolt_y := mini(absi(y-15),absi(y-240))
			if bolt_x*bolt_x+bolt_y*bolt_y<16:
				value *= 0.60
			img.set_pixel(x,y,Color(value,value,value))
	img.generate_mipmaps()
	panel_cache = ImageTexture.create_from_image(img)
	return panel_cache
