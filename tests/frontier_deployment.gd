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
 var saw_fall := false
 var saw_glide := false
 var saw_compression := false
 var prior_fov: float = game.player.camera.fov
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
  var phase: int = game.deployment.flight.phase
  saw_fall = saw_fall or phase==2
  saw_glide = saw_glide or phase==3
  saw_compression = saw_compression or game.deployment.pose.landing_weight>0.4
  assert(absf(game.player.camera.fov-prior_fov)<3.0)
  prior_fov = game.player.camera.fov
 assert(not game.deployment_active())
 assert(game.deployment.landing_clear)
 assert(saw_fall and saw_glide and saw_compression)
 assert(absf(game.player.visual.rotation.x)<0.01 and absf(game.player.visual.rotation.z)<0.01)
 assert(absf(game.player.camera.fov-60.0)<0.2)
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
