extends Node2D

const Grid = preload("res://scripts/grid_world.gd")
const INK := Color("#28343b")
const PAPER := Color("#f4ede0")
const GOLD := Color("#edbd68")
const TEAL := Color("#397d79")
const WALK_SECONDS := 20
const STEP_TIME := 0.17

var fixtures: Array[Dictionary] = []
var blocked: Dictionary = {}
var player_cell := Vector2i(6, 7)
var player_screen := Vector2.ZERO
var move_from := Vector2.ZERO
var move_to := Vector2.ZERO
var move_elapsed := 0.0
var moving := false
var route: Array[Vector2i] = []
var pending_interaction := ""
var elapsed_seconds := 0
var money := 18
var carrying_returns := true
var bought_scarf := false
var journal_open := false
var ended := false
var message := "A quiet afternoon at Bellwether. Bring the sweater bag to Returns."
var notes: Array[String] = ["I arrived at Bellwether with a bag of returned sweaters."]

func _ready() -> void:
	_build_store()
	player_screen = Grid.screen_at(player_cell)
	queue_redraw()

func _build_store() -> void:
	fixtures.clear()
	blocked.clear()
	_add_fixture("returns", "RETURNS", "counter", [Vector2i(4, 3), Vector2i(5, 3)], 35, Color("#c98f69"), true)
	_add_fixture("clerk", "CLERK", "staff", [Vector2i(5, 4)], 0, Color("#6e849a"), true)
	_add_fixture("shirts", "SHIRTS", "rack", [Vector2i(9, 3), Vector2i(9, 4)], 42, Color("#719896"), true)
	_add_fixture("coats", "COATS", "rack", [Vector2i(3, 7), Vector2i(3, 8)], 46, Color("#8c7896"), true)
	_add_fixture("display", "SCARF DISPLAY", "display", [Vector2i(9, 8)], 35, Color("#bd7d69"), true)
	_add_fixture("television", "TELEVISION", "television", [Vector2i(2, 1)], 62, Color("#506878"), true)
	_add_fixture("door", "FRONT DOORS", "door", [Vector2i(12, 10)], 0, GOLD, false)

func _add_fixture(id: String, title: String, kind: String, cells: Array, height: int, color: Color, blocks: bool) -> void:
	fixtures.append({"id": id, "title": title, "kind": kind, "cells": cells, "height": height, "color": color})
	if blocks:
		for cell in cells:
			blocked[cell] = true

func _process(delta: float) -> void:
	if journal_open or ended:
		return
	if moving:
		move_elapsed += delta
		var amount := minf(move_elapsed / STEP_TIME, 1.0)
		player_screen = move_from.lerp(move_to, amount)
		if amount >= 1.0:
			moving = false
			player_cell = Grid.cell_at(move_to)
			player_screen = move_to
			elapsed_seconds += WALK_SECONDS
		queue_redraw()
	elif not route.is_empty():
		_begin_next_move()
	elif pending_interaction != "":
		var id := pending_interaction
		pending_interaction = ""
		_interact(id)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			journal_open = false
			queue_redraw()
			return
		if event.keycode == KEY_J:
			journal_open = not journal_open
			queue_redraw()
			return
		if ended:
			if event.keycode == KEY_R:
				_reset_afternoon()
			return
		if journal_open:
			return
		if event.keycode == KEY_E:
			_interact_nearest()
		elif event.keycode == KEY_SPACE:
			elapsed_seconds += 120
			_set_message("You take a short break and watch the store settle around you.")
		elif event.keycode == KEY_R:
			if carrying_returns:
				_plan_interaction("returns")
			else:
				_set_message("The sweater bag is already back at Returns.")
		else:
			var direction := Vector2i.ZERO
			match event.keycode:
				KEY_W, KEY_UP:
					direction = Vector2i(0, -1)
				KEY_S, KEY_DOWN:
					direction = Vector2i(0, 1)
				KEY_A, KEY_LEFT:
					direction = Vector2i(-1, 0)
				KEY_D, KEY_RIGHT:
					direction = Vector2i(1, 0)
			if direction != Vector2i.ZERO and not moving:
				route.clear()
				pending_interaction = ""
				var next := player_cell + direction
				if Grid.walkable(next, blocked):
					route.append(next)
				else:
					_set_message("A fixture or wall blocks that step.")
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if ended or journal_open or moving or event.position.y < 75 or event.position.y > 705:
			return
		var clicked := _fixture_at_point(event.position)
		if clicked != "":
			_plan_interaction(clicked)
			return
		var target := Grid.cell_at(event.position)
		if Grid.walkable(target, blocked):
			route = Grid.path(player_cell, target, blocked)
			pending_interaction = ""
			if route.is_empty() and target != player_cell:
				_set_message("There is no clear route to that floor tile.")

func _begin_next_move() -> void:
	var next: Vector2i = route.pop_front()
	if not Grid.walkable(next, blocked):
		route.clear()
		pending_interaction = ""
		return
	move_from = Grid.screen_at(player_cell)
	move_to = Grid.screen_at(next)
	move_elapsed = 0.0
	moving = true

func _fixture_at_point(point: Vector2) -> String:
	var best_id := ""
	var best_distance := 60.0
	for fixture in fixtures:
		for cell in fixture["cells"]:
			var anchor: Vector2 = Grid.screen_at(cell)
			var height: int = fixture["height"]
			var target := anchor - Vector2(0, height * 0.55)
			var distance := point.distance_to(target)
			if distance < best_distance:
				best_distance = distance
				best_id = fixture["id"]
	return best_id

func _interact_nearest() -> void:
	if moving:
		return
	var best_id := ""
	var best_distance := 2
	for fixture in fixtures:
		for cell in fixture["cells"]:
			var distance: int = absi(player_cell.x - cell.x) + absi(player_cell.y - cell.y)
			if distance < best_distance:
				best_distance = distance
				best_id = fixture["id"]
	if best_id == "":
		_set_message("Nothing is within reach. Walk closer or click an object.")
	else:
		_interact(best_id)

func _plan_interaction(id: String) -> void:
	if moving:
		return
	var selected: Dictionary = {}
	for fixture in fixtures:
		if fixture["id"] == id:
			selected = fixture
			break
	if selected.is_empty():
		return
	var shortest := 999
	var destination = null
	for cell in selected["cells"]:
		for offset in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
			var candidate: Vector2i = cell + offset
			if not Grid.walkable(candidate, blocked):
				continue
			var candidate_path := Grid.path(player_cell, candidate, blocked)
			if candidate == player_cell or not candidate_path.is_empty():
				if candidate_path.size() < shortest:
					shortest = candidate_path.size()
					destination = candidate
	if destination == null:
		_set_message("There is no clear approach to " + selected["title"] + ".")
		return
	route = Grid.path(player_cell, destination, blocked)
	pending_interaction = id
	if route.is_empty():
		pending_interaction = ""
		_interact(id)

func _interact(id: String) -> void:
	match id:
		"returns":
			if carrying_returns:
				carrying_returns = false
				elapsed_seconds += 90
				notes.append("The clerk accepted the returned sweater bag at the counter.")
				_set_message("The clerk checks the receipt and takes the sweater bag. 'Thanks for bringing it by.'")
			else:
				_set_message("The returns counter is clear. Your bag has already been checked in.")
		"clerk":
			elapsed_seconds += 60
			if carrying_returns:
				_set_message("Clerk: 'Returns are just beside me. I can help when you bring the bag over.'")
			else:
				_set_message("Clerk: 'All set with the sweaters. Take your time looking around.'")
		"shirts":
			elapsed_seconds += 60
			notes.append("The shirt rack has simple everyday styles.")
			_set_message("You browse neatly folded shirts. The tags show ordinary store prices.")
		"coats":
			elapsed_seconds += 60
			notes.append("A coat rack stands near the west aisle.")
			_set_message("You look through the coats and leave them on the rack.")
		"display":
			elapsed_seconds += 60
			if bought_scarf:
				_set_message("The display has other scarves, but you already chose one.")
			elif money >= 8:
				bought_scarf = true
				money -= 8
				notes.append("I bought a soft scarf from the display for $8.")
				_set_message("You buy a soft scarf for $8. The clerk nods as you tuck it into your bag.")
			else:
				_set_message("The scarf is $8, more than you have left today.")
		"television":
			elapsed_seconds += 120
			notes.append("The television loops a quiet home-goods demonstration.")
			_set_message("You watch a short home-goods demonstration on the store television.")
		"door":
			elapsed_seconds += 30
			ended = true
			_set_message("You step out toward the shopping arcade. This store slice ends here.")

func _reset_afternoon() -> void:
	player_cell = Vector2i(6, 7)
	player_screen = Grid.screen_at(player_cell)
	route.clear()
	pending_interaction = ""
	moving = false
	elapsed_seconds = 0
	money = 18
	carrying_returns = true
	bought_scarf = false
	journal_open = false
	ended = false
	notes = ["I arrived at Bellwether with a bag of returned sweaters."]
	_set_message("A new afternoon begins. Bring the sweater bag to Returns.")

func _set_message(value: String) -> void:
	message = value
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 800), Color("#d9cfc0"))
	_draw_walls()
	_draw_floor()
	var drawables: Array[Dictionary] = []
	for index in fixtures.size():
		var fixture: Dictionary = fixtures[index]
		var depth := 0
		for cell in fixture["cells"]:
			depth = maxi(depth, cell.x + cell.y)
		drawables.append({"type": "fixture", "index": index, "depth": depth})
	drawables.append({"type": "player", "depth": player_cell.x + player_cell.y + (0.5 if moving else 0.0)})
	drawables.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["depth"] < b["depth"])
	for item in drawables:
		if item["type"] == "player":
			_draw_person(player_screen, Color("#c85d50"), true)
		else:
			_draw_fixture(fixtures[item["index"]])
	_draw_ui()
	if journal_open:
		_draw_journal()
	if ended:
		_draw_ending()

func _draw_walls() -> void:
	var back_left := Grid.screen_at(Vector2i(0, 0)) + Vector2(-42, -21)
	var back_right := Grid.screen_at(Vector2i(13, 0)) + Vector2(42, -21)
	draw_colored_polygon(PackedVector2Array([back_left + Vector2(0, -112), back_right + Vector2(0, -112), back_right, back_left]), Color("#9bafa8"))
	draw_line(back_left + Vector2(0, -112), back_right + Vector2(0, -112), Color("#6b827e"), 4)
	var west_top := Grid.screen_at(Vector2i(0, 0)) + Vector2(-42, -21)
	var west_bottom := Grid.screen_at(Vector2i(0, 11)) + Vector2(-42, 21)
	draw_colored_polygon(PackedVector2Array([west_top + Vector2(0, -112), west_bottom + Vector2(0, -112), west_bottom, west_top]), Color("#b2b3a1"))
	draw_line(west_top + Vector2(0, -112), west_bottom + Vector2(0, -112), Color("#8a917e"), 4)
	draw_string(ThemeDB.fallback_font, Vector2(587, 63), "BELLWETHER", HORIZONTAL_ALIGNMENT_CENTER, 170, 24, Color("#294851"))

func _diamond(center: Vector2) -> PackedVector2Array:
	return PackedVector2Array([center + Vector2(0, -21), center + Vector2(42, 0), center + Vector2(0, 21), center + Vector2(-42, 0)])

func _draw_floor() -> void:
	for y in Grid.HEIGHT:
		for x in Grid.WIDTH:
			var cell := Vector2i(x, y)
			var center: Vector2 = Grid.screen_at(cell)
			var tile_color := Color("#e9dcc8") if (x + y) % 2 == 0 else Color("#e3d4bf")
			if y >= 9 and x >= 10:
				tile_color = Color("#d7c2a7")
			draw_colored_polygon(_diamond(center), tile_color)
			draw_polyline(PackedVector2Array([center + Vector2(0, -21), center + Vector2(42, 0), center + Vector2(0, 21), center + Vector2(-42, 0), center + Vector2(0, -21)]), Color("#cbbba6"), 1.0)
	var welcome := Grid.screen_at(Vector2i(11, 10))
	draw_colored_polygon(_diamond(welcome), Color("#b57858", 0.45))

func _draw_fixture(fixture: Dictionary) -> void:
	var kind: String = fixture["kind"]
	var color: Color = fixture["color"]
	var height: int = fixture["height"]
	var label_position := Vector2.ZERO
	for cell in fixture["cells"]:
		var center: Vector2 = Grid.screen_at(cell)
		label_position += center
		if kind == "staff":
			_draw_person(center, color, false)
		elif kind == "door":
			_draw_doors(center)
		else:
			_draw_prism(center, height, color)
			if kind == "rack":
				draw_line(center + Vector2(-24, -height - 8), center + Vector2(24, -height - 8), INK, 4)
				for dx in [-16, 0, 16]:
					draw_line(center + Vector2(dx, -height - 5), center + Vector2(dx, -height + 12), color.lightened(0.4), 5)
			elif kind == "television":
				draw_rect(Rect2(center.x - 27, center.y - height - 8, 54, 36), INK)
				draw_rect(Rect2(center.x - 22, center.y - height - 3, 44, 26), Color("#9fc3c6"))
			elif kind == "display":
				draw_circle(center + Vector2(0, -height - 8), 12, Color("#e7a687"))
	label_position /= float(fixture["cells"].size())
	var label_y := -height - 34
	if kind == "staff":
		label_y = -86
	if kind == "door":
		label_y = -76
	draw_string(ThemeDB.fallback_font, label_position + Vector2(-64, label_y), fixture["title"], HORIZONTAL_ALIGNMENT_CENTER, 128, 15, INK)

func _draw_prism(center: Vector2, height: int, color: Color) -> void:
	var top := center + Vector2(0, -height)
	draw_colored_polygon(PackedVector2Array([top + Vector2(-38, 0), top + Vector2(0, 19), center + Vector2(0, 19), center + Vector2(-38, 0)]), color.darkened(0.28))
	draw_colored_polygon(PackedVector2Array([top + Vector2(0, 19), top + Vector2(38, 0), center + Vector2(38, 0), center + Vector2(0, 19)]), color.darkened(0.15))
	draw_colored_polygon(PackedVector2Array([top + Vector2(0, -19), top + Vector2(38, 0), top + Vector2(0, 19), top + Vector2(-38, 0)]), color.lightened(0.16))
	draw_line(top + Vector2(-38, 0), top + Vector2(0, -19), color.darkened(0.35), 2)
	draw_line(top + Vector2(0, -19), top + Vector2(38, 0), color.darkened(0.35), 2)

func _draw_person(feet: Vector2, coat: Color, player: bool) -> void:
	draw_circle(feet + Vector2(0, -3), 12, Color("#5d6258", 0.28))
	draw_line(feet + Vector2(-7, -10), feet + Vector2(-7, -27), INK, 5)
	draw_line(feet + Vector2(7, -10), feet + Vector2(7, -27), INK, 5)
	draw_colored_polygon(PackedVector2Array([feet + Vector2(-16, -63), feet + Vector2(16, -63), feet + Vector2(12, -26), feet + Vector2(-12, -26)]), coat)
	draw_circle(feet + Vector2(0, -73), 12, Color("#d4a67c"))
	draw_line(feet + Vector2(-15, -58), feet + Vector2(-22, -38), Color("#d4a67c"), 5)
	draw_line(feet + Vector2(15, -58), feet + Vector2(22, -38), Color("#d4a67c"), 5)
	if player and carrying_returns:
		draw_rect(Rect2(feet.x + 16, feet.y - 36, 22, 23), Color("#eee2bf"))
		draw_line(feet + Vector2(18, -36), feet + Vector2(36, -36), Color("#936f51"), 3)

func _draw_doors(center: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([center + Vector2(-34, -9), center + Vector2(-34, -70), center + Vector2(34, -70), center + Vector2(34, -9)]), Color("#547a7c"))
	draw_rect(Rect2(center.x - 30, center.y - 67, 60, 52), Color("#b9d2cc"))
	draw_line(center + Vector2(0, -67), center + Vector2(0, -15), Color("#496d70"), 3)
	draw_circle(center + Vector2(-6, -38), 3, GOLD)
	draw_circle(center + Vector2(6, -38), 3, GOLD)

func _draw_ui() -> void:
	draw_rect(Rect2(0, 0, 1280, 75), INK)
	draw_string(ThemeDB.fallback_font, Vector2(24, 33), "HUGHESLIKE", HORIZONTAL_ALIGNMENT_LEFT, 300, 28, PAPER)
	draw_string(ThemeDB.fallback_font, Vector2(25, 59), "Bellwether Department Store · temporary drawn art", HORIZONTAL_ALIGNMENT_LEFT, 520, 15, GOLD)
	draw_string(ThemeDB.fallback_font, Vector2(1035, 33), _clock_text() + "  ·  $" + str(money), HORIZONTAL_ALIGNMENT_RIGHT, 220, 21, PAPER)
	draw_string(ThemeDB.fallback_font, Vector2(983, 58), "Bag: " + ("returns" if carrying_returns else "delivered"), HORIZONTAL_ALIGNMENT_RIGHT, 270, 15, GOLD)
	draw_rect(Rect2(0, 708, 1280, 92), INK)
	draw_string(ThemeDB.fallback_font, Vector2(24, 741), message, HORIZONTAL_ALIGNMENT_LEFT, 1230, 19, PAPER)
	draw_string(ThemeDB.fallback_font, Vector2(24, 778), "WASD / arrows: walk    Click: go or use    E: nearby interaction    R: take bag to Returns    J: notebook    Space: wait", HORIZONTAL_ALIGNMENT_LEFT, 1230, 15, GOLD)

func _draw_journal() -> void:
	draw_rect(Rect2(265, 155, 750, 500), Color("#23313a", 0.92))
	draw_rect(Rect2(285, 175, 710, 460), PAPER)
	draw_string(ThemeDB.fallback_font, Vector2(315, 215), "Afternoon notebook", HORIZONTAL_ALIGNMENT_LEFT, 650, 28, INK)
	draw_string(ThemeDB.fallback_font, Vector2(315, 245), "Things you noticed or did. J / Esc to close.", HORIZONTAL_ALIGNMENT_LEFT, 650, 16, TEAL)
	for index in mini(notes.size(), 9):
		draw_string(ThemeDB.fallback_font, Vector2(315, 285 + index * 35), "• " + notes[index], HORIZONTAL_ALIGNMENT_LEFT, 640, 17, INK)

func _draw_ending() -> void:
	draw_rect(Rect2(322, 252, 636, 215), Color("#23313a", 0.94))
	draw_string(ThemeDB.fallback_font, Vector2(350, 302), "The afternoon continues outside.", HORIZONTAL_ALIGNMENT_CENTER, 580, 28, PAPER)
	draw_string(ThemeDB.fallback_font, Vector2(350, 350), "Store visit: " + ("returns delivered" if not carrying_returns else "returns still in hand") + " · " + ("scarf bought" if bought_scarf else "no purchase"), HORIZONTAL_ALIGNMENT_CENTER, 580, 19, GOLD)
	draw_string(ThemeDB.fallback_font, Vector2(350, 413), "Press R to begin another store visit.", HORIZONTAL_ALIGNMENT_CENTER, 580, 17, PAPER)

func _clock_text() -> String:
	var total_minutes := 14 * 60 + int(elapsed_seconds / 60.0)
	return "%02d:%02d" % [int(total_minutes / 60.0), total_minutes % 60]
