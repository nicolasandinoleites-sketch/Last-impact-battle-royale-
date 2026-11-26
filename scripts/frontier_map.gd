extends Node3D
const Art = preload("res://scripts/arena_art.gd")
const HALF := 64.0
const CELL := 2.0
const CELLS := 64
var game
var grid := AStarGrid2D.new()
var obstacles: Array[Rect2] = []
var buildings: Array[Rect2] = []
var sectors: Array[Dictionary] = []
var decor
var routes_ready := false
var loot_sites: Array[Vector3] = [
	Vector3(-3,0,10),Vector3(3,0,10),Vector3(0,0,7),
	Vector3(-38,0,-34),Vector3(38,0,-34),Vector3(-38,0,33),Vector3(38,0,33),
	Vector3(-28,0,-25),Vector3(28,0,-25),Vector3(-28,0,25),Vector3(28,0,25),
	Vector3(-12,0,-20),Vector3(12,0,-20),Vector3(-18,0,8),Vector3(18,0,8),
	Vector3(-48,0,0),Vector3(48,0,0),Vector3(0,0,-45),Vector3(0,0,45)]
var building_centers: Array[Vector3] = [Vector3(-38,0,-34),Vector3(38,0,-34),Vector3(-38,0,33),Vector3(38,0,33)]

func build(owner_game) -> void:
	game = owner_game
	var floor_mat: StandardMaterial3D = game.mat("67767a")
	floor_mat.albedo_texture = Art.floor_texture()
	floor_mat.uv1_scale = Vector3(32,32,32)
	game.block(Vector3(0,-0.3,0),Vector3(HALF*2,0.6,HALF*2),floor_mat)
	var wall_mat: StandardMaterial3D = game.mat("455763")
	wall_mat.albedo_texture = Art.panel_texture()
	wall_mat.uv1_scale = Vector3(4,2,1)
	var roof_mat: StandardMaterial3D = game.mat("2f4554")
	var accent: StandardMaterial3D = game.mat("a86a42")
	accent.albedo_texture = Art.panel_texture()
	for x in [-HALF,HALF]:
		wall(Vector3(x,1.5,0),Vector3(0.6,3.0,HALF*2),wall_mat)
	for z in [-HALF,HALF]:
		wall(Vector3(0,1.5,z),Vector3(HALF*2,3.0,0.6),wall_mat)
	sectors = [
		{"name":"HELIX","rect":Rect2(-62,-62,62,62),"color":Color("455e65")},
		{"name":"NEXUS","rect":Rect2(0,-62,62,62),"color":Color("4f5d72")},
		{"name":"FORGE","rect":Rect2(-62,0,62,62),"color":Color("71645a")},
		{"name":"HARBOR","rect":Rect2(0,0,62,62),"color":Color("526b66")}]
	for sector in sectors:
		var area: Rect2 = sector["rect"]
		var center := area.get_center()
		var tile: StandardMaterial3D = game.mat("ffffff")
		tile.albedo_color = sector["color"]
		tile.albedo_texture = Art.floor_texture()
		tile.uv1_scale = Vector3(16,16,16)
		slab(Vector3(center.x,0.006,center.y),Vector3(area.size.x,0.012,area.size.y),tile)
	for center in building_centers:
		building(center,wall_mat,roof_mat,accent)
	for p in [Vector3(-6,0.75,1),Vector3(7,0.75,3),Vector3(4,0.75,-10),Vector3(-11,0.75,-14),Vector3(15,0.75,-4),Vector3(-25,0.75,0),Vector3(25,0.75,0),Vector3(-12,0.75,34),Vector3(12,0.75,-34)]:
		wall(p,Vector3(2.5,1.5,1.3),accent)
	decor = Art.new()
	add_child(decor)
	var strips: Array[Transform3D] = []
	var lights: Array[Transform3D] = []
	var details: Array[Transform3D] = []
	for i in range(-56,57,4):
		for side in [-1.0,1.0]:
			strips.append(decor.piece(Vector3(i,0.026,side*3.0),Vector3(2.0,0.018,0.12)))
			strips.append(decor.piece(Vector3(side*3.0,0.026,i),Vector3(0.12,0.018,2.0)))
	for center in building_centers:
		for side in [-1.0,1.0]:
			lights.append(decor.piece(center+Vector3(side*2.15,2.55,-5.06),Vector3(0.15,1.0,0.06)))
			lights.append(decor.piece(center+Vector3(side*2.15,2.55,5.06),Vector3(0.15,1.0,0.06)))
			details.append(decor.piece(center+Vector3(side*5.1,3.92,0),Vector3(0.18,0.12,10.4)))
		details.append(decor.piece(center+Vector3(0,4.1,0),Vector3(3.2,0.38,2.4)))
	decor.batch("8dadae",strips)
	decor.batch("6fd2e5",lights)
	decor.batch("b67c47",details)
	build_grid()

func slab(pos: Vector3, dimensions: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)

func wall(pos: Vector3, dimensions: Vector3, material: Material) -> void:
	game.block(pos,dimensions,material)
	obstacles.append(Rect2(Vector2(pos.x-dimensions.x*0.5,pos.z-dimensions.z*0.5),Vector2(dimensions.x,dimensions.z)))

func building(center: Vector3, material: Material, roof: Material, accent: Material) -> void:
	buildings.append(Rect2(Vector2(center.x-5.0,center.z-5.0),Vector2(10,10)))
	# Both north and south entrances remain open; roof clearance is 3.55 m.
	for side in [-1.0,1.0]:
		wall(center+Vector3(side*5.0,1.8,0),Vector3(0.35,3.6,10.35),material)
		for x in [-3.65,3.65]:
			wall(center+Vector3(x,1.8,side*5.0),Vector3(2.7,3.6,0.35),material)
		game.block(center+Vector3(0,3.35,side*5.0),Vector3(4.6,0.5,0.35),accent)
	game.block(center+Vector3(0,3.75,0),Vector3(10.6,0.4,10.6),roof)

func cell_at(p: Vector3) -> Vector2i:
	return Vector2i(clampi(floori((p.x+HALF)/CELL),0,CELLS-1),clampi(floori((p.z+HALF)/CELL),0,CELLS-1))

func cell_center(id: Vector2i) -> Vector3:
	return Vector3(float(id.x)*CELL-HALF+CELL*0.5,0,float(id.y)*CELL-HALF+CELL*0.5)

func build_grid() -> void:
	grid.region = Rect2i(0,0,CELLS,CELLS)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for x in range(CELLS):
		for z in range(CELLS):
			var id := Vector2i(x,z)
			var center := cell_center(id)
			for rect in obstacles:
				if rect.grow(0.75).has_point(Vector2(center.x,center.z)):
					grid.set_point_solid(id,true)
					break
	routes_ready = true

func nearest_open(id: Vector2i) -> Vector2i:
	if not grid.is_point_solid(id):
		return id
	for r in range(1,5):
		for x in range(-r,r+1):
			for z in range(-r,r+1):
				var candidate := id+Vector2i(x,z)
				if grid.is_in_boundsv(candidate) and not grid.is_point_solid(candidate):
					return candidate
	return id

func route(from: Vector3, to: Vector3) -> PackedVector3Array:
	var result := PackedVector3Array()
	if not routes_ready:
		return result
	var start := nearest_open(cell_at(from))
	var goal := nearest_open(cell_at(to))
	if grid.is_point_solid(start) or grid.is_point_solid(goal):
		return result
	for id in grid.get_id_path(start,goal):
		result.append(cell_center(id))
	return result

func sector_name(pos: Vector3) -> String:
	for sector in sectors:
		var rect: Rect2 = sector["rect"]
		if rect.has_point(Vector2(pos.x,pos.z)):
			return sector["name"]
	return "PERIMETRO"

func loot_positions(seed_value: int) -> Array[Vector3]:
	# Three guaranteed starter supplies; remaining six use unique seeded sites.
	var available: Array[Vector3] = []
	for i in range(3,loot_sites.size()):
		available.append(loot_sites[i])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var result: Array[Vector3] = [loot_sites[0],loot_sites[1],loot_sites[2]]
	for i in range(6):
		var index := rng.randi_range(0,available.size()-1)
		result.append(available.pop_at(index))
	return result
