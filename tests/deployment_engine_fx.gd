extends SceneTree
const FX = preload("res://scripts/deployment_engine_fx.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var rig := Node3D.new()
	root.add_child(rig)
	var rotor := Node3D.new()
	rig.add_child(rotor)
	var fx := FX.new()
	rig.add_child(fx)
	fx.configure(rotor,0.1,false,0)
	assert(not fx.particles.emitting and not fx.glow.visible)
	assert(fx.particles.amount==8 and not fx.particles.local_coords)
	fx.set_power(0.8,true)
	for tick in range(30):
		fx.update_effect(1.0/60.0)
	assert(fx.intensity>0.7 and fx.particles.emitting and fx.glow.visible)
	assert(not rotor.transform.basis.is_equal_approx(Basis.IDENTITY))
	fx.update_effect(1.0/60.0,false)
	assert(not fx.particles.emitting and not fx.glow.visible)
	fx.reset_effect()
	assert(fx.intensity==0.0 and rotor.transform.basis.is_equal_approx(Basis.IDENTITY))
	assert(not fx.particles.emitting and not fx.particles.visible)
	rig.queue_free()
	print("DEPLOYMENT ENGINE FX FIXTURE PASS")
	quit(0)
