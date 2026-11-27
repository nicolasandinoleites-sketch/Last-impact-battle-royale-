extends RefCounted
# Fictional gameplay balance. Visual variants share the original Tripo rig.
const ORDER := ["IGNIS", "VOLTAR", "ARC", "HELIOS"]
const DATA := {
 "IGNIS":{"name":"IGNIS X1","mag":30,"damage":34,"delay":0.15,"reload":1.4,"range":100.0,"family":"ENERGY","tint":Color.WHITE},
 "VOLTAR":{"name":"VOLTAR-9","mag":36,"damage":17,"delay":0.09,"reload":1.15,"range":30.0,"family":"LIGHT","tint":Color("7ad8e8")},
 "ARC":{"name":"ARC CANNON","mag":12,"damage":48,"delay":0.36,"reload":1.75,"range":65.0,"family":"PLASMA","tint":Color("bc91f8")},
 "HELIOS":{"name":"HELIOS SR","mag":6,"damage":78,"delay":0.72,"reload":2.15,"range":110.0,"family":"HEAVY","tint":Color("f4c378")}
}
const AMMO_TYPES := {"AMMO":"ENERGY","AMMO_LIGHT":"LIGHT","AMMO_PLASMA":"PLASMA","AMMO_HEAVY":"HEAVY"}
static func spec(id: String) -> Dictionary:
 return DATA.get(id,DATA.IGNIS)
static func pickup_label(kind: String) -> String:
 if kind.begins_with("WEAPON_"): return str(spec(kind.trim_prefix("WEAPON_")).name)
 return str({"CASH":"CREDITOS","GRENADE":"GRANADA DE PULSO","MED":"BOTIQUIN","SHIELD":"ESCUDO","AMMO":"ENERGIA","AMMO_LIGHT":"CELDAS LIGERAS","AMMO_PLASMA":"PLASMA","AMMO_HEAVY":"CELDAS PESADAS"}.get(kind,kind))
