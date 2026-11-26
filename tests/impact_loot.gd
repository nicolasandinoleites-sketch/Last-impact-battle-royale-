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
 for target in game.targets: target.set_physics_process(false)
 var op = game.targets[2]
 op.reset_target()
 op.global_position = Vector3(-20,0.02,-20)
 game.player.global_position = Vector3(-19,0,-20)
 var fx = game.combat_fx
 assert(fx.slots.size()<=16)
 fx.emit_shot(Vector3(-19,1,-20),Vector3(-20,1,-20),Vector3.RIGHT,"BODY",game.player.global_position)
 assert(fx.shot_count==1 and fx.impact_count==1 and fx.last_impact=="BODY")
 assert(fx.slots[0].holder.visible)
 fx._process(0.3)
 assert(not fx.slots[0].holder.visible)
 op.armor = 25
 assert(game.impact_kind(op)=="SHIELD")
 op.armor = 0
 assert(game.impact_kind(op)=="BODY")
 var original_count: int = game.pickups.size()
 op.take_hit(100)
 assert(not op.active and op.collision_layer==0 and op.death_left>0)
 assert(game.corpse_pickups.size()==2 and game.pickups.size()==original_count+2)
 op.take_hit(100)
 assert(game.corpse_pickups.size()==2)
 op.step_death(0.31)
 assert(op.visual.rotation.x < -0.1 and op.visible)
 op.step_death(0.4)
 assert(not op.visible)
 var drop = game.corpse_pickups[0]
 game.player.global_position = drop.global_position
 game.reserve = 0
 assert(game.collect_nearby())
 assert(game.reserve>0 and not drop.active)
 game.reset_round()
 assert(game.corpse_pickups.is_empty() and game.pickups.size()==original_count)
 assert(op.active and op.death_left==0 and fx.shot_count==0)
 print("R0788 IMPACT LOOT PASS | pooled effects, shield/body, death, one-time drops, collect, reset")
 game.queue_free()
 await process_frame
 await process_frame
 quit()
