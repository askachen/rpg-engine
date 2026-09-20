extends RefCounted
## The project supplies the default; --game=path selects content for development.
static func content_path() -> String:
	if OS.has_feature("editor"):
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--game="):
				return argument.trim_prefix("--game=")
	return str(ProjectSettings.get_setting("story_engine/content_path", ""))

static func valid_id(value: String) -> bool:
	var pattern := RegEx.new()
	pattern.compile("^[a-zA-Z0-9][a-zA-Z0-9_-]{0,63}$")
	return pattern.search(value) != null

static func profile_path(game_id: String) -> String:
	return "user://" + game_id + "_profile.json"
