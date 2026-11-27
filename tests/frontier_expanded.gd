extends SceneTree
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var game = load("res://battle_royale.tscn").instantiate()
 root.add_child(game)
 await physics_frame
 assert(game.frontier.expanded and game.frontier.half_extent==128.0)
 assert(game.frontier.grid.region.size==Vector2i(128,128))
 assert(game.frontier.buildings.size()==12 and game.pickups.size()==31)
 assert(game.zone.radius==114.0 and game.zone.seconds_remaining()==45)
 assert(game.deployment.flight.edge==122.0 and game.deployment.flight.plane_position.x < -100.0)
 var path: PackedVector3Array = game.frontier.route(Vector3(-110,0,-98),Vector3(110,0,98))
 assert(path.size()>80 and path[path.size()-1].distance_to(Vector3(110,0,98))<3.0)
 for seed in range(7300,7350):
  game.round_seed=seed
  var sites: Array[Vector3] = game.map_pickup_sites()
  assert(sites.size()==31 and sites==game.map_pickup_sites())
  for p in sites:
   assert(p.is_finite() and sites.count(p)==1 and not game.frontier.grid.is_point_solid(game.frontier.cell_at(p)))
   assert(not game.zone.outside(p))
  for i in range(19,31): assert(Vector2(sites[i].x,sites[i].z).length()>64.0)
 game.zone.advance(195.0)
 assert(is_equal_approx(game.zone.radius,60.0))
 game.reset_round()
 assert(game.zone.radius==114.0 and game.pickups.size()==31)
 game.deployment.finish()
 game.queue_free()
 await process_frame
 await process_frame
 OS.delay_msec(180)
 var legacy = load("res://survival.tscn").instantiate()
 root.add_child(legacy)
 await physics_frame
 assert(not legacy.frontier.expanded and legacy.frontier.half_extent==64.0 and legacy.zone.radius==54.0 and legacy.pickups.size()==9)
 print("R0793 EXPANDED PASS | fourfold area, legacy unchanged, outer POIs, navigation, 50 loot seeds, storm, reset")
 legacy.queue_free()
 await process_frame
 await process_frame
 OS.delay_msec(180)
 quit()
