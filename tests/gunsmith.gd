extends SceneTree
const Preset = preload("res://scripts/loadout_preset.gd")
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 OS.set_environment("LASTIMPACT_LOADOUT_PATH","user://qa_gunsmith.cfg")
 var saved := Preset.new()
 saved.weapon_id = "HELIOS"
 saved.extended = true
 saved.holographic = true
 assert(saved.save_preset()==OK)
 var restored := Preset.new()
 restored.load_preset()
 assert(restored.weapon_id=="HELIOS" and restored.price()==375)
 var game = load("res://battle_royale.tscn").instantiate()
 root.add_child(game)
 await physics_frame
 game.deployment.finish()
 game.set_physics_process(false)
 game.player.set_physics_process(false)
 for target in game.targets: target.set_physics_process(false)
 var s = game.supplies
 game.player.global_position = s.station.global_position
 assert(s.next_store_weapon()=="HELIOS" and s.store_price()==375)
 assert(not s.buy_weapon() and s.credits==300)
 s.credits = 450
 assert(s.buy_weapon() and s.credits==75 and game.owned_weapons.size()==2)
 assert(game.weapon_id=="HELIOS" and game.magazine_capacity()==8 and game.ammo==8)
 assert(s.has_upgrade("HELIOS","HOLO") and s.has_upgrade("HELIOS","RELOAD"))
 var weapon = game.player.weapon
 assert(weapon.accessories.HOLO.visible and weapon.accessories.MAG.visible and weapon.accessories.RELOAD.visible)
 assert(game.cycle_weapon() and game.weapon_id=="IGNIS")
 assert(not weapon.accessories.HOLO.visible and not weapon.accessories.MAG.visible)
 assert(s.buy_upgrade("HOLO") and s.credits==0 and weapon.accessories.HOLO.visible)
 assert(game.cycle_weapon() and game.equip_weapon("ARC",true))
 assert(game.owned_weapons.size()==2 and not weapon.accessories.HOLO.visible)
 var drop = game.corpse_pickups.back()
 assert(drop.kind=="WEAPON_HELIOS" and drop.attachments.HOLO and drop.attachments.MAG)
 game.reset_round()
 assert(game.owned_weapons.size()==1 and s.upgrades.is_empty() and not weapon.accessories.HOLO.visible)
 DirAccess.remove_absolute("user://qa_gunsmith.cfg")
 print("R0791 GUNSMITH PASS | saved preset, exact price, purchases, visible accessories, swap, drop, reset")
 game.queue_free()
 await process_frame
 await process_frame
 OS.delay_msec(180)
 quit()
