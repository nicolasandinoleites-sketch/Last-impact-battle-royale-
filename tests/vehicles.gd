extends SceneTree
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var game=load("res://battle_royale.tscn").instantiate()
 root.add_child(game)
 await physics_frame
 var fleet=game.vehicles
 assert(fleet.vehicles.size()==2 and not fleet.toggle())
 game.deployment.finish()
 game.set_physics_process(false)
 game.player.set_physics_process(false)
 for t in game.targets: t.set_physics_process(false)
 var bike=fleet.vehicles[0]
 var rover=fleet.vehicles[1]
 assert(bike.max_speed>rover.max_speed and rover.hp>bike.hp)
 game.player.global_position=bike.global_position+Vector3(2,0,0)
 assert(fleet.toggle() and fleet.mounted==bike)
 assert(not game.player.is_physics_processing() and game.player.collision_mask==0)
 var start: Vector3=bike.global_position
 for i in range(90):
  fleet.step(1.0/60.0,Vector2(0,-1))
  await physics_frame
 assert(bike.global_position.distance_to(start)>5.0 and bike.speed>3.0)
 assert(not fleet.toggle())
 var rounds: int=game.ammo
 game.shoot()
 assert(game.ammo==rounds)
 assert(not game.ability.activate())
 # Place a real obstacle across the open road and verify collision.
 var barrier:=StaticBody3D.new()
 game.add_child(barrier)
 barrier.position=bike.global_position-Vector3(0,-1,4)
 var col:=CollisionShape3D.new()
 var shape:=BoxShape3D.new()
 shape.size=Vector3(5,3,0.5)
 col.shape=shape
 barrier.add_child(col)
 await physics_frame
 await physics_frame
 for i in range(120):
  fleet.step(1.0/60.0,Vector2(0,-1))
  await physics_frame
 assert(bike.global_position.z>barrier.position.z)
 for i in range(120):
  fleet.step(1.0/60.0,Vector2.ZERO)
  await physics_frame
 assert(absf(bike.speed)<0.1 and fleet.toggle())
 assert(fleet.mounted==null and game.player.is_physics_processing() and game.player.collision_mask==1)
 game.player.global_position=rover.global_position+Vector3(2,0,0)
 assert(fleet.toggle())
 rover.take_hit(999)
 fleet.step(0.016,Vector2.ZERO)
 assert(fleet.mounted==null and rover.hp==0)
 game.reset_round()
 assert(fleet.mounted==null and bike.hp==100 and rover.hp==180 and bike.global_position.distance_to(bike.spawn_point)<0.01)
 assert(game.deployment_active())
 print("R0794 VEHICLES PASS | mounts, acceleration, wall collision, brake, exit, destruction, reset")
 game.deployment.finish()
 game.queue_free()
 await process_frame
 await process_frame
 OS.delay_msec(180)
 quit()
