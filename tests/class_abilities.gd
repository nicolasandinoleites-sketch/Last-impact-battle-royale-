extends SceneTree
const Classes = preload("res://scripts/operator_classes.gd")
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 OS.set_environment("LASTIMPACT_CLASS_PATH","user://qa_operator_class.cfg")
 var preset := Classes.new()
 preset.selected = "TITAN"
 assert(preset.save_selection()==OK)
 var saved := Classes.new()
 saved.load_selection()
 assert(saved.selected=="TITAN")
 var game = load("res://battle_royale.tscn").instantiate()
 root.add_child(game)
 await physics_frame
 var a = game.ability
 assert(a.class_id=="TITAN" and not a.activate())
 game.deployment.finish()
 game.set_physics_process(false)
 game.player.set_physics_process(false)
 for target in game.targets: target.set_physics_process(false)
 assert(a.activate() and not a.activate())
 game.health=100
 game.armor=0
 game.damage_player(20)
 assert(game.health==90)
 game.damage_player(10,false)
 assert(game.health==80)
 a.step(5.1)
 assert(not a.active("TITAN") and a.cooldown_left>0.0)
 game.damage_player(20)
 assert(game.health==60)
 a.step(35.0)
 assert(a.activate())
 a.reset()
 a.class_id="SERAPH"
 game.health=65
 game.armor=90
 assert(a.activate() and game.health==95 and game.armor==100)
 a.reset()
 game.health=100
 assert(not a.activate())
 a.class_id="RAZE"
 assert(a.activate())
 game.cooldown=0
 game.shoot()
 assert(is_equal_approx(game.cooldown,float(game.Arsenal.spec(game.weapon_id).delay)*0.75))
 a.reset()
 a.class_id="PHANTOM"
 assert(a.activate() and a.detection_range()==5.0 and is_equal_approx(a.movement_factor(),1.2))
 a.step(5.1)
 assert(a.detection_range()==18.0 and a.movement_factor()==1.0)
 a.reset()
 a.class_id="SPECTRE"
 assert(not a.reveals(20.0) and a.reveals(5.0))
 assert(a.activate() and a.reveals(44.0) and not a.reveals(46.0))
 game.reset_round()
 assert(a.active_left==0.0 and a.cooldown_left==0.0 and game.deployment_active())
 assert(not a.activate())
 DirAccess.remove_absolute("user://qa_operator_class.cfg")
 print("R0792 CLASSES PASS | persistence, deployment guard, five abilities, cooldown, reset")
 game.queue_free()
 await process_frame
 await process_frame
 OS.delay_msec(180)
 quit()
