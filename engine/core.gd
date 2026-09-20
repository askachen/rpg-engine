class_name StoryCore
extends RefCounted
## The authoritative game rules. Both the GUI and headless runner call act().

var content: Dictionary = {}
var state: Dictionary = {}
var active_event := ""
var active_node := ""
var pending_effects: Array = []
var event_context: Dictionary = {}
var history: Array = []
var load_error := ""
var replay_mode := false
const PERIODS = ["day", "evening", "late"]
var numbers = preload("res://engine/numeric_state.gd").new()

func load_content(path: String) -> bool:
	var loader = preload("res://engine/content_loader.gd").new()
	var parsed: Dictionary = loader.load_game(path)
	if loader.error != "":
		load_error = loader.error
		return false
	if not preload("res://engine/game_bootstrap.gd").valid_id(str(parsed.get("id", ""))):
		load_error = "Invalid game ID; expected 1-64 letters, digits, underscores or hyphens."
		return false
	load_error = numbers.definitions_error(parsed)
	if load_error != "": return false
	var initial: Dictionary = parsed.initial.duplicate(true)
	if not numbers.normalize(initial, parsed):
		load_error = "initial: invalid numeric state"
		return false
	content = parsed
	new_game(false)
	return true

func new_game(play_opening: bool = true) -> void:
	if replay_mode: return
	state = content.get("initial", {}).duplicate(true)
	numbers.normalize(state, content)
	if records_enabled(): state["actions"] = []
	clear_event()
	history.clear()
	if play_opening and content.has("opening_event"):
		start_event(content.opening_event, {"source":"opening"})

func clear_event() -> void:
	active_event = ""
	active_node = ""
	pending_effects.clear()
	event_context.clear()

func event_view() -> Dictionary:
	if active_event == "": return {}
	var view: Dictionary = content.events[active_event].duplicate(true)
	if active_node != "":
		var node: Dictionary = view.nodes[active_node]
		view.sequence = node.get("sequence", []).duplicate(true)
		view.choices = node.choices.duplicate(true)
	return view

func event_candidates(who: String, context: Dictionary = {}) -> Array:
	var candidates: Array = []
	for id in content.events:
		var event: Dictionary = content.events[id]
		if id == content.get("opening_event", ""): continue
		if event.get("character", "") != who: continue
		var reason := "eligible"
		if id in state.completed and not event.get("repeatable", false): reason = "completed"
		elif not route_allows(id): reason = "route_order"
		elif not satisfied(event.conditions, context): reason = "conditions"
		candidates.append({"id": id, "priority": event.get("priority", 0), "eligible": reason == "eligible", "reason": reason, "checks": checks(event.conditions, context), "selected": false})
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

func checks(conditions: Array, context: Dictionary = {}, depth: int = 0) -> Array:
	var output: Array = []
	for condition in conditions:
		if condition.get("kind") in ["all", "any"]:
			var children: Array = checks(condition.conditions, context, depth + 1) if depth < 8 else []
			var matches := 0
			for child in children:
				if child.passed: matches += 1
			output.append({"condition":condition,"children":children,"actual":matches,"expected":children.size(),"passed":not children.is_empty() and (matches == children.size() if condition.kind == "all" else matches > 0)})
			continue
		var actual = null
		var expected = condition.get("value", true)
		var passed := false
		match condition.get("kind", ""):
			"action_count":
				actual = action_count(condition)
				passed = numbers.compare(actual, expected, condition.op, {"type":"integer","min":0})
			"day":
				actual = state.day
				passed = numbers.compare(actual, expected, condition.get("op", ""), {"type":"integer","min":1})
			"map":
				actual = state.map
				expected = condition.id
				passed = actual == expected
			"target":
				actual = context.get("target")
				expected = condition.id
				passed = actual != null and actual == expected
			"zone":
				actual = []
				expected = condition.id
				if state.map == condition.map:
					for zone in content.maps[state.map].get("zones", []):
						if zone.has("id") and Rect2(zone.rect[0], zone.rect[1], zone.rect[2], zone.rect[3]).has_point(Vector2(state.position[0], state.position[1])): actual.append(zone.id)
				passed = expected in actual
			"stat", "variable":
				var group := "stats" if condition.kind == "stat" else "variables"
				var id: String = condition.get("id", "")
				actual = state.get(group, {}).get(id)
				passed = numbers.compare(actual, expected, condition.get("op", ""), content.get(group, {}).get(id, {}))
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

func satisfied(conditions: Array, context: Dictionary = {}) -> bool:
	for check in checks(conditions, context):
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
	var previous_day: int = int(state.day)
	var total := PERIODS.find(state.period) + amount
	state.day += int(total / 3)
	state.period = PERIODS[total % 3]
	if state.day > previous_day:
		for shop in content.shops:
			for item in content.shops[shop]:
				var offer: Dictionary = content.shops[shop][item]
				if offer.get("restock") == "daily": state.stock[shop+":"+item] = offer.capacity

func adjacent(position: Array) -> bool:
	return abs(int(position[0]) - int(state.position[0])) + abs(int(position[1]) - int(state.position[1])) <= 1

func target_visible(target: Dictionary) -> bool:
	return satisfied(target.get("conditions", []), {"target":target.id})

func context_for_event(id: String) -> Dictionary:
	var event: Dictionary = content.events[id]
	for target in map_objects():
		if not adjacent(target.position) or not target_visible(target): continue
		if target.get("event") == id or (target.kind == "npc" and target.character == event.get("character", "")):
			return {"target":target.id}
	return {}

func start_event(id: String, context: Dictionary, entry_effects: Array = []) -> Dictionary:
	if replay_mode: return result(false, "replay_read_only")
	if active_event != "": return result(false, "event_busy")
	if not content.events.has(id): return result(false, "unknown_event")
	if id == content.get("opening_event", "") and context.get("source") != "opening": return result(false, "unavailable")
	var event: Dictionary = content.events[id]
	if (id in state.completed and not event.get("repeatable", false)) or not route_allows(id) or not satisfied(event.conditions, context):
		return result(false, "unavailable", {"checks":checks(event.conditions, context)})
	clear_event()
	active_event = id
	event_context = context.duplicate(true)
	if not event_context_valid():
		clear_event()
		return result(false, "unavailable")
	pending_effects = entry_effects.duplicate(true)
	return result(true, "event", {"event":id})

func event_context_valid() -> bool:
	if not event_context.has("target"): return true
	for target in map_objects():
		if target.id == event_context.target:
			if not adjacent(target.position) or not target_visible(target): return false
			if target.has("required_item"):
				if state.inventory.get(target.required_item.id, 0) < target.required_item.count: return false
			return true
	return false

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

func shop_offer(shop_id: String, item_id: String) -> Dictionary:
	var offer: Dictionary = content.shops.get(shop_id, {}).get(item_id, {})
	var stock := int(state.stock.get(shop_id+":"+item_id,0))
	var reason := ""
	var reachable := false
	for target in map_objects():
		if target.kind == "shop" and target.shop == shop_id and adjacent(target.position) and target_visible(target): reachable = true
	if not reachable: reason = "shop_unreachable"
	elif offer.is_empty(): reason = "unknown_offer"
	elif not offer.get("unlimited", false) and stock <= 0: reason = "out_of_stock"
	elif state.money < offer.price: reason = "insufficient_money"
	return {"available":reason == "", "reason":reason, "price":offer.get("price",0), "stock":stock, "unlimited":offer.get("unlimited",false), "owned":state.inventory.get(item_id,0)}

func act(command: Dictionary) -> Dictionary:
	var before := state.duplicate(true)
	var event_before := active_event
	var response := _act(command)
	# A schedule/flag change must never place a solid actor on the player.
	if not replay_mode and response.ok and command.get("op") != "move" and not walkable(Vector2i(int(state.position[0]), int(state.position[1]))):
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
	if replay_mode and op not in ["choose", "cancel_event"]: return result(false, "replay_read_only")
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
						if target.has("event"):
							return start_event(target.event, {"source":"object","target":target.id}, effects)
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
						var context := {"source":"npc", "target":target.id}
						var candidates := event_candidates(target.character, context)
						for candidate in candidates:
							if candidate.selected:
								var response := start_event(candidate.id, context)
								response.candidates = candidates
								return response
						return result(true, "smalltalk", {"character": target.character, "candidates": candidates})
			return result(false, "unknown_target")
		"buy":
			var shop_id := str(command.get("shop", ""))
			var item_id := str(command.get("item", ""))
			var offer := shop_offer(shop_id,item_id)
			if not offer.available: return result(false,offer.reason)
			var stock_key := shop_id + ":" + item_id
			state.money -= offer.price
			if not offer.unlimited: state.stock[stock_key] -= 1
			state.inventory[item_id] = state.inventory.get(item_id, 0) + 1
			return result(true, "purchased")
		"choose":
			if active_event == "":
				return result(false, "no_event")
			var event: Dictionary = content.events[active_event]
			for choice in event_view().choices:
				if choice.id == command.get("choice", ""):
					if not replay_mode and not satisfied(choice.get("conditions", []), event_context):
						return result(false, "choice_locked")
					if choice.get("cancel", false):
						clear_event()
						return result(true, "cancelled")
					if not replay_mode and (not event_context_valid() or not satisfied(event.conditions, event_context)): return result(false, "effect_failed")
					if choice.has("next"):
						pending_effects.append_array(choice.get("effects", []).duplicate(true))
						active_node = choice.next
						return result(true, "event_branch", {"event": active_event, "node": active_node})
					if replay_mode:
						var replayed := active_event
						clear_event()
						return result(true, "event_completed", {"event":replayed})
					if not apply_effects(pending_effects + choice.get("effects", []) + event.get("effects", [])):
						return result(false, "effect_failed")
					var finished := active_event
					if event_context.get("source") == "object": state.objects[event_context.target] = true
					if finished not in state.completed: state.completed.append(finished)
					if event.has("action_tags"):
						if not state.has("actions"): state.actions = []
						state.actions.append({"event":finished,"tags":event.action_tags.duplicate(),"day":state.day,"period":state.period})
					advance_time(int(event.get("time_cost", 0)))
					clear_event()
					return result(true, "event_completed", {"event": finished})
			return result(false, "unknown_choice")
	return result(false, "unknown_operation")

func apply_effects(effects: Array) -> bool:
	if replay_mode: return false
	var previous := state.duplicate(true)
	for effect in effects:
		match effect.kind:
			"stat", "variable":
				if not numbers.apply(state, content, effect):
					state = previous
					return false
			"stock":
				var offer: Dictionary = content.shops.get(effect.shop, {}).get(effect.id, {})
				var key: String = effect.shop + ":" + effect.id
				var value: float = effect.value + (state.stock.get(key, 0) if effect.op == "add" else 0)
				if offer.is_empty() or offer.get("unlimited", false) or not numbers.valid_value(value, {"type":"integer","min":0,"max":offer.get("capacity",numbers.LIMIT)}):
					state = previous
					return false
				state.stock[key] = int(value)
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
	if replay_mode or active_event != "":
		return false
	var checked := state.duplicate(true)
	if not numbers.normalize(checked, content) or not valid_actions(checked) or not valid_stock(checked): return false
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
	if not numbers.normalize(candidate, content): return {}
	for key in content.initial:
		if key in numbers.GROUPS: continue
		if not candidate.has(key) or typeof(candidate[key]) != typeof(content.initial[key]):
			return {}
	if not content.maps.has(candidate.map) or candidate.period not in PERIODS or candidate.day < 1 or candidate.money < 0:
		return {}
	if not numbers.valid_value(candidate.day, {"type":"integer","min":1}) or not valid_actions(candidate) or not valid_stock(candidate): return {}
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
	if replay_mode or active_event != "": return false
	var data := read_save(path)
	if data.is_empty(): return false
	state = data.state.duplicate(true)
	clear_event()
	return true

func records_enabled() -> bool:
	for event in content.events.values():
		if event.has("action_tags"): return true
	return false

func action_count(condition: Dictionary) -> int:
	var count := 0
	var window: Dictionary = condition.get("window", {})
	var now: int = int(state.day) if window.get("unit") == "days" else (int(state.day)-1)*3+PERIODS.find(state.period)
	var end: int = now - (0 if window.get("include_current", true) else 1)
	for record in state.get("actions", []):
		var point: int = int(record.day) if window.get("unit") == "days" else (int(record.day)-1)*3+PERIODS.find(record.period)
		if not window.is_empty() and (point > end or point <= end-int(window.size)): continue
		for tag in condition.tags:
			if tag in record.tags:
				count += 1
				break
	return count

func valid_actions(candidate: Dictionary) -> bool:
	if not candidate.has("actions"):
		if records_enabled(): candidate.actions = []
		return true
	if not candidate.actions is Array: return false
	var previous := -1
	for record in candidate.actions:
		if not record is Dictionary or not record.has_all(["event","tags","day","period"]): return false
		if not content.events.has(record.event) or not record.tags is Array or record.tags.is_empty(): return false
		if not numbers.valid_value(record.day, {"type":"integer","min":1}) or record.period not in PERIODS: return false
		var point: int = (int(record.day)-1)*3+PERIODS.find(record.period)
		if point < previous or point > (int(candidate.day)-1)*3+PERIODS.find(candidate.period): return false
		previous = point
		var unique := {}
		for tag in record.tags:
			if not tag is String or tag not in content.events[record.event].get("action_tags", []) or unique.has(tag): return false
			unique[tag] = true
	return true

func format_day(day: int, language: String = "zh_TW") -> String:
	var config: Dictionary = content.get("date_display", {})
	if config.is_empty(): return "DAY %02d" % day
	var extra: bool = day > config.normal_days
	return tr_key(config.extra_text if extra else config.normal_text, language).replace("{day}", str(day-int(config.normal_days) if extra else day))

func event_available(id: String, context: Dictionary = {}) -> bool:
	var event: Dictionary = content.events[id]
	return (id not in state.completed or event.get("repeatable",false)) and route_allows(id) and satisfied(event.conditions,context)

func target_event_available(target: Dictionary) -> bool:
	if not target_visible(target): return false
	if target.has("required_item") and state.inventory.get(target.required_item.id,0) < target.required_item.count: return false
	var context := {"target":target.id}
	if target.kind == "npc":
		for candidate in event_candidates(target.character,context):
			if candidate.selected: return true
	elif target.kind == "inspect" and target.has("event"):
		if state.objects.get(target.id,false) and not target.get("repeatable",false): return false
		return event_available(target.event,context)
	return false

func replay_session(card_id: String, unlocked: Array):
	var card: Dictionary = content.get("gallery",{}).get(card_id,{})
	if card_id not in unlocked or not card.has("event") or not content.events.has(card.event): return null
	var session = get_script().new()
	session.content = content.duplicate(true)
	session.state = state.duplicate(true)
	session.replay_mode = true
	session.active_event = card.event
	return session

func valid_stock(candidate: Dictionary) -> bool:
	for shop in content.shops:
		for item in content.shops[shop]:
			var offer: Dictionary = content.shops[shop][item]
			var count = candidate.stock.get(shop+":"+item,0)
			if not numbers.valid_value(count,{"type":"integer","min":0,"max":offer.get("capacity",numbers.LIMIT)}): return false
	return true
