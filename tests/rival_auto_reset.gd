extends SceneTree
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var game = load("res://battle_royale.tscn").instantiate()
 root.add_child(game)
 await physics_frame
 await physics_frame
 var director = game.rival_deployment
 # No manual action: auto exit, auto glide, then reset during actual opponent descent.
 for i in range(1200):
  await physics_frame
  if director.drops[0].launched and director.drops[1].launched: break
 assert(director.drops[0].launched and director.drops[1].launched)
 assert(game.deployment.flight.jumped and game.deployment.cinematic.timeline.ready_to_exit)
 game.reset_round()
 for d in director.drops:
  assert(not d.launched and not d.landed and not d.target.visible)
  assert(d.target.collision_layer==0 and d.target.hp==100)
 # Second round entirely automatic, including rival landing and ground handoff.
 for i in range(2400):
  await physics_frame
  if not director.enabled and not game.deployment_active(): break
 assert(not director.enabled and not game.deployment_active())
 for d in director.drops:
  assert(d.landed and d.released and d.clear)
  assert(d.target.is_physics_processing())
  assert(absf(d.land_at.y)<0.15)
 assert(director.drops[0].land_at.distance_to(director.drops[1].land_at)>15.0)
 print("R0784 AUTO RESET PASS | no input, interrupted descent, clean second deployment")
 game.queue_free()
 await process_frame
 await process_frame
 quit()
