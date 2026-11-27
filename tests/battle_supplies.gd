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
 for target in game.targets:
  target.set_physics_process(false)
  target.collision_layer = 0
 var s = game.supplies
 assert(s.credits==300 and s.grenades==2)
 game.player.global_position = Vector3(0,0,0)
 assert(not s.buy_weapon() and not s.buy_upgrade("MAG"))
 game.player.global_position = s.station.global_position
 assert(s.buy_upgrade("MAG") and game.magazine_capacity()==38 and s.credits==200)
 assert(not s.buy_upgrade("MAG"))
 assert(s.buy_weapon() and game.owned_weapons.size()==2 and s.credits==0)
 assert(is_equal_approx(game.reload_duration(),float(game.Arsenal.spec(game.weapon_id).reload)*0.8))
 assert(not s.buy_weapon())
 assert(game.equip_weapon("ARC",true) and game.owned_weapons.size()==2)
 assert(game.corpse_pickups.size()==1 and game.corpse_pickups[0].kind=="WEAPON_VOLTAR")
 assert(game.corpse_pickups[0].attachments.get("RELOAD",false))
 s.step(34.9)
 assert(s.drop_state==0)
 s.step(0.2)
 assert(s.drop_state==1 and s.crate.visible and s.crate.position.y>0.0)
 s.step(4.0)
 assert(s.drop_state==2 and s.drop_count==1)
 assert(not s.spawn_airdrop() and game.corpse_pickups.size()==4)
 var cash = game.corpse_pickups[1]
 game.player.global_position = cash.global_position
 assert(game.collect_nearby() and s.credits==250)
 var grenade = game.corpse_pickups[2]
 game.player.global_position = grenade.global_position
 assert(game.collect_nearby() and s.grenades==4)
 var rival = game.targets[2]
 rival.reset_target()
 game.player.global_position = Vector3(-20,0.01,-20)
 game.player.yaw = 0.0
 rival.global_position = Vector3(-20,0.01,-21.4)
 await physics_frame
 await physics_frame
 assert(s.melee() and rival.hp==58 and not s.melee())
 rival.global_position = Vector3(-20,0.01,-28)
 await physics_frame
 await physics_frame
 assert(s.throw_grenade() and s.grenades==3 and not s.throw_grenade())
 s.step(0.75)
 assert(rival.hp==3 and not s.orb.visible)
 game.reset_round()
 assert(game.owned_weapons.size()==1 and game.pickups.size()==19)
 assert(s.credits==300 and s.grenades==2 and s.upgrades.is_empty() and s.drop_state==0)
 print("R0790 SUPPLIES PASS | two slots, store, magazine, reload, airdrop, cash, pulse, melee, reset")
 game.queue_free()
 await process_frame
 await process_frame
 OS.delay_msec(180)
 quit()
