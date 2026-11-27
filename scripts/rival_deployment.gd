extends Node3D
# Only humanoid rivals use the aircraft. Drones retain their ground behavior.
# The original operator bodies, skeletons and health are reused, not replaced.
const Flight = preload("res://scripts/deployment_flight.gd")
const Surface = preload("res://scripts/deployment_surface.gd")
const Pose = preload("res://scripts/deployment_pose.gd")
const Rig = preload("res://scripts/deployment_asset_rig.gd")
const Socket = preload("res://scripts/deployment_back_socket.gd")
const Operator = preload("res://scripts/survival_operator.gd")
const PACK = "res://assets/deployment/jetpack_rig.glb"
const PALETTES := [Color(0.60,0.88,1.0),Color(1.0,0.78,0.42)]
const ZONES := [Vector3(-22,0,-24),Vector3(22,0,24)]
var drops: Array[Dictionary] = []
var elapsed_since_exit := 0.0
var enabled := false
var game

func configure(owner_game) -> void:
 game = owner_game
 for target in game.targets:
  if target.get_script()!=Operator:
   continue
  var index := drops.size()
  var pose := Pose.new()
  var rig: Node3D = null
  if target.model_loaded:
   pose.setup(target.actor.skeleton)
   if ResourceLoader.exists(PACK):
    var scene := load(PACK) as PackedScene
    if scene!=null:
     var instance := scene.instantiate() as Node3D
     rig = Rig.new()
     if not rig.attach_model(instance,false,0) or Socket.attach(target.actor.skeleton,rig)==null:
      if instance.get_parent()==null: instance.free()
      rig.free()
      rig = null
   # Distinct team armor tint; original mesh and textures remain shared.
   for child in target.actor.model.find_children("*","MeshInstance3D",true,false):
    var mesh_node := child as MeshInstance3D
    if mesh_node.mesh==null: continue
    for j in range(mesh_node.mesh.get_surface_count()):
     var mat := mesh_node.get_active_material(j) as StandardMaterial3D
     if mat!=null:
      var tint := mat.duplicate() as StandardMaterial3D
      tint.albedo_color = PALETTES[index%PALETTES.size()]
      mesh_node.set_surface_override_material(j,tint)
  drops.append({"target":target,"flight":Flight.new(),"surface":Surface.new(),"pose":pose,"rig":rig,"delay":0.25+0.65*index,"goal":ZONES[index%ZONES.size()],"launched":false,"landed":false,"released":false,"clear":false,"last_phase":-1,"anim_elapsed":0.0,"land_at":Vector3.ZERO})

func begin() -> void:
 elapsed_since_exit = 0.0
 enabled = true
 for d in drops:
  var t: CharacterBody3D = d.target
  if game.frontier.expanded: d.flight.configure_expanded()
  d.flight.reset()
  d.launched = false
  d.landed = false
  d.released = false
  d.clear = false
  d.last_phase = -1
  d.anim_elapsed = 0.0
  d.land_at = Vector3.ZERO
  t.set_physics_process(false)
  t.hide()
  t.collision_layer = 0
  t.velocity = Vector3.ZERO
  t.visual.rotation = Vector3.ZERO
  if t.model_loaded: d.pose.setup(t.actor.skeleton)
  if is_instance_valid(d.rig): d.rig.reset_rig()

func airborne(target) -> bool:
 if not enabled: return false
 for d in drops:
  if d.target==target: return not d.landed
 return false

func launch(d: Dictionary, plane_position: Vector3) -> void:
 var f = d.flight
 var t: CharacterBody3D = d.target
 var offset := -1.1 if d.delay<0.5 else 1.1
 f.position = plane_position+Vector3(-6,-2.58,offset)
 f.position.x = clampf(f.position.x,-f.edge,f.edge)
 if game.frontier.expanded:
  var goal := Vector3(clampf(f.position.x+24.0,-100.0,100.0),0,offset*24.0)
  var cell: Vector2i = game.frontier.nearest_open(game.frontier.cell_at(goal))
  d.goal = game.frontier.cell_center(cell)
 f.velocity = Vector3(9,-4,offset*2.0)
 f.jumped = true
 f.transition(Flight.Phase.FREEFALL)
 t.global_position = f.position
 t.reset_physics_interpolation()
 t.show()
 t.visual.show()
 d.launched = true
 print("RIVAL DROP LAUNCH | ",t.name," | ",f.position)

func step(delta: float, player_flight, player_active: bool) -> void:
 if not enabled: return
 if player_flight.phase>=Flight.Phase.FREEFALL:
  elapsed_since_exit += delta
 for d in drops:
  var t: CharacterBody3D = d.target
  if d.released: continue
  if not d.launched:
   if player_flight.phase>=Flight.Phase.FREEFALL and elapsed_since_exit>=d.delay:
    launch(d,player_flight.plane_position)
   else: continue
  if not d.landed:
   step_drop(d,delta)
  if d.landed and not player_active:
   t.set_physics_process(true)
   d.released = true
 if drops.all(func(d): return d.released): enabled = false

func step_drop(d: Dictionary, delta: float) -> void:
 var f = d.flight
 var t: CharacterBody3D = d.target
 var surface = d.surface
 var exclusions: Array[RID] = [t.get_rid()]
 surface.configure(t.get_world_3d().direct_space_state,exclusions)
 var goal: Vector3 = d.goal
 var old: Vector3 = t.global_position
 var steering := Vector2(goal.x-old.x,goal.z-old.z)
 # Proportional steering brakes near target instead of circling it.
 steering = (steering/5.0).limit_length(1.0)
 var open_early := old.y<49.0 and Vector2(goal.x-old.x,goal.z-old.z).length()>18.0
 var previous: int = f.phase
 f.step(delta,steering,false,open_early,0.0,Callable(surface,"height_below"))
 if previous in [Flight.Phase.FREEFALL,Flight.Phase.GLIDE]:
  var planned: Vector3 = f.position
  var hit := t.move_and_collide(planned-old)
  f.position = t.global_position
  if hit!=null:
   if hit.get_normal().y>=0.7 and surface.standing_clear(t.global_position):
    f.velocity = Vector3.ZERO
    f.transition(Flight.Phase.LAND)
   else:
    f.velocity.x = 0.0
    f.velocity.z = 0.0
    if f.phase==Flight.Phase.LAND: f.transition(Flight.Phase.GLIDE)
  if f.phase==Flight.Phase.LAND:
   d.clear = surface.standing_clear(t.global_position)
   if not d.clear: f.transition(Flight.Phase.GLIDE)
 if f.phase==Flight.Phase.GROUND:
  if d.clear and surface.standing_clear(t.global_position):
   land(d)
   return
  f.transition(Flight.Phase.GLIDE)
 var yaw: float = atan2(-steering.x,-steering.y) if steering.length()>0.05 else t.visual.rotation.y
 var tilt := -0.50 if f.phase==Flight.Phase.FREEFALL else (-0.20 if f.phase==Flight.Phase.GLIDE else 0.0)
 t.visual.rotation.x = lerpf(t.visual.rotation.x,tilt,1.0-exp(-delta*8.0))
 t.visual.rotation.y = lerp_angle(t.visual.rotation.y,yaw,1.0-exp(-delta*8.0))
 d.anim_elapsed += delta
 if t.model_loaded and d.anim_elapsed>=0.05:
  var landing_progress := clampf(f.time_in_phase/Flight.LAND_DURATION,0.0,1.0) if f.phase==Flight.Phase.LAND else 0.0
  d.pose.update(t.actor.skeleton,d.anim_elapsed,f.phase,steering,f.elapsed,landing_progress)
  d.anim_elapsed = 0.0
 if is_instance_valid(d.rig):
  if d.last_phase!=f.phase: d.rig.glider.set_phase(f.phase)
  var near: bool = t.global_position.distance_to(game.player.global_position)<18.0
  d.rig.glider.update_deployment(delta,0.65,near)
 d.last_phase = f.phase

func land(d: Dictionary) -> void:
 var t: CharacterBody3D = d.target
 d.landed = true
 d.land_at = t.global_position
 t.velocity = Vector3.ZERO
 t.collision_layer = 2
 t.visual.rotation.x = 0.0
 t.visual.rotation.z = 0.0
 if t.model_loaded:
  d.pose.restore(t.actor.skeleton)
  t.actor.reset_locomotion()
 if is_instance_valid(d.rig): d.rig.reset_rig()
 print("RIVAL DROP LAND | ",t.name," | ",d.land_at)
