extends SceneTree
const Adaptive = preload("res://scripts/adaptive_resolution.gd")

func _initialize() -> void:
	var policy := Adaptive.new()
	var slow := {"duration_ms":10000,"frames":180,"mean_fps":18.0,"p95_ms":65.0}
	var fast := {"duration_ms":10000,"frames":300,"mean_fps":30.0,"p95_ms":35.0}
	policy.observe(slow)
	assert(policy.pending==-1)
	policy.observe(slow)
	assert(policy.pending==1 and not policy.commit_if_safe(false) and policy.level==0)
	assert(policy.commit_if_safe(true) and policy.resolution()==Vector2i(720,405))
	for i in range(4):
		policy.observe(slow)
	assert(policy.commit_if_safe(true) and policy.resolution()==Vector2i(640,360))
	for i in range(6):
		policy.observe(slow)
	assert(policy.pending==-1 and policy.level==2)
	for i in range(4):
		policy.observe(fast)
	assert(policy.commit_if_safe(true) and policy.level==1)
	policy.reset()
	assert(policy.resolution()==Vector2i(800,450) and policy.pending==-1)
	policy.observe({"duration_ms":1000,"frames":5,"mean_fps":5,"p95_ms":200})
	assert(policy.slow_windows==0)
	print("ADAPTIVE RESOLUTION POLICY PASS")
	quit(0)
