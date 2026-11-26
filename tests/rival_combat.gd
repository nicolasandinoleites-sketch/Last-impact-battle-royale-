extends SceneTree
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var game = load("res://battle_royale.tscn").instantiate()
 root.add_child(game)
 await physics_frame
 await physics_frame
 game.set_physics_process(false)
 game.deployment.finish()
 game.rival_deployment.enabled = false
 game.player.set_physics_process(false)
 for t in game.targets: t.set_physics_process(false)
 for p in game.pickups: p.collect(p.quantity)
 var a = game.targets[2]
 var b = game.targets[4]
 a.reset_target()
 b.reset_target()
 assert(a.weapon_loaded and b.weapon_loaded)
 a.global_position = Vector3(-20,0,-20)
 b.global_position = Vector3(-15,0,-20)
 game.player.global_position = Vector3(40,0,40)
 await physics_frame
 a.set_physics_process(true)
 for i in range(720):
  await physics_frame
  if a.reloads>0: break
 assert(a.opponent==b and a.shots>=6 and a.reloads==1 and b.hp<100)
 assert(a.rival_weapon.pulse_count>=6 and a.rounds==6)
 a.set_physics_process(false)
 # Real scene obstacle blocks the fictional projectile.
 a.global_position = Vector3(-6,0,-2)
 b.global_position = Vector3(-6,0,4)
 await physics_frame
 assert(not a.clear_path(b.global_position))
 a.opponent=b
 a.shot_left=0.0
 var shots: int = a.shots
 var hp: int = b.hp
 a.step_rival_combat(0.1,true)
 assert(a.shots==shots and b.hp==hp)
 # A navigation-grid cover choice must actually occlude the opponent in the game world.
 a.global_position = Vector3(-10,0,1)
 b.global_position = Vector3(-2,0,1)
 await physics_frame
 a.opponent=b
 var cover: Vector3 = a.select_reload_cover()
 assert(cover.distance_to(a.global_position)<10.0)
 var ray := PhysicsRayQueryParameters3D.create(cover+Vector3.UP*0.9,b.global_position+Vector3.UP*0.9,1)
 assert(not a.get_world_3d().direct_space_state.intersect_ray(ray).is_empty())
 a.reset_target()
 assert(a.shots==0 and a.rounds==6 and a.reloads==0 and not a.tracer.visible)
 print("R0786 COMBAT PASS | real Ignis, autonomous rival duel, reload, obstacle, cover, reset")
 game.queue_free()
 await process_frame
 await process_frame
 quit()
