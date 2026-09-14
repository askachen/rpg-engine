class_name StoryCore
extends RefCounted
## The authoritative game rules. Both the GUI and headless runner call act().

var content: Dictionary = {}
var state: Dictionary = {}
var active_event := ""
var history: Array = []
var load_error := ""
const PERIODS = ["day", "evening", "late"]

func load_content(path: String) -> bool:
	var loader = preload("res://engine/content_loader.gd").new()
	var parsed: Dictionary = loader.load_game(path)
	if loader.error != "":
		load_error = loader.error
		return false
	if not preload("res://engine/game_bootstrap.gd").valid_id(str(parsed.get("id", ""))):
		load_error = "Invalid game ID; expected 1-64 letters, digits, underscores or hyphens."
		return false
	content = parsed
	new_game()
	return true

func new_game() -> void:
	state = content.get("initial", {}).duplicate(true)
	active_event = ""
	history.clear()

func tr_key(key: String, language: String = "zh_TW") -> String:
	var catalog: Dictionary = content.get("locales", {})
	return str(catalog.get(language, {}).get(key, catalog.get(default_language(), {}).get(key, key)))

func protagonist_id() -> String:
	return str(content.get("protagonist", "player"))

func default_language() -> String:
	return str(content.get("default_language", "zh_TW"))

func result(ok: bool, message: String, extra: Dictionary = {}) -> Dictionary:
	var out := {"ok": ok, "message": message}
	out.merge(extra)
	return out

func checks(conditions: Array) -> Array:
	var output: Array = []
	for condition in conditions:
		var actual = null
		var expected = condition.get("value", true)
		var passed := false
		match condition.get("kind", ""):
			"affection":
				actual = state.characters[condition.id].affection
				passed = actual >= expected
			"stage":
				actual = state.characters[condition.id].stage
				passed = actual == expected
			"item":
				actual = state.inventory.get(condition.id, 0)
				passed = actual >= expected
			"completed":
				actual = condition.id in state.completed
				passed = actual == expected
			"flag":
				actual = state.flags.get(condition.id, false)
				passed = actual == expected
			"period":
				actual = state.period
				passed = actual == expected
			"money":
				actual = state.money
				passed = actual >= expected
		output.append({"condition": condition, "actual": actual, "expected": expected, "passed": passed})
	return output

func satisfied(conditions: Array) -> bool:
	for check in checks(conditions):
		if not check.passed:
			return false
	return true

func route_progress(who: String) -> Dictionary:
	var ids: Array = content.get("routes", {}).get(who, {}).get("events", [])
	var done := 0
	var next := ""
	for id in ids:
		if id in state.completed: done += 1
		elif next == "": next = id
	return {"completed": done, "total": ids.size(), "next_event": next,
		"complete": not ids.is_empty() and done == ids.size()}

func route_allows(event_id: String) -> bool:
	for who in content.get("routes", {}):
		if event_id in content.routes[who].events:
			return route_progress(who).next_event == event_id
	return true # Unlisted events are independent side events.

func current_ending() -> String:
	var ids: Array = content.get("endings", {}).keys()
	ids.sort()
	for id in ids:
		var requirements: Array = content.endings[id].get("conditions", [])
		if not requirements.is_empty() and satisfied(requirements): return id
	return ""

func advance_time(amount: int) -> void:
	var total := PERIODS.find(state.period) + amount
	state.day += int(total / 3)
	state.period = PERIODS[total % 3]

func adjacent(position: Array) -> bool:
	return abs(int(position[0]) - int(state.position[0])) + abs(int(position[1]) - int(state.position[1])) <= 1

func target_visible(target: Dictionary) -> bool:
	return satisfied(target.get("conditions", []))

func walkable(pos: Vector2i) -> bool:
	var area: Dictionary = content.maps[state.map]
	if pos.x < 0 or pos.y < 0 or pos.x >= area.width or pos.y >= area.height:
		return false
	for wall in area.walls:
		if Vector2i(int(wall[0]), int(wall[1])) == pos:
			return false
	for furnishing in area.get("furniture", []):
		if furnishing.get("solid", true) and Rect2i(int(furnishing.position[0]), int(furnishing.position[1]), int(furnishing.size[0]), int(furnishing.size[1])).has_point(pos):
			return false
	for target in area.objects:
		if Vector2i(int(target.position[0]), int(target.position[1])) == pos and target.get("solid", true) and target_visible(target) and not state.objects.get(target.id, false):
			return false
	return true

func path_to(destination: Vector2i, interaction: bool = false) -> Dictionary:
	## Plans only; every returned step must still be executed through act(move).
	var start := Vector2i(int(state.position[0]), int(state.position[1]))
	var queue: Array[Vector2i] = [start]
	var parents: Dictionary = {start: start}
	var cursor := 0
	while cursor < queue.size():
		var current: Vector2i = queue[cursor]
		cursor += 1
		var distance := absi(current.x - destination.x) + absi(current.y - destination.y)
		if distance <= (1 if interaction else 0):
			var path: Array[Vector2i] = []
			while current != start:
				path.push_front(current)
				current = parents[current]
			return {"ok": true, "path": path}
		for offset in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
			var next: Vector2i = current + offset
			if not parents.has(next) and walkable(next):
				parents[next] = current
				queue.append(next)
	return {"ok": false, "path": []}

func act(command: Dictionary) -> Dictionary:
	var before := state.duplicate(true)
	var response := _act(command)
	history.append({"command": command.duplicate(true), "result": response.duplicate(true), "before": before, "after": state.duplicate(true)})
	return response

func _act(command: Dictionary) -> Dictionary:
	var op := str(command.get("op", ""))
	if active_event != "" and op != "choose":
		return result(false, "event_busy")
	match op:
		"move":
			var dx := int(command.get("dx", 0))
			var dy := int(command.get("dy", 0))
			if abs(dx) + abs(dy) != 1:
				return result(false, "invalid_move")
			var pos: Array = [state.position[0] + dx, state.position[1] + dy]
			if not walkable(Vector2i(int(pos[0]), int(pos[1]))):
				return result(false, "blocked")
			state.position = pos
			return result(true, "moved")
		"wait":
			advance_time(1)
			return result(true, "time_advanced")
		"interact":
			for target in content.maps[state.map].objects:
				if target.id != command.get("target", ""):
					continue
				if not adjacent(target.position):
					return result(false, "too_far")
				if not target_visible(target):
					return result(false, "unavailable", {"checks": checks(target.get("conditions", []))})
				match target.kind:
					"exit":
						state.map = target.destination
						state.position = content.maps[state.map].spawns[target.spawn].duplicate()
						return result(true, "map_changed")
					"pickup", "switch":
						if state.objects.get(target.id, false):
							return result(false, "already_used")
						if not apply_effects(target.effects):
							return result(false, "effect_failed")
						state.objects[target.id] = true
						return result(true, "collected" if target.kind == "pickup" else "activated")
					"shop":
						return result(true, "shop", {"shop": target.shop})
					"npc":
						var candidates: Array = []
						for event_id in content.events:
							var event: Dictionary = content.events[event_id]
							if event.character == target.character and event_id not in state.completed and route_allows(event_id) and satisfied(event.conditions):
								candidates.append(event_id)
						candidates.sort_custom(func(a, b):
							var pa = content.events[a].get("priority", 0)
							var pb = content.events[b].get("priority", 0)
							return pa > pb if pa != pb else a < b)
						if candidates.is_empty():
							return result(true, "smalltalk", {"character": target.character})
						active_event = candidates[0]
						return result(true, "event", {"event": active_event})
			return result(false, "unknown_target")
		"buy":
			var shop_id := str(command.get("shop", ""))
			var item_id := str(command.get("item", ""))
			var reachable := false
			for target in content.maps[state.map].objects:
				if target.kind == "shop" and target.shop == shop_id and adjacent(target.position) and target_visible(target):
					reachable = true
			if not reachable:
				return result(false, "shop_unreachable")
			var offer: Dictionary = content.shops.get(shop_id, {}).get(item_id, {})
			if offer.is_empty():
				return result(false, "unknown_offer")
			var stock_key := shop_id + ":" + item_id
			if state.stock.get(stock_key, 0) <= 0:
				return result(false, "out_of_stock")
			if state.money < offer.price:
				return result(false, "insufficient_money")
			state.money -= offer.price
			state.stock[stock_key] -= 1
			state.inventory[item_id] = state.inventory.get(item_id, 0) + 1
			return result(true, "purchased")
		"choose":
			if active_event == "":
				return result(false, "no_event")
			var event: Dictionary = content.events[active_event]
			for choice in event.choices:
				if choice.id == command.get("choice", ""):
					if not satisfied(choice.get("conditions", [])):
						return result(false, "choice_locked")
					if choice.get("cancel", false):
						active_event = ""
						return result(true, "cancelled")
					if not satisfied(event.conditions) or not apply_effects(choice.get("effects", []) + event.get("effects", [])):
						return result(false, "effect_failed")
					var finished := active_event
					state.completed.append(finished)
					advance_time(int(event.get("time_cost", 0)))
					active_event = ""
					return result(true, "event_completed", {"event": finished})
			return result(false, "unknown_choice")
	return result(false, "unknown_operation")

func apply_effects(effects: Array) -> bool:
	var previous := state.duplicate(true)
	for effect in effects:
		match effect.kind:
			"money": state.money += effect.value
			"item": state.inventory[effect.id] = state.inventory.get(effect.id, 0) + effect.value
			"affection": state.characters[effect.id].affection += effect.value
			"stage": state.characters[effect.id].stage = effect.value
			"flag": state.flags[effect.id] = effect.value
			_:
				state = previous
				return false
	if state.money < 0:
		state = previous
		return false
	for count in state.inventory.values():
		if count < 0:
			state = previous
			return false
	return true

func save_game(path: String) -> bool:
	if active_event != "":
		return false
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"game_id": content.id, "version": 1, "content_version": content.version, "saved_at": Time.get_unix_time_from_system(), "state": state}))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return false
	return DirAccess.rename_absolute(path + ".tmp", path) == OK

func read_save(path: String) -> Dictionary:
	## Validates without changing live state; also used by the slot browser.
	if not FileAccess.file_exists(path):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("game_id") != content.id or data.get("version") != 1 or not data.get("state") is Dictionary:
		return {}
	var candidate: Dictionary = data.state
	for key in content.initial:
		if not candidate.has(key) or typeof(candidate[key]) != typeof(content.initial[key]):
			return {}
	if not content.maps.has(candidate.map) or candidate.period not in PERIODS or candidate.day < 1 or candidate.money < 0:
		return {}
	if candidate.position.size() != 2:
		return {}
	for coordinate in candidate.position:
		if not (coordinate is float or coordinate is int) or coordinate != floor(coordinate):
			return {}
	var area: Dictionary = content.maps[candidate.map]
	if candidate.position[0] < 0 or candidate.position[1] < 0 or candidate.position[0] >= area.width or candidate.position[1] >= area.height:
		return {}
	# Visual-layout v4 repositions world furniture; retain progress at the map entrance.
	var reposition_before := int(content.get("save_migration", {}).get("reposition_before_version", 0))
	if int(data.get("content_version", 0)) < reposition_before:
		candidate.position = area.spawns.entry.duplicate()
	for wall in area.walls:
		if wall == candidate.position:
			return {}
	for character in content.characters:
		if not candidate.characters.has(character) or not candidate.characters[character] is Dictionary:
			return {}
		if not candidate.characters[character].has_all(["stage", "affection"]):
			return {}
		for field in ["stage", "affection"]:
			var value = candidate.characters[character][field]
			if not (value is float or value is int) or value < 0 or value != floor(value):
				return {}
	for inventory in [candidate.inventory, candidate.stock]:
		for value in inventory.values():
			if not (value is float or value is int) or value < 0 or value != floor(value):
				return {}
	for event in candidate.completed:
		if not content.events.has(event): return {}
	return data

func load_game(path: String) -> bool:
	if active_event != "": return false
	var data := read_save(path)
	if data.is_empty(): return false
	state = data.state.duplicate(true)
	active_event = ""
	return true
