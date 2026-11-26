extends Node3D
# Optional actual articulated assets; no placeholder meshes.
const Rig = preload("res://scripts/deployment_asset_rig.gd")
const BackSocket = preload("res://scripts/deployment_back_socket.gd")
const Flight = preload("res://scripts/deployment_flight.gd")
const AIRCRAFT := "res://assets/deployment/aircraft_rig.glb"
const JETPACK := "res://assets/deployment/jetpack_rig.glb"
var plane: Node3D
var pack: Node3D
var available := false
var phase := -1

func load_model(path: String) -> Node3D:
 if not ResourceLoader.exists(path):
  return null
 var scene := load(path) as PackedScene
 if scene==null:
  return null
 return scene.instantiate() as Node3D

func configure(actor, profile: int) -> bool:
 var plane_model := load_model(AIRCRAFT)
 var pack_model := load_model(JETPACK)
 if plane_model==null or pack_model==null or not actor.model_loaded:
  if plane_model!=null: plane_model.free()
  if pack_model!=null: pack_model.free()
  print("LAST IMPACT DEPLOYMENT ASSETS NOT INSTALLED")
  return false
 plane = Rig.new()
 add_child(plane)
 if not plane.attach_model(plane_model,true,profile):
  if plane_model.get_parent()==null: plane_model.free()
  pack_model.free()
  plane.queue_free()
  return false
 plane.scale = Vector3.ONE*10.0
 plane.rotation.y = -PI*0.5
 plane.hide()
 pack = Rig.new()
 if not pack.attach_model(pack_model,false,profile):
  if pack_model.get_parent()==null: pack_model.free()
  pack.free()
  plane.queue_free()
  return false
 var socket := BackSocket.attach(actor.raze.skeleton,pack)
 if socket==null:
  pack.free()
  plane.queue_free()
  return false
 available = true
 reset()
 print("LAST IMPACT DEPLOYMENT ASSETS BOUND")
 return true

func reset() -> void:
 if not available: return
 phase = -1
 plane.reset_rig()
 pack.reset_rig()
 plane.hide()

func step(delta: float, state: int, plane_position: Vector3, steering: Vector2) -> void:
 if not available: return
 plane.global_position = plane_position
 plane.visible = state!=Flight.Phase.GROUND
 plane.set_aircraft_power(0.82,plane.visible)
 plane.step_aircraft(delta,plane.visible)
 if phase!=state:
  pack.glider.set_phase(state)
  phase = state
 pack.glider.update_deployment(delta,clampf(0.64-steering.y*0.25,0.0,1.0))

func finish() -> void:
 if not available: return
 reset()
