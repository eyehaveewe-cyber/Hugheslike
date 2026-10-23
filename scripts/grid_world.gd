class_name StoreGrid
extends RefCounted

const WIDTH := 14
const HEIGHT := 12
const HALF_W := 42.0
const HALF_H := 21.0
const ORIGIN := Vector2(625, 175)
const DIRECTIONS := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]

static func screen_at(cell: Vector2i) -> Vector2:
	return ORIGIN + Vector2((cell.x - cell.y) * HALF_W, (cell.x + cell.y) * HALF_H)

static func cell_at(point: Vector2) -> Vector2i:
	var relative := point - ORIGIN
	var diagonal_a := relative.x / HALF_W
	var diagonal_b := relative.y / HALF_H
	return Vector2i(roundi((diagonal_a + diagonal_b) / 2.0), roundi((diagonal_b - diagonal_a) / 2.0))

static func inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < WIDTH and cell.y >= 0 and cell.y < HEIGHT

static func walkable(cell: Vector2i, blocked: Dictionary) -> bool:
	return inside(cell) and not blocked.has(cell)

static func path(start: Vector2i, target: Vector2i, blocked: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not walkable(target, blocked):
		return result
	var frontier: Array[Vector2i] = [start]
	var previous := {start: start}
	var cursor := 0
	while cursor < frontier.size():
		var current := frontier[cursor]
		cursor += 1
		if current == target:
			break
		for direction in DIRECTIONS:
			var next: Vector2i = current + direction
			if walkable(next, blocked) and not previous.has(next):
				previous[next] = current
				frontier.append(next)
	if not previous.has(target):
		return result
	var step := target
	while step != start:
		result.push_front(step)
		step = previous[step]
	return result
