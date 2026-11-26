extends RefCounted
# Compatibility-safe lens protection: no material transparency or hitbox changes.
# Only suppress the cosmetic mesh when the near lens intersects the actor capsule.
static func overlaps_lens(camera_pos: Vector3, actor_pos: Vector3, was_hidden: bool) -> bool:
	var radius := 0.78 if was_hidden else 0.58
	var closest := actor_pos+Vector3.UP*clampf(camera_pos.y-actor_pos.y,0.25,1.65)
	return camera_pos.distance_squared_to(closest)<radius*radius
