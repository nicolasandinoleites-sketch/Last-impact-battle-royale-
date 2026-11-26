extends SceneTree
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var game = load("res://battle_royale.tscn").instantiate()
 root.add_child(game)
 await physics_frame
 await physics_frame
 var a = game.targets[2]
 var b = game.targets[4]
 # Freeze the round, isolate actual operators and supplies for deterministic checks.
 game.set_physics_process(false)
 game.deployment.finish()
 game.player.set_physics_process(false)
 for t in game.targets: t.set_physics_process(false)
 for p in game.pickups: p.collect(p.quantity)
 a.reset_target()
 b.reset_target()
 a.global_position = Vector3(-20,0,-20)
 b.global_position = Vector3(20,0,20)
 game.player.global_position = Vector3(40,0,40)
 await physics_frame
 a.decide_tactical(0.4)
 assert(a.ai_state=="PATROL")
 var med = game.pickups[0]
 med.reset_pickup()
 med.global_position = Vector3(-19,0,-20)
 a.hp = 40
 a.decision_left = 0
 a.decide_tactical(0.4)
 assert(a.ai_state=="LOOT" and a.tactical_pickup==med)
 assert(a.collect_supply() and a.hp==75 and not med.active and a.loot_count==1)
 assert(not a.collect_supply())
 var shield = game.pickups[1]
 shield.reset_pickup()
 shield.global_position = Vector3(-19,0,-20)
 a.decision_left = 0
 a.decide_tactical(0.4)
 assert(a.ai_state=="LOOT" and a.tactical_pickup==shield)
 assert(a.collect_supply() and a.armor==25 and not shield.active)
 a.take_hit(30)
 assert(a.hp==70 and a.armor==0)
 game.player.global_position = Vector3(-18,0,-20)
 await physics_frame
 a.decision_left = 0
 a.decide_tactical(0.4)
 assert(a.ai_state=="ENGAGE")
 a.hp=20
 a.decision_left=0
 a.decide_tactical(0.4)
 assert(a.ai_state=="RETREAT")
 a.global_position=Vector3(-59,0,-20)
 a.decision_left=0
 a.decide_tactical(0.4)
 assert(a.ai_state=="ZONE")
 for seed_value in range(7300,7350):
  var sites: Array[Vector3] = game.frontier.battle_loot_positions(seed_value)
  assert(sites.size()==9 and sites==game.frontier.battle_loot_positions(seed_value))
  var sectors := {}
  for site in sites:
   assert(sites.count(site)==1 and not game.frontier.grid.is_point_solid(game.frontier.cell_at(site)))
   sectors[game.frontier.sector_name(site)]=true
  assert(sectors.size()==4)
 a.reset_target()
 assert(a.armor==0 and a.hp==100 and a.loot_count==0 and a.tactical_pickup==null and not a.tactical_ready)
 # Verify autonomous path-following and actual pickup in the physics loop.
 a.global_position=Vector3(-20,0,-20)
 a.hp=40
 med.reset_pickup()
 med.global_position=Vector3(-16,0,-20)
 game.player.global_position=Vector3(40,0,40)
 a.set_physics_process(true)
 for i in range(360):
  await physics_frame
  if a.loot_count>0: break
 assert(a.loot_count==1 and a.hp==75 and not med.active)
 a.set_physics_process(false)
 print("R0785 TACTICS PASS | patrol, med, shield, damage, engagement, retreat, zone, reset, 50 seeds")
 game.queue_free()
 await process_frame
 await process_frame
 quit()
