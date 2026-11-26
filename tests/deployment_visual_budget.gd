extends SceneTree
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var game = load("res://deployment_preview.tscn").instantiate()
 root.add_child(game)
 await physics_frame
 var assets = game.deployment.assets
 assert(assets.available and game.player.raze.clip_motion.available)
 var glider = assets.pack.glider
 glider.set_phase(3)
 for i in range(40): glider.update_deployment(1.0/60.0,0.85)
 assert(glider.deployment==1.0)
 assert(is_equal_approx(glider.wing_left.transform.basis.x.length()/glider.left_open.x.length(),1.30))
 assert(is_equal_approx(glider.wing_right.transform.basis.x.length()/glider.right_open.x.length(),1.30))
 var images: Array[String] = []
 for file in DirAccess.get_files_at("res://assets/deployment"):
  if file.ends_with(".jpg"):
   var tex := load("res://assets/deployment/"+file) as Texture2D
   assert(tex!=null and maxi(tex.get_width(),tex.get_height())==2048)
   images.append(str(tex.get_width())+"x"+str(tex.get_height()))
 assert(images.size()==2)
 var particle_count := 0
 for engine in assets.plane.aircraft_engines: particle_count += engine.particles.amount
 for engine in glider.engines: particle_count += engine.particles.amount
 assert(particle_count==[56,100,144][game.profile])
 glider.reset_deployment()
 assert(not glider.visible and is_equal_approx(glider.wing_left.transform.basis.x.length(),glider.left_open.x.length()))
 print("DEPLOYMENT VISUAL BUDGET PASS | wing x1.30, textures=",images,", profile particles=",particle_count,", locomotion=",game.player.raze.clip_motion.available)
 quit()
