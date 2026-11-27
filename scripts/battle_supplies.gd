extends Node3D
# Match-local economy and fictional energy equipment. Shared meshes, no new physics bodies.
var game
var credits := 300
var grenades := 2
var upgrades: Dictionary = {}
var station: Node3D
var crate: Node3D
var canopy: MeshInstance3D
var orb: MeshInstance3D
var blade: MeshInstance3D
var elapsed := 0.0
var drop_clock := 0.0
var drop_state := 0
var drop_site := Vector3.ZERO
var orb_clock := 0.0
var orb_start := Vector3.ZERO
var orb_end := Vector3.ZERO
var melee_left := 0.0
var drop_count := 0
const SHOP_POS := Vector3(0,0,24)

func mesh_part(parent: Node3D, size: Vector3, offset: Vector3, color: Color) -> MeshInstance3D:
 var part := MeshInstance3D.new()
 var box := BoxMesh.new()
 box.size = size
 part.mesh = box
 var mat := StandardMaterial3D.new()
 mat.albedo_color = color
 mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 part.material_override = mat
 part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 parent.add_child(part)
 part.position = offset
 return part

func configure(owner_game) -> void:
 game = owner_game
 station = Node3D.new()
 add_child(station)
 station.position = SHOP_POS
 mesh_part(station,Vector3(1.5,1.25,0.7),Vector3(0,0.625,0),Color("23394d"))
 mesh_part(station,Vector3(1.2,0.3,0.05),Vector3(0,0.95,0.38),Color("45dfb3"))
 var label := Label3D.new()
 label.text = "ARMERIA"
 label.position.y = 1.7
 label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
 label.pixel_size = 0.008
 station.add_child(label)
 crate = Node3D.new()
 add_child(crate)
 mesh_part(crate,Vector3(1.35,0.8,0.95),Vector3(0,0.4,0),Color("354459"))
 mesh_part(crate,Vector3(1.40,0.12,0.99),Vector3(0,0.8,0),Color("d5a54c"))
 canopy = mesh_part(crate,Vector3(1.6,0.06,1.6),Vector3(0,1.8,0),Color("51e8ff"))
 orb = mesh_part(self,Vector3.ONE*0.18,Vector3.ZERO,Color("c98cff"))
 blade = mesh_part(self,Vector3(0.09,0.08,0.85),Vector3.ZERO,Color("80efff"))
 reset()

func reset() -> void:
 credits = 300
 grenades = 2
 upgrades.clear()
 elapsed = 0.0
 drop_clock = 0.0
 drop_state = 0
 drop_count = 0
 orb_clock = 0.0
 melee_left = 0.0
 crate.hide()
 orb.hide()
 blade.hide()

func available() -> bool:
 return not game.deployment_active() and game.round_result==""

func near_shop() -> bool:
 return available() and game.player.global_position.distance_to(station.global_position)<3.0

func has_upgrade(id: String, key: String) -> bool:
 return bool(upgrades.get(id,{}).get(key,false))

func buy_upgrade(key: String) -> bool:
 if not near_shop() or key not in ["MAG","RELOAD"] or has_upgrade(game.weapon_id,key): return false
 var cost := 100 if key=="MAG" else 125
 if credits<cost: return false
 credits -= cost
 var data: Dictionary = upgrades.get(game.weapon_id,{})
 data[key] = true
 upgrades[game.weapon_id] = data
 game.message = "ACCESORIO INSTALADO: "+key
 return true

func next_store_weapon() -> String:
 for id in game.Arsenal.ORDER:
  if not game.owned_weapons.has(id): return id
 return ""

func buy_weapon() -> bool:
 if not near_shop() or credits<200: return false
 var id := next_store_weapon()
 if id.is_empty() or not game.equip_weapon(id,true): return false
 credits -= 200
 # Customized store loadout: fast reload module included.
 upgrades[id] = {"RELOAD":true}
 game.message = game.weapon_name()+" PERSONALIZADA"
 return true

func spawn_airdrop() -> bool:
 if drop_state!=0: return false
 var candidates: Array[Vector3] = [Vector3(-19,0,-19),Vector3(19,0,-19),Vector3(-19,0,19),Vector3(19,0,19),Vector3(0,0,0)]
 for p in candidates:
  if game.zone.outside(p) or game.frontier.grid.is_point_solid(game.frontier.cell_at(p)): continue
  drop_site = p
  drop_state = 1
  drop_clock = 0.0
  crate.global_position = p+Vector3.UP*20.0
  canopy.show()
  crate.show()
  game.message = "AIRDROP EN DESCENSO"
  return true
 return false

func land_airdrop() -> void:
 drop_state = 2
 drop_count += 1
 crate.global_position = drop_site
 canopy.hide()
 crate.show()
 game.spawn_dynamic_pickup("CASH",250,drop_site+Vector3(-0.65,0,0))
 game.spawn_dynamic_pickup("GRENADE",2,drop_site+Vector3(0.65,0,0))
 game.spawn_dynamic_pickup("WEAPON_HELIOS",1,drop_site+Vector3(0,0,0.8))
 game.message = "AIRDROP DISPONIBLE"

func aim_forward() -> Vector3:
 return -Basis(Vector3.UP,game.player.yaw).z

func melee() -> bool:
 if not available() or melee_left>0.0: return false
 melee_left = 0.65
 var origin: Vector3 = game.player.global_position+Vector3.UP*1.0
 var end := origin+aim_forward()*2.0
 var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,end,3))
 blade.global_position = origin+aim_forward()*0.8
 blade.look_at(end,Vector3.UP)
 blade.show()
 if not hit.is_empty() and hit.collider.has_method("take_hit"):
  hit.collider.take_hit(42)
 game.message = "CUCHILLA DE ENERGIA"
 return true

func throw_grenade() -> bool:
 if not available() or grenades<=0 or orb_clock>0: return false
 grenades -= 1
 orb_clock = 0.75
 orb_start = game.player.global_position+Vector3.UP*1.2
 var end := orb_start+aim_forward()*8.0
 var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(orb_start,end,1))
 if not hit.is_empty(): end = hit.position+hit.normal*0.25
 orb_end = end
 orb.global_position = orb_start
 orb.show()
 return true

func detonate() -> void:
 orb.hide()
 for rival in game.targets:
  if not rival.active or rival.collision_layer==0: continue
  var goal: Vector3 = rival.global_position+Vector3.UP
  if goal.distance_to(orb_end)>3.0: continue
  if get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(orb_end,goal,1)).is_empty():
   rival.take_hit(55)
 if is_instance_valid(game.combat_fx):
  game.combat_fx.emit_shot(orb_end+Vector3.UP*0.15,orb_end,Vector3.UP,"WORLD",game.player.global_position,"PLASMA")

func step(delta: float) -> void:
 if not available(): return
 elapsed += delta
 if drop_state==0 and elapsed>=35.0: spawn_airdrop()
 if drop_state==1:
  drop_clock += delta
  crate.global_position = drop_site+Vector3.UP*maxf(0.0,20.0-drop_clock*5.0)
  if drop_clock>=4.0: land_airdrop()
 if melee_left>0:
  melee_left = maxf(0.0,melee_left-delta)
  if melee_left<0.42: blade.hide()
 if orb_clock>0.0:
  orb_clock = maxf(0.0,orb_clock-delta)
  var p := 1.0-orb_clock/0.75
  orb.global_position = orb_start.lerp(orb_end,p)+Vector3.UP*sin(p*PI)*1.2
  if orb_clock==0.0: detonate()
