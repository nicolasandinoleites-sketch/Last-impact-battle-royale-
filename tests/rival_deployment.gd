extends SceneTree
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var game = load("res://battle_royale.tscn").instantiate()
 root.add_child(game)
 await physics_frame
 await physics_frame
 var director = game.rival_deployment
 assert(director.drops.size()==2)
 assert(game.targets.size()==6)
 for d in director.drops:
  assert(d.target.model_loaded and d.rig!=null)
  assert(not d.target.visible and d.target.collision_layer==0 and not d.target.is_physics_processing())
 game.request_jump()
 for i in range(10): await physics_frame
 game.request_jump()
 var saw_split := false
 var saw_glide := [false,false]
 var saw_air := [false,false]
 for i in range(1800):
  await physics_frame
  var drops = director.drops
  if drops[0].launched and not drops[1].launched: saw_split = true
  for j in range(2):
   var d = drops[j]
   if d.launched and not d.landed:
    assert(d.target.collision_layer==0 and not d.target.is_physics_processing())
    assert(d.target.hp==100)
    saw_air[j] = true
    if d.flight.phase==3:
     saw_glide[j] = saw_glide[j] or d.rig.glider.deployment>0.95
  if not director.enabled and not game.deployment_active(): break
 assert(saw_split and saw_air[0] and saw_air[1] and saw_glide[0] and saw_glide[1])
 for d in director.drops:
  assert(d.landed and d.released and d.clear and d.target.collision_layer==2)
  assert(d.target.is_physics_processing() and not d.rig.glider.visible)
  assert(absf(d.land_at.y)<0.15)
  assert(d.land_at.distance_to(d.goal)<9.0)
 assert(director.drops[0].land_at.distance_to(director.drops[1].land_at)>15.0)
 game.reset_round()
 assert(game.deployment_active() and director.enabled)
 for d in director.drops:
  assert(not d.launched and not d.landed and not d.released and not d.target.visible)
 print("R0784 RIVAL DEPLOYMENT PASS | stagger, two real operators, wings, separate safe landing, ground AI, reset")
 game.deployment.finish()
 for voice in [game.deployment.audio.engine,game.deployment.audio.wind,game.deployment.audio.cue]:
  voice.stop()
  voice.stream=null
 game.queue_free()
 await process_frame
 await process_frame
 OS.delay_msec(200)
 quit()
