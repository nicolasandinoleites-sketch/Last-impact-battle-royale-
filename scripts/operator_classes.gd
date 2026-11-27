extends RefCounted
const ORDER = ["RAZE","PHANTOM","TITAN","SERAPH","SPECTRE"]
const DATA = {
 "RAZE":{"role":"ASALTO","skill":"SOBRECARGA","desc":"Cadencia +33% durante 6 s.","duration":6.0,"cooldown":28.0,"color":"ffae58"},
 "PHANTOM":{"role":"INFILTRACION","skill":"SIGILO","desc":"Deteccion rival reducida a 5 m; velocidad +20%.","duration":5.0,"cooldown":32.0,"color":"b49aff"},
 "TITAN":{"role":"DEFENSA","skill":"BASTION","desc":"Reduce el dano de combate un 50% durante 5 s.","duration":5.0,"cooldown":35.0,"color":"69b8ff"},
 "SERAPH":{"role":"SOPORTE","skill":"REPARACION","desc":"Recupera 30 de vida y 20 de escudo.","duration":0.0,"cooldown":40.0,"color":"6de3ad"},
 "SPECTRE":{"role":"RECONOCIMIENTO","skill":"ESCANEO","desc":"Revela rivales hasta 45 m en el minimapa durante 7 s.","duration":7.0,"cooldown":30.0,"color":"f0df72"}
}
var selected := "RAZE"

func path() -> String:
 var override := OS.get_environment("LASTIMPACT_CLASS_PATH")
 return override if not override.is_empty() else "user://lastimpact_class.cfg"

func load_selection() -> void:
 var cfg := ConfigFile.new()
 if cfg.load(path())!=OK: return
 var id := str(cfg.get_value("operator","class","RAZE"))
 selected = id if DATA.has(id) else "RAZE"

func save_selection() -> Error:
 var cfg := ConfigFile.new()
 cfg.set_value("operator","class",selected if DATA.has(selected) else "RAZE")
 return cfg.save(path())
