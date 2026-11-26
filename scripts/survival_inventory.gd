extends RefCounted
const MED_MAX := 3
const SHIELD_MAX := 3
const AMMO_MAX := 180
const MED_HEAL := 35
const SHIELD_HEAL := 25
var medkits := 0
var shield_cells := 0

func reset() -> void:
	medkits = 0
	shield_cells = 0

func add_item(kind: String, quantity: int) -> int:
	var amount := maxi(0,quantity)
	if kind=="MED":
		var taken := mini(amount,MED_MAX-medkits)
		medkits += taken
		return taken
	if kind=="SHIELD":
		var taken := mini(amount,SHIELD_MAX-shield_cells)
		shield_cells += taken
		return taken
	return 0

func use_med(health: int) -> int:
	if medkits<=0 or health>=100 or health<=0:
		return health
	medkits -= 1
	return mini(100,health+MED_HEAL)

func use_shield(armor: int) -> int:
	if shield_cells<=0 or armor>=100:
		return armor
	shield_cells -= 1
	return mini(100,armor+SHIELD_HEAL)
