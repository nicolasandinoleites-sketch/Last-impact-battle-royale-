extends RefCounted
# Cosmetic support lock; does not move the CharacterBody or modify collision.
# Only active for calibrated, forward, grounded imported clips.
const ENTER := 0.72
const EXIT := 0.35
const MAX_DRIFT := 0.28
const MAX_CORRECTION := 0.10
var anchors: Dictionary = {}
var weights: Dictionary = {}
var contact_count := 0
var max_error := 0.0

func reset() -> void:
	anchors.clear()
	weights.clear()
	contact_count = 0
	max_error = 0.0

func release() -> void:
	anchors.clear()
	weights.clear()

func update(actor: Node3D, mixer, delta: float, eligible: bool) -> void:
	if not eligible or not mixer.calibrated or mixer.weight<0.85:
		release()
		return
	var rig: Skeleton3D = actor.skeleton
	for side in ["L","R"]:
		var confidence: float = mixer.support_confidence(side)
		var id := rig.find_bone(side+"_Foot")
		if id<0:
			continue
		var current := rig.to_global(rig.get_bone_global_pose(id).origin)
		if anchors.has(side):
			var anchor: Vector3 = anchors[side]
			var drift := current.distance_to(anchor)
			if confidence<EXIT or drift>MAX_DRIFT:
				anchors.erase(side)
				weights.erase(side)
				continue
		elif confidence>=ENTER:
			anchors[side] = current
			weights[side] = 0.0
			contact_count += 1
		if not anchors.has(side):
			continue
		var amount := minf(1.0,float(weights[side])+delta*16.0)
		weights[side] = amount
		var target: Vector3 = anchors[side]
		var correction := (target-current).limit_length(MAX_CORRECTION)*amount
		if correction.length_squared()>0.000004:
			var error: float = actor.solve_leg(side,current+correction,actor.global_transform.basis*Vector3.FORWARD)
			max_error = maxf(max_error,error)
