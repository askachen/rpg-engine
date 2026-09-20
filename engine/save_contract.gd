extends RefCounted
## Pure candidate validation/migration. Never mutates the running core or files.
const VERSION := 2
var error := ""

func reject(code: String) -> Dictionary:
	error = code
	return {}

func integer(value, minimum: int = 0) -> bool:
	return (value is int or value is float) and is_finite(value) and value == floor(value) and value >= minimum and value <= 9007199254740991

func read(core, path: String) -> Dictionary:
	error = ""
	if not FileAccess.file_exists(path): return reject("missing_file")
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK: return reject("invalid_json")
	if parser.data is Dictionary and parser.data.get("version") == 1 and not parser.data.has("saved_at"):
		parser.data.saved_at = FileAccess.get_modified_time(path)
	return validate(core,parser.data)

func validate(core, value) -> Dictionary:
	error = ""
	if not value is Dictionary: return reject("invalid_envelope")
	var data: Dictionary = value.duplicate(true)
	if data.get("game_id") != core.content.id: return reject("wrong_game")
	if not integer(data.get("version"),1) or int(data.version) not in [1,VERSION]: return reject("unsupported_save_version")
	if data.version == 1:
		if not data.has("content_version"): data.content_version = 1
		if not data.has("saved_at"): data.saved_at = 1
	if not integer(data.get("content_version"),1): return reject("invalid_content_version")
	if data.content_version > core.content.version: return reject("future_content_version")
	if not data.get("state") is Dictionary: return reject("invalid_state")
	if data.has("developer") and not data.developer is bool: return reject("invalid_metadata")
	if data.has("saved_at") and (not (data.saved_at is int or data.saved_at is float) or not is_finite(data.saved_at) or data.saved_at <= 0): return reject("invalid_metadata")
	if data.version == VERSION:
		if not data.get("developer") is bool or not (data.get("saved_at") is float or data.get("saved_at") is int) or not is_finite(data.saved_at) or data.saved_at <= 0: return reject("invalid_metadata")
		for key in data:
			if key not in ["game_id","version","content_version","saved_at","state","developer"]: return reject("unknown_envelope_field:"+str(key))
	var reposition: int = int(core.content.get("save_migration",{}).get("reposition_before_version",0))
	var legacy_reposition: bool = data.content_version < reposition
	while data.content_version < core.content.version:
		var migration: Dictionary = {}
		for entry in core.content.get("save_migrations",[]):
			if entry.from_version == data.content_version: migration = entry; break
		if migration.is_empty():
			if legacy_reposition:
				data.content_version = core.content.version
				break
			return reject("missing_content_migration:"+str(data.content_version))
		if migration.to_version <= data.content_version or migration.to_version > core.content.version: return reject("invalid_migration")
		for group in migration.get("renames",{}):
			if group not in ["stats","variables","inventory"] or not data.state.get(group,{}) is Dictionary: return reject("invalid_migration_group")
			for old_id in migration.renames[group]:
				var new_id: String = migration.renames[group][old_id]
				if data.state.get(group,{}).has(old_id):
					if data.state[group].has(new_id): return reject("migration_collision")
					data.state[group][new_id] = data.state[group][old_id]
					data.state[group].erase(old_id)
				if group == "inventory" and data.state.get("stock") is Dictionary:
					for stock_id in data.state.stock.keys():
						if str(stock_id).ends_with(":"+old_id):
							var replacement: String = str(stock_id).trim_suffix(old_id)+new_id
							if data.state.stock.has(replacement): return reject("migration_collision")
							data.state.stock[replacement] = data.state.stock[stock_id]
							data.state.stock.erase(stock_id)
		data.content_version = migration.to_version
	var state: Dictionary = data.state
	for key in ["map","position","day","period","money","inventory","characters","completed","flags","objects","stock"]:
		if not state.has(key): return reject("missing_state_field:"+key)
	for key in state:
		if key not in ["map","position","day","period","money","inventory","characters","completed","flags","objects","stock","stats","variables","actions"]: return reject("unknown_state_field:"+str(key))
	if not state.map is String or not core.content.maps.has(state.map): return reject("unknown_map")
	if not state.period is String or state.period not in core.PERIODS or not integer(state.day,1) or not integer(state.money): return reject("invalid_time_or_money")
	for key in ["inventory","characters","flags","objects","stock"]:
		if not state[key] is Dictionary: return reject("invalid_container:"+key)
	if not state.position is Array or state.position.size() != 2 or not integer(state.position[0]) or not integer(state.position[1]): return reject("invalid_position")
	var area: Dictionary = core.content.maps[state.map]
	if state.position[0] >= area.width or state.position[1] >= area.height: return reject("invalid_position")
	if not state.completed is Array: return reject("invalid_completed")
	var seen := {}
	for id in state.completed:
		if not id is String or not core.content.events.has(id) or seen.has(id): return reject("invalid_completed_id")
		seen[id] = true
	if state.characters.size() != core.content.characters.size(): return reject("invalid_characters")
	for id in core.content.characters:
		var character = state.characters.get(id)
		if not character is Dictionary or character.size() != 2 or not integer(character.get("stage")) or not integer(character.get("affection")): return reject("invalid_character:"+id)
	for id in state.inventory:
		if not core.content.items.has(id) or not integer(state.inventory[id]): return reject("invalid_inventory:"+str(id))
	var stock_ids := {}
	for shop in core.content.shops:
		for item in core.content.shops[shop]: stock_ids[shop+":"+item] = true
	for id in state.stock:
		if not stock_ids.has(id) or not integer(state.stock[id]): return reject("invalid_stock:"+str(id))
	var object_ids := {}
	for map in core.content.maps.values():
		for target in map.objects: object_ids[target.id] = true
	for id in state.objects:
		if not object_ids.has(id) or not state.objects[id] is bool: return reject("invalid_object:"+str(id))
	var known_flags: Dictionary = core.content.initial.flags.duplicate()
	collect_flags(core.content,known_flags)
	for id in state.flags:
		if not id is String or not known_flags.has(id) or not state.flags[id] is bool: return reject("invalid_flag:"+str(id))
	if not core.numbers.normalize(state,core.content): return reject("invalid_numbers")
	if not core.valid_actions(state) or not core.valid_stock(state): return reject("invalid_actions_or_stock")
	if legacy_reposition: state.position = core.content.maps[state.map].spawns.entry.duplicate()
	var probe = core.get_script().new()
	probe.content = core.content
	probe.state = state
	if not probe.walkable(Vector2i(int(state.position[0]),int(state.position[1]))): return reject("blocked_position")
	data.version = VERSION
	data.developer = data.get("developer",false)
	return data


func collect_flags(node, output: Dictionary) -> void:
	if node is Dictionary:
		if node.get("kind") == "flag" and node.get("id") is String: output[node.id] = true
		for child in node.values(): collect_flags(child,output)
	elif node is Array:
		for child in node: collect_flags(child,output)
