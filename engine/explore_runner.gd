extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2: quit(2); return
	var request = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var core = preload("res://engine/core.gd").new()
	if not core.load_content(request.content): quit(2); return
	core.new_game()
	var report: Dictionary = preload("res://engine/reachability.gd").new().search(core,request.limits)
	var file := FileAccess.open(args[1],FileAccess.WRITE)
	if file == null: quit(2); return
	file.store_string(JSON.stringify(report))
	file.close()
	quit(0)
