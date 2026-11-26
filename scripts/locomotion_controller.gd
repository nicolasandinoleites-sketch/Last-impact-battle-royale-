extends RefCounted
# Ground-plane velocity uses a single vector budget; diagonal input cannot
# accelerate faster than cardinal input. A reversal brakes before accelerating.
const GROUND_ACCEL := 20.0
const GROUND_BRAKE := 26.0
const REVERSE_BRAKE := 32.0
const AIR_ACCEL := 8.0
const SPRINT_ACCEL := 16.0

static func step(current: Vector2, desired: Vector2, grounded: bool, sprinting: bool, delta: float) -> Vector2:
	var rate := SPRINT_ACCEL if sprinting else GROUND_ACCEL
	if not grounded:
		rate = AIR_ACCEL
	elif desired.length_squared()<0.001:
		rate = GROUND_BRAKE
	elif current.dot(desired)<0.0:
		rate = REVERSE_BRAKE
	elif current.length()>desired.length():
		rate = GROUND_BRAKE
	return current.move_toward(desired,rate*maxf(delta,0.0))

static func facing_target(camera_yaw: float, current_yaw: float, direction: Vector3, combat: bool, sliding: bool) -> float:
	if sliding and direction.length_squared()>0.01:
		return atan2(-direction.x,-direction.z)
	if combat:
		return camera_yaw
	if direction.length_squared()>0.015:
		return atan2(-direction.x,-direction.z)
	# Free look has a dead zone; turn the hips only after a large idle camera turn.
	var difference := angle_difference(current_yaw,camera_yaw)
	if absf(difference)>deg_to_rad(65.0):
		return camera_yaw
	return current_yaw
