extends RefCounted
# Read static geometry on FRONTIER's world collision layer (1).
# Origin is the operator's feet, not the centre of its capsule.
var space: PhysicsDirectSpaceState3D
var excluded: Array[RID] = []
const WORLD_MASK := 1
const PROBE_DEPTH := 180.0
const MIN_FLOOR_NORMAL := 0.7

func configure(state: PhysicsDirectSpaceState3D, ignore: Array[RID] = []) -> void:
 space = state
 excluded = ignore.duplicate()

func height_below(feet: Vector3) -> float:
 if space == null:
  return NAN
 var query := PhysicsRayQueryParameters3D.create(feet+Vector3.UP*0.04,feet-Vector3.UP*PROBE_DEPTH,WORLD_MASK,excluded)
 query.collide_with_areas = false
 var hit := space.intersect_ray(query)
 if hit.is_empty() or Vector3(hit["normal"]).y < MIN_FLOOR_NORMAL:
  return NAN
 return Vector3(hit["position"]).y

func standing_clear(feet: Vector3) -> bool:
 if space == null:
  return false
 var shape := CapsuleShape3D.new()
 shape.radius = 0.36
 shape.height = 1.76
 var query := PhysicsShapeQueryParameters3D.new()
 query.shape = shape
 query.transform = Transform3D(Basis.IDENTITY,feet+Vector3.UP*0.94)
 query.collision_mask = WORLD_MASK
 query.exclude = excluded
 query.collide_with_areas = false
 return space.intersect_shape(query,1).is_empty()
