class_name StoryCore
extends RefCounted
## The authoritative game rules. Both the GUI and headless runner call act().

var content: Dictionary = {}
var state: Dictionary = {}
var active_event := ""
var active_node := ""
var pending_effects: Array = []
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
	clear_event()
	history.clear()

func clear_event() -> void:
	active_event = ""
	active_node = ""
	pending_effects.clear()

func event_view() -> Dictionary:
	if active_event == "": return {}
	var view: Dictionary = content.events[active_event].duplicate(true)
	if active_node != "":
		var node: Dictionary = view.nodes[active_node]
		view.sequence = node.get("sequence", []).duplicate(true)
		view.choices = node.choices.duplicate(true)
	return view

func event_candidates(who: String) -> Array:
	var candidates: Array = []
	for id in content.events:
		var event: Dictionary = content.events[id]
		if event.character != who: continue
		var reason := "eligible"
		if id in state.completed and not event.get("repeatable", false): reason = "completed"
		elif not route_allows(id): reason = "route_order"
		elif not satisfied(event.conditions): reason = "conditions"
		candidates.append({"id": id, "priority": event.get("priority", 0), "eligible": reason == "eligible", "reason": reason, "checks": checks(event.conditions), "selected": false})
	candidates.sort_custom(func(a, b): return a.priority > b.priority if a.priority != b.priority else a.id < b.id)
	var selected := false
	for candidate in candidates:
		if candidate.eligible:
			candidate.selected = not selected
			candidate.reason = "selected" if not selected else "lower_rank"
			selected = true
	return candidates

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

func map_objects(map_id: String = "") -> Array:
	## One resolved view for rendering, picking, navigation and gameplay. Content stays immutable.
	if map_id == "": map_id = state.map
	var output: Array = []
	for source_map in content.maps:
		for original in content.maps[source_map].objects:
			if not satisfied(original.get("visible_when", [])): continue
			var target: Dictionary = original
			var location: String = source_map
			if original.has("schedule"):
				location = ""
				for placement in original.schedule:
					if satisfied(placement.conditions):
						location = placement.map
						target = original.duplicate(true)
						target.position = placement.position.duplicate()
						break
			if location == map_id: output.append(target)
	return output

func object_removed(target: Dictionary) -> bool:
	return target.kind in ["pickup", "switch"] and state.objects.get(target.id, false)

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
	for target in map_objects():
		if Vector2i(int(target.position[0]), int(target.position[1])) == pos and target.get("solid", true) and target_visible(target) and not object_removed(target):
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
	var event_before := active_event
	var response := _act(command)
	# A schedule/flag change must never place a solid actor on the player.
	if response.ok and command.get("op") != "move" and not walkable(Vector2i(int(state.position[0]), int(state.position[1]))):
		state = before.duplicate(true)
		# Return to exploration if committing a choice would trap the player.
		# The event remains uncompleted and can be started again after moving.
		if command.get("op") == "choose": clear_event()
		else: active_event = event_before
		response = result(false, "world_blocked")
	history.append({"command": command.duplicate(true), "result": response.duplicate(true), "before": before, "after": state.duplicate(true)})
	return response

func _act(command: Dictionary) -> Dictionary:
	var op := str(command.get("op", ""))
	if active_event != "" and op not in ["choose", "cancel_event"]:
		return result(false, "event_busy")
	match op:
		"cancel_event":
			if active_event == "": return result(false, "no_event")
			clear_event()
			return result(true, "cancelled")
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
			for target in map_objects():
				if target.id != command.get("target", ""):
					continue
				if not adjacent(target.position):
					return result(false, "too_far")
				if not target_visible(target):
					return result(false, "unavailable", {"checks": checks(target.get("conditions", []))})
				match target.kind:
					"inspect":
						if state.objects.get(target.id, false) and not target.get("repeatable", false):
							return result(true, "inspected", {"text": target.text})
						var effects: Array = target.get("effects", []).duplicate(true)
						if target.has("required_item"):
							var requirement: Dictionary = target.required_item
							if command.get("item", "") != requirement.id or state.inventory.get(requirement.id, 0) < requirement.count:
								return result(false, "item_required", {"target": target.id, "requirement": requirement})
							if requirement.consume: effects.push_front({"kind": "item", "id": requirement.id, "value": -requirement.count})
						if not apply_effects(effects): return result(false, "effect_failed")
						state.objects[target.id] = true
						return result(true, "inspected", {"text": target.text})
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
						var candidates := event_candidates(target.character)
						for candidate in candidates:
							if candidate.selected:
								clear_event()
								active_event = candidate.id
								return result(true, "event", {"event": active_event, "candidates": candidates})
						return result(true, "smalltalk", {"character": target.character, "candidates": candidates})
			return result(false, "unknown_target")
		"buy":
			var shop_id := str(command.get("shop", ""))
			var item_id := str(command.get("item", ""))
			var reachable := false
			for target in map_objects():
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
			for choice in event_view().choices:
				if choice.id == command.get("choice", ""):
					if not satisfied(choice.get("conditions", [])):
						return result(false, "choice_locked")
					if choice.get("cancel", false):
						clear_event()
						return result(true, "cancelled")
					if not satisfied(event.conditions): return result(false, "effect_failed")
					if choice.has("next"):
						pending_effects.append_array(choice.get("effects", []).duplicate(true))
						active_node = choice.next
						return result(true, "event_branch", {"event": active_event, "node": active_node})
					if not apply_effects(pending_effects + choice.get("effects", []) + event.get("effects", [])):
						return result(false, "effect_failed")
					var finished := active_event
					if finished not in state.completed: state.completed.append(finished)
					advance_time(int(event.get("time_cost", 0)))
					clear_event()
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
	clear_event()
	return true
