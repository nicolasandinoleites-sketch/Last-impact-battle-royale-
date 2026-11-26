extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func frames(n: int) -> void:
	for i in range(n):
		await physics_frame

func check(ok: bool, label: String) -> bool:
	if not ok:
		push_error("TEST FAILED: touch " + label)
		quit(1)
		return false
	print("PASS: touch " + label)
	return true

# Engine-level event fixtures, not OS-injected input or physical multitouch.
func touch(hud, id: int, at: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = id
	event.position = at
	event.pressed = down
	hud._input(event)

func drag(hud, id: int, at: Vector2, relative: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = id
	event.position = at
	event.relative = relative
	hud._input(event)

func tap(hud, name: String, id: int = 0) -> void:
	var p: Vector2 = hud.buttons()[name]
	touch(hud,id,p,true)
	touch(hud,id,p,false)

func run() -> void:
	var game = load("res://survival.tscn").instantiate()
	root.add_child(game)
	await frames(15)
	var hud = game.hud
	var start: Vector2 = hud.at(0.14,0.80)
	var finish: Vector2 = start+Vector2(0,-54)*hud.unit()
	var initial: Vector3 = game.player.position
	touch(hud,0,start,true)
	drag(hud,0,finish,finish-start)
	await frames(20)
	if not check(game.player.position.distance_to(initial)>0.2 and game.mobile_move.length()>0.4,"joystick displacement"):
		return
	tap(hud,"SLIDE",1)
	await frames(3)
	if not check(game.player.slide_time>0.0 and game.player.low_stance,"slide with joystick held (synthetic two contacts)"):
		return
	touch(hud,0,finish,false)
	if not check(game.mobile_move==Vector2.ZERO and hud.move_id==-1,"joystick release"):
		return
	game.reset_round()
	await frames(15)
	var fire_point: Vector2 = hud.buttons()["FIRE"]
	touch(hud,0,fire_point,true)
	await frames(20)
	touch(hud,0,fire_point,false)
	if not check(game.ammo<30 and not game.fire and hud.fire_id==-1,"fire consumes ammo and releases"):
		return
	var missing: int = 30-game.ammo
	var reserve_before: int = game.reserve
	tap(hud,"LOAD")
	await frames(100)
	if not check(game.ammo==30 and game.reserve==reserve_before-missing,"reload transfers actual ammunition"):
		return
	tap(hud,"AIM")
	if not check(game.player.aiming,"aim enabled"):
		return
	tap(hud,"AIM")
	if not check(not game.player.aiming,"aim disabled"):
		return
	tap(hud,"JUMP")
	await frames(5)
	if not check(game.player.velocity.y>0 and not game.player.is_on_floor(),"jump physics"):
		return
	game.reset_round()
	var supply = game.pickups[0]
	game.player.position = supply.position+Vector3.UP*0.1
	game.player.reset_physics_interpolation()
	tap(hud,"PICKUP")
	if not check(game.inventory.medkits==1 and not supply.active,"pickup touch with controlled proximity"):
		return
	game.health = 65
	tap(hud,"MED")
	if not check(game.health==100 and game.inventory.medkits==0,"heal consumes inventory"):
		return
	print("LAST IMPACT TOUCH FIXTURES PASS")
	quit(0)
