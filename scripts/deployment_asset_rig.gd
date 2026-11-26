extends Node3D
# Bind the exact articulated GLB node contract. No flight physics or placeholder geometry.
const FX = preload("res://scripts/deployment_engine_fx.gd")
const Glider = preload("res://scripts/deployment_glider_visual.gd")
const AIRCRAFT_SUFFIXES := ["L_outer","L_inner","R_inner","R_outer"]
var aircraft_engines: Array[Node3D] = []
var glider: Node3D
var model: Node3D
var bound := false

func attach_model(instance: Node3D, is_aircraft: bool, profile: int = 0) -> bool:
	if bound or not is_instance_valid(instance):
		return false
	# Manual controllers own transforms: never run imported clips concurrently.
	for animation in instance.find_children("*","AnimationPlayer",true,false):
		animation.stop()
	if is_aircraft:
		for suffix in AIRCRAFT_SUFFIXES:
			if not instance.find_child("Rotor_"+suffix,true,false) is Node3D or not instance.find_child("Exhaust_"+suffix,true,false) is Node3D:
				return false
	else:
		for marker in ["Wing_L","Wing_R","Exhaust_L","Exhaust_R"]:
			if not instance.find_child(marker,true,false) is Node3D:
				return false
	model = instance
	if is_aircraft:
		add_child(model)
		for suffix in AIRCRAFT_SUFFIXES:
			var marker := model.find_child("Exhaust_"+suffix,true,false) as Node3D
			var rotor := model.find_child("Rotor_"+suffix,true,false) as Node3D
			var effect := FX.new()
			marker.add_child(effect)
			effect.configure(rotor,0.038,true,profile)
			aircraft_engines.append(effect)
	else:
		glider = Glider.new()
		add_child(glider)
		glider.add_child(model)
		var engines: Array[Node3D] = []
		for suffix in ["L","R"]:
			var marker := model.find_child("Exhaust_"+suffix,true,false) as Node3D
			var effect := FX.new()
			marker.add_child(effect)
			effect.configure(null,0.058,false,profile)
			engines.append(effect)
		var left := model.find_child("Wing_L",true,false) as Node3D
		var right := model.find_child("Wing_R",true,false) as Node3D
		# Source Deploy/Retract GLB tracks use opposite local Z rotation, 65 degrees.
		if not glider.configure(left,right,Vector3(0,0,1),Vector3(0,0,1),engines,65.0):
			return false
		glider.deployed_span_scale = 1.30
	bound = true
	return true

func set_aircraft_power(throttle: float, active: bool) -> void:
	for engine in aircraft_engines:
		engine.set_power(throttle,active)

func step_aircraft(delta: float, in_range: bool = true) -> void:
	for engine in aircraft_engines:
		engine.update_effect(delta,in_range)

func reset_rig() -> void:
	for engine in aircraft_engines:
		engine.reset_effect()
	if is_instance_valid(glider):
		glider.reset_deployment()
