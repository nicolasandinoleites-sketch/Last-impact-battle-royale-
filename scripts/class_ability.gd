extends Node
const Classes = preload("res://scripts/operator_classes.gd")
var selection := Classes.new()
var game
var class_id := "RAZE"
var active_left := 0.0
var cooldown_left := 0.0

func configure(owner_game) -> void:
 game = owner_game
 selection.load_selection()
 class_id = selection.selected

func spec() -> Dictionary:
 return Classes.DATA[class_id]

func active(id: String) -> bool:
 return class_id==id and active_left>0.0

func activate() -> bool:
 if not is_instance_valid(game) or game.deployment_active() or game.round_result!="" or game.health<=0 or cooldown_left>0.0: return false
 if class_id=="SERAPH":
  if game.health>=100 and game.armor>=100: return false
  game.health = mini(100,game.health+30)
  game.armor = mini(100,game.armor+20)
 active_left = float(spec().duration)
 cooldown_left = float(spec().cooldown)
 game.message = str(spec().skill)+" ACTIVADA"
 return true

func step(delta: float) -> void:
 active_left = maxf(0.0,active_left-delta)
 cooldown_left = maxf(0.0,cooldown_left-delta)

func reset() -> void:
 active_left = 0.0
 cooldown_left = 0.0

func shot_factor() -> float:
 return 0.75 if active("RAZE") else 1.0

func movement_factor() -> float:
 return 1.2 if active("PHANTOM") else 1.0

func detection_range() -> float:
 return 5.0 if active("PHANTOM") else 18.0

func reduce_damage(amount: int, combat: bool) -> int:
 return ceili(float(amount)*0.5) if combat and active("TITAN") else amount

func reveals(distance: float) -> bool:
 return distance<=8.0 or (active("SPECTRE") and distance<=45.0)
