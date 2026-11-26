extends RefCounted
# Small, explicit loot table. All quantities use the existing inventory caps.
static func operator_drop(rounds: int, shield: int, seed_value: int) -> Array:
 var result: Array = [["AMMO",maxi(12,rounds*4)]]
 result.append(["SHIELD" if shield>0 or posmod(seed_value,2)==0 else "MED",1])
 return result
