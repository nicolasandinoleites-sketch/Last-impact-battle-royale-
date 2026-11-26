extends SceneTree
const Glider = preload("res://scripts/deployment_glider_visual.gd")
const FX = preload("res://scripts/deployment_engine_fx.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var glider := Glider.new()
	root.add_child(glider)
	var left := Node3D.new()
	var right := Node3D.new()
	glider.add_child(left)
	glider.add_child(right)
	var fx := FX.new()
	glider.add_child(fx)
	fx.configure(null,0.1,false,0)
	var effects: Array[Node3D] = [fx]
	assert(glider.configure(left,right,Vector3.UP,Vector3.UP,effects))
	assert(not glider.visible and glider.deployment==0.0)
	glider.set_phase(Glider.Phase.IN_PLANE)
	assert(not glider.visible)
	glider.set_phase(Glider.Phase.FREEFALL)
	glider.update_deployment(1.0/60.0,1.0)
	assert(glider.visible and glider.deployment==0.0 and not fx.particles.emitting)
	glider.set_phase(Glider.Phase.GLIDE)
	for i in range(60):
		glider.update_deployment(1.0/60.0,0.8)
	assert(glider.deployment==1.0 and left.transform.basis.is_equal_approx(Basis.IDENTITY))
	assert(fx.particles.emitting)
	glider.set_phase(Glider.Phase.LAND)
	for i in range(30):
		glider.update_deployment(1.0/60.0,0.8)
	assert(not glider.visible and not fx.particles.emitting and glider.deployment==0.0)
	glider.reset_deployment()
	assert(glider.phase==Glider.Phase.GROUND and fx.intensity==0.0)
	print("DEPLOYMENT GLIDER FIXTURE PASS")
	quit(0)
