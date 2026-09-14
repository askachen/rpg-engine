extends SceneTree
## Native resource compatibility check, not a full playback or glyph-coverage test.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var loader = load("res://engine/content_loader.gd").new()
	var data: Dictionary = loader.load_game(args[0])
	var errors: Array = []
	if loader.error != "": errors.append(loader.error)
	for path in data.get("assets", []):
		var extension: String = str(path).get_extension().to_lower()
		if extension in ["png", "jpg", "jpeg", "webp", "svg"]:
			var decoded := Image.new()
			if decoded.load(path) != OK or decoded.is_empty(): errors.append(path + ": Godot image decode failed")
		elif extension in ["wav", "ogg", "mp3"]:
			var stream = load(path)
			if not stream is AudioStream or stream.get_length() <= 0:
				errors.append(path + ": invalid audio resource or duration")
		elif extension in ["ttf", "otf", "tres"]:
			if not load(path) is Font: errors.append(path + ": expected Font resource")
		else:
			errors.append(path + ": native probe does not support this asset type yet")
	var output := FileAccess.open(args[1], FileAccess.WRITE)
	output.store_string(JSON.stringify({"errors": errors, "checked": data.get("assets", []).size()}))
	output.close()
	quit(0 if errors.is_empty() else 1)
