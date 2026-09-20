extends RefCounted
## Runtime counterpart of tools/content_loader.py. No gameplay implementation.
var error := ""
var origins: Dictionary = {}
const COLLECTIONS = ["maps", "characters", "events", "items", "shops", "routes", "endings", "gallery", "locales", "avatars", "visuals", "stats", "variables"]

func read_object(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		error = path + ": file not found"
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		error = "%s:%d: %s" % [path, parser.get_error_line(), parser.get_error_message()]
		return {}
	if not parser.data is Dictionary:
		error = path + ": expected JSON object"
		return {}
	return parser.data

func load_game(path: String) -> Dictionary:
	error = ""
	origins.clear()
	var data := read_object(path)
	if error != "" or not data.has("sources"): return data
	if data.get("format_version") != 1:
		error = path + "/format_version: expected 1"
		return {}
	var sources = data.sources
	if not sources is Dictionary:
		error = path + "/sources: expected object"
		return {}
	data.erase("sources")
	data.erase("format_version")
	for section in sources:
		if section not in COLLECTIONS or not sources[section] is Array:
			error = path + "/sources/" + section + ": unknown collection or invalid file list"
			return {}
		if not data.has(section): data[section] = {}
		if not data[section] is Dictionary:
			error = path + "/" + section + ": expected object"
			return {}
		var owners: Dictionary = {}
		for key in data[section]: owners[key] = path
		for relative in sources[section]:
			if not relative is String or relative.is_empty() or relative.is_absolute_path() or ":" in relative or "\\" in relative or ".." in relative.split("/"):
				error = path + "/sources/" + section + ": expected relative path inside content directory"
				return {}
			var target: String = path.get_base_dir().path_join(relative)
			var fragment := read_object(target)
			if error != "": return {}
			for key in fragment:
				if data[section].has(key):
					error = "%s/%s/%s: duplicate ID; first defined in %s" % [target, section, key, owners[key]]
					return {}
				data[section][key] = fragment[key]
				origins[section+"/"+str(key)] = target
				owners[key] = target
	return data
