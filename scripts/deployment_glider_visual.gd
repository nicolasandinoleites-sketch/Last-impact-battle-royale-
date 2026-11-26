extends Node3D
# Attach to the actual RAZE back socket only after asset and pivot review.
# Input is authoritative deployment phase, not normal player jump/fall.
enum Phase { INTRO, IN_PLANE, FREEFALL, GLIDE, LAND, GROUND }
var wing_left: Node3D
var wing_right: Node3D
var engines: Array[Node3D] = []
var left_open := Basis.IDENTITY
var right_open := Basis.IDENTITY
var left_axis := Vector3.UP
var right_axis := Vector3.UP
var folded_angle := deg_to_rad(75.0)
var deployment := 0.0
var phase := Phase.GROUND
var configured := false

func configure(left_pivot: Node3D, right_pivot: Node3D, left_hinge: Vector3, right_hinge: Vector3, effects: Array[Node3D], fold_degrees: float = 75.0) -> bool:
	if configured or not is_instance_valid(left_pivot) or not is_instance_valid(right_pivot) or left_hinge.length_squared()<0.01 or right_hinge.length_squared()<0.01:
		return false
	wing_left = left_pivot
	wing_right = right_pivot
	left_open = left_pivot.transform.basis
	right_open = right_pivot.transform.basis
	left_axis = left_hinge.normalized()
	right_axis = right_hinge.normalized()
	folded_angle = deg_to_rad(clampf(fold_degrees,0.0,110.0))
	engines = effects
	configured = true
	reset_deployment()
	return true

func set_phase(next_phase: Phase) -> void:
	phase = next_phase
	if phase==Phase.INTRO or phase==Phase.IN_PLANE or phase==Phase.GROUND:
		reset_effects()
		deployment = 0.0
		hide()
	else:
		show()

func update_deployment(delta: float, throttle: float, within_fx_range: bool = true) -> void:
	if not configured:
		return
	var open := phase==Phase.GLIDE
	deployment = move_toward(deployment,1.0 if open else 0.0,maxf(delta,0.0)/(0.48 if open else 0.34))
	var angle := folded_angle*(1.0-smoothstep(0.0,1.0,deployment))
	wing_left.transform.basis = left_open*Basis(left_axis,angle)
	wing_right.transform.basis = right_open*Basis(right_axis,-angle)
	for engine in engines:
		if is_instance_valid(engine) and engine.has_method("set_power"):
			engine.set_power(clampf(throttle,0.0,1.0)*deployment,open)
			engine.update_effect(delta,within_fx_range and visible)
	# LAND remains visible until wings have folded, then hides entirely.
	if phase==Phase.LAND and deployment<=0.0:
		hide()

func reset_effects() -> void:
	for engine in engines:
		if is_instance_valid(engine) and engine.has_method("reset_effect"):
			engine.reset_effect()

func reset_deployment() -> void:
	phase = Phase.GROUND
	deployment = 0.0
	reset_effects()
	hide()
	if configured:
		wing_left.transform.basis = left_open*Basis(left_axis,folded_angle)
		wing_right.transform.basis = right_open*Basis(right_axis,-folded_angle)
