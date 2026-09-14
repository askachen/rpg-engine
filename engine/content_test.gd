extends SceneTree
## Serialize composed content to compare Python tooling with the runtime loader.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var loader = load("res://engine/content_loader.gd").new()
	var data: Dictionary = loader.load_game(args[0])
	var output := FileAccess.open(args[1], FileAccess.WRITE)
	output.store_string(JSON.stringify({"data": data, "error": loader.error}))
	output.close()
	quit(0)
