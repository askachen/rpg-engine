extends RefCounted
## Profile persistence is independent of UI, world state and content loading.
static func read(path: String, language: String) -> Dictionary:
	var result := {"unlocked": [], "read_lines": [], "language": language, "volume": 0.8, "dash": true}
	if not FileAccess.file_exists(path): return result
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary: return result
	for key in ["unlocked", "read_lines"]:
		if parsed.get(key) is Array:
			for value in parsed[key]:
				if value is String and value not in result[key]: result[key].append(value)
	if parsed.get("language") is String: result.language = parsed.language
	if parsed.get("dash") is bool: result.dash = parsed.dash
	if parsed.get("volume") is float or parsed.get("volume") is int:
		result.volume = clampf(float(parsed.volume), 0.0, 1.0)
	return result

static func write(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var error := file.get_error()
	file.close()
	return error == OK and DirAccess.rename_absolute(path + ".tmp", path) == OK
