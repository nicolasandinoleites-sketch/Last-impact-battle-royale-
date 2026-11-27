extends RefCounted
const Catalog = preload("res://scripts/weapon_catalog.gd")
var weapon_id := ""
var extended := false
var holographic := false

func config_path() -> String:
 var override := OS.get_environment("LASTIMPACT_LOADOUT_PATH")
 return override if not override.is_empty() else "user://lastimpact_loadout.cfg"

func load_preset() -> void:
 var cfg := ConfigFile.new()
 if cfg.load(config_path())!=OK: return
 var id := str(cfg.get_value("armory","weapon",""))
 weapon_id = id if Catalog.DATA.has(id) else ""
 extended = bool(cfg.get_value("armory","extended",false))
 holographic = bool(cfg.get_value("armory","holographic",false))

func save_preset() -> Error:
 var cfg := ConfigFile.new()
 cfg.set_value("armory","weapon",weapon_id)
 cfg.set_value("armory","extended",extended)
 cfg.set_value("armory","holographic",holographic)
 return cfg.save(config_path())

func attachments() -> Dictionary:
 var result := {"RELOAD":true}
 if extended: result["MAG"] = true
 if holographic: result["HOLO"] = true
 return result

func price() -> int:
 return 200+(100 if extended else 0)+(75 if holographic else 0)
