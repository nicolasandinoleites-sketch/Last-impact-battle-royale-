extends SceneTree
func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var game = load("res://deployment_preview.tscn").instantiate()
 root.add_child(game)
 await physics_frame
 await physics_frame
 assert(game.deployment_active())
 assert(game.player.model_loaded)
 assert(not game.player.is_physics_processing())
 assert(not game.targets[0].is_physics_processing())
 var zone_before: float = game.zone.radius
 var ammo_before: int = game.ammo
 game.shoot()
 game.damage_player(50)
 assert(game.ammo==ammo_before and game.health==100)
 game.request_jump()
 await physics_frame
 await physics_frame
 game.request_jump()
 for i in range(1500):
  await physics_frame
  if not game.deployment_active():
   break
  assert(game.zone.radius==zone_before)
 assert(not game.deployment_active())
 assert(game.deployment.landing_clear)
 assert(game.player.is_physics_processing() and game.targets[0].is_physics_processing())
 assert(game.player.weapon.visible)
 for i in range(5):
  await physics_frame
 assert(game.player.is_on_floor())
 game.reset_round()
 assert(game.deployment_active() and not game.player.is_physics_processing())
 assert(not game.targets[0].is_physics_processing())
 print("FRONTIER DEPLOYMENT PASS | real RAZE, real map, pause, landing, handoff, reset")
 quit()
