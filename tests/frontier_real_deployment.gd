extends SceneTree
# Requires both real articulated GLBs. Never report PASS if the assets are missing.
func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 var game = load("res://deployment_preview.tscn").instantiate()
 root.add_child(game)
 await physics_frame
 await physics_frame
 assert(game.deployment.assets.available)
 assert(game.player.model_loaded)
 var controller = game.deployment
 var cinematic = controller.cinematic
 var assets = controller.assets
 assert(is_instance_valid(cinematic))
 assert(cinematic.shot.current)
 assert(not assets.pack.glider.visible)
 game.request_jump()
 for i in range(10):
  await physics_frame
  if cinematic.interior: break
 assert(cinematic.interior and cinematic.cabin.visible and not assets.plane.visible)
 assert(game.player.visual.visible)
 assert(cinematic.timeline.opening==0.0)
 game.request_jump()
 var seen_open := false
 for i in range(240):
  await physics_frame
  if controller.flight.phase==2: break
  seen_open = seen_open or cinematic.cabin.opening>0.99
  assert(not assets.pack.glider.visible)
 assert(controller.flight.phase==2 and seen_open)
 assert(not cinematic.cabin.visible and game.player.camera.current)
 assert(game.player.global_position.distance_to(cinematic.timeline.exit_world(controller.flight.plane_position))<0.25)
 assert(assets.pack.glider.visible and assets.pack.glider.deployment<0.01)
 game.request_jump()
 var seen_wings := false
 var seen_fx := false
 for i in range(1500):
  await physics_frame
  if not game.deployment_active(): break
  if controller.flight.phase==3:
   seen_wings = seen_wings or assets.pack.glider.deployment>0.99
   seen_fx = seen_fx or assets.pack.glider.engines[0].particles.emitting
 assert(seen_wings and seen_fx)
 assert(not game.deployment_active())
 assert(not assets.pack.glider.visible and not assets.plane.visible)
 assert(game.player.is_physics_processing() and game.player.camera.current)
 game.reset_round()
 await physics_frame
 assert(game.deployment_active() and not assets.pack.glider.visible)
 assert(cinematic.timeline.opening==0.0)
 print("REAL CINEMATIC DEPLOYMENT PASS | RAZE, aircraft, cabin, ramp, pack, FX, landing, reset")
 quit()
