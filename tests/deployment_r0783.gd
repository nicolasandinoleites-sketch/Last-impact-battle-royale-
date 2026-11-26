extends SceneTree
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var game = load("res://battle_royale.tscn").instantiate()
 root.add_child(game)
 await physics_frame
 await physics_frame
 assert(game.deployment_active() and game.deployment.assets.available)
 var c = game.deployment
 var a = c.audio
 assert(a.clips.size()==6 and a.get_child_count()==3)
 assert(a.engine.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD)
 assert(a.wind.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD)
 assert(a.wind.stream.loop_end==88200 and a.engine.stream.loop_end==88200)
 assert(absf(a.engine.stream.get_length()-4.0)<0.01)
 assert(c.cinematic.passengers.actors.size()==(2 if game.profile==0 else 4))
 game.request_jump()
 for i in range(10): await physics_frame
 assert(c.cinematic.passengers.visible)
 game.request_jump()
 for i in range(180):
  await physics_frame
  if c.flight.phase==2: break
 assert(c.flight.phase==2 and not c.cinematic.passengers.visible)
 assert(a.event_count==2)
 for i in range(75): await physics_frame
 assert(c.flight.phase==2 and c.speed_effect>0.4 and a.wind_gain>0.3)
 game.request_jump()
 var saw_glide := false
 var saw_land := false
 for i in range(1500):
  await physics_frame
  if not game.deployment_active(): break
  if c.flight.phase==3:
   saw_glide = true
  if c.flight.phase==4:
   saw_land = true
   assert(a.event_count==4)
 assert(saw_glide and saw_land and not game.deployment_active())
 assert(not a.engine.playing and not a.wind.playing and not a.cue.playing)
 assert(c.speed_effect==0.0 and not c.cinematic.passengers.visible)
 assert(game.player.is_physics_processing() and game.player.raze.clip_motion.available)
 game.reset_round()
 assert(game.deployment_active() and a.event_count==0 and not c.cinematic.passengers.visible)
 print("R0783 DEPLOYMENT PASS | real BR entry, six sounds, passengers, velocity effect, reset")
 c.finish()
 for voice in [a.engine,a.wind,a.cue]:
  voice.stop()
  voice.stream = null
 await create_timer(0.25).timeout
 game.queue_free()
 await create_timer(0.25).timeout
 quit()
