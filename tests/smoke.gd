extends SceneTree

const Grid = preload("res://scripts/grid_world.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, detail: String) -> void:
	if not condition:
		failures += 1
		push_error(detail)

func _run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	_check(scene.player_cell == Vector2i(6, 7), "The player should start on the sales floor.")
	_check(not Grid.walkable(Vector2i(4, 3), scene.blocked), "The returns counter should block walking.")
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_J
	scene._unhandled_input(key)
	_check(scene.journal_open, "J should open the notebook.")
	key.keycode = KEY_ESCAPE
	scene._unhandled_input(key)
	_check(not scene.journal_open, "Escape should close the notebook.")
	key.keycode = KEY_D
	scene._unhandled_input(key)
	for i in 3:
		scene._process(0.2)
	_check(scene.player_cell == Vector2i(7, 7), "D should move the player one floor cell.")
	var mouse := InputEventMouseButton.new()
	mouse.pressed = true
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = Grid.screen_at(Vector2i(7, 6))
	scene._unhandled_input(mouse)
	for i in 3:
		scene._process(0.2)
	_check(scene.player_cell == Vector2i(7, 6), "Clicking a floor cell should move the player there.")
	for fixture in scene.fixtures:
		var reachable := false
		for cell in fixture["cells"]:
			for direction in Grid.DIRECTIONS:
				var adjacent: Vector2i = cell + direction
				if Grid.walkable(adjacent, scene.blocked):
					if not Grid.path(scene.player_cell, adjacent, scene.blocked).is_empty() or adjacent == scene.player_cell:
						reachable = true
		_check(reachable, fixture["title"] + " should have a reachable approach.")
	scene._plan_interaction("returns")
	for i in 40:
		scene._process(0.2)
	_check(not scene.carrying_returns, "The returns interaction should hand off the bag.")
	scene._plan_interaction("display")
	for i in 70:
		scene._process(0.2)
	_check(scene.bought_scarf and scene.money == 10, "The scarf purchase should cost $8.")
	scene._plan_interaction("door")
	for i in 70:
		scene._process(0.2)
	_check(scene.ended, "The front door should finish this store visit.")
	scene._reset_afternoon()
	_check(scene.carrying_returns and scene.money == 18 and not scene.ended, "Restart should restore the initial state.")
	print("Store smoke checks: ", "PASS" if failures == 0 else str(failures) + " failed")
	quit(0 if failures == 0 else 1)
