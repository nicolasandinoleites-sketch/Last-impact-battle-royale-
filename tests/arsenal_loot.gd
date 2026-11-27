extends SceneTree
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var game = load("res://battle_royale.tscn").instantiate()
 root.add_child(game)
 await physics_frame
 game.deployment.finish()
 game.set_physics_process(false)
 game.player.set_physics_process(false)
 for t in game.targets: t.set_physics_process(false)
 assert(game.pickups.size()==19 and game.magazine_capacity()==30 and game.weapon_id=="IGNIS")
 for seed_value in range(7300,7350):
  var basic: Array[Vector3] = game.frontier.battle_loot_positions(seed_value)
  var extra: Array[Vector3] = game.frontier.arsenal_sites(seed_value,basic)
  assert(extra.size()==6 and extra==game.frontier.arsenal_sites(seed_value,basic))
  var sectors := {}
  for site in extra:
   assert(site.is_finite() and extra.count(site)==1 and not basic.has(site))
   assert(not game.frontier.grid.is_point_solid(game.frontier.cell_at(site)))
   sectors[game.frontier.sector_name(site)] = true
  assert(sectors.size()==3)
  var utility: Array[Vector3] = game.frontier.utility_sites(seed_value,basic+extra)
  assert(utility.size()==4 and utility==game.frontier.utility_sites(seed_value,basic+extra))
  for site in utility:
   assert(not basic.has(site) and not extra.has(site) and not game.frontier.grid.is_point_solid(game.frontier.cell_at(site)))
 game.ammo = 19
 game.reserve = 42
 for i in [9,11,13]:
  var item = game.pickups[i]
  game.player.global_position = item.global_position
  assert(game.collect_nearby() and not item.active)
  assert(game.ammo==game.magazine_capacity() and game.reserve==0)
  var supply = game.pickups[i+1]
  game.player.global_position = supply.global_position
  assert(game.collect_nearby() and game.reserve>0)
  var stored: int = game.reserve
  var capacity: int = game.magazine_capacity()
  game.shoot()
  assert(game.ammo==capacity-1 and is_equal_approx(game.cooldown,float(game.Arsenal.spec(game.weapon_id).delay)))
  game.start_reload()
  assert(is_equal_approx(game.reload_left,game.reload_duration()))
  game.reload_left=0.01
  game._physics_process(0.02)
  assert(game.ammo==capacity and stored-1==game.reserve)
  game.ammo -= 2
 assert(game.owned_weapons.size()==2 and game.owned_weapons.has("IGNIS") and game.owned_weapons.has("HELIOS"))
 assert(game.cycle_weapon() and game.weapon_id=="IGNIS" and game.ammo==19 and game.reserve==42)
 assert(not game.equip_weapon("VOLTAR"))
 assert(game.collect_ammo("AMMO_HEAVY",999)==163)
 assert(game.reserve==42)
 assert(game.equip_weapon("HELIOS") and game.reserve==180 and game.ammo==4)
 assert(game.corpse_pickups.size()==2 and game.corpse_pickups[0].loaded_rounds==34)
 game.reset_round()
 assert(game.weapon_id=="IGNIS" and game.owned_weapons.size()==1 and game.ammo==30 and game.reserve==120)
 assert(game.pickups.size()==19 and game.pickups[9].active)
 print("R0789 ARSENAL PASS | 4 weapon types, 2 carry slots, 3 ammo families plus energy, 50 seeds, pickup, swap, cap, reset")
 game.queue_free()
 await process_frame
 await process_frame
 OS.delay_msec(180)
 quit()
