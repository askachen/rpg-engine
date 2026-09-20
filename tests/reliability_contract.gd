extends "res://tests/world_objects.gd"

func write(path: String, data) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(data) if data is Dictionary else str(data))
	file.close()

func _initialize() -> void:
	check(core.load_content("res://games/numeric_lab/game.json"),"Load fixture")
	var command := {"op":"debug","action":"set","group":"stats","id":"INT","value":1}
	check(core.act(command).message == "developer_disabled","Mutations opt in")
	core.developer_enabled = true
	if OS.get_cmdline_user_args().has("--release"):
		check(core.act(command).message == "developer_disabled" and not core.developer_used,"Release simulation hard-disables mutation")
		print(JSON.stringify({"reliability_failures":failures})); quit(0 if failures.is_empty() else 1); return
	check(core.act(command).ok and core.developer_used,"Developer change marked")
	check(core.history[-1].diff[0].path == "/stats/INT","Path-level state diff")
	check(core.act({"op":"debug","action":"teleport","map":"room","spawn":"entry"}).ok,"Validated developer teleport")
	check(core.save_game("user://dev.json"),"Developer save")
	check(core.read_save("user://dev.json").developer,"Persistent developer marker")
	core.new_game(false)
	check(not core.developer_used,"New game resets marker")
	check(core.save_game("user://valid.json"),"Valid schema v2 save")
	var saved: Dictionary = core.read_save("user://valid.json")
	var before: Dictionary = core.state.duplicate(true)
	for defect in ["money","day","position","character","inventory","flag","object","completed","action","unknown","metadata","version","future"]:
		var broken := saved.duplicate(true)
		match defect:
			"money": broken.state.money = true
			"day": broken.state.day = 1.5
			"position": broken.state.position = "2,3"
			"character": broken.state.characters.guide.stage = false
			"inventory": broken.state.inventory.unknown = 1
			"flag": broken.state.flags.bad = 1
			"object": broken.state.objects.unknown = true
			"completed": broken.state.completed = ["opening","opening"]
			"action": broken.state.actions = [{"event":"work","tags":["work"],"day":99,"period":"day"}]
			"unknown": broken.state.unrecognized = 1
			"metadata": broken.erase("developer")
			"version": broken.version = 999
			"future": broken.content_version = 999
		write("user://broken.json",broken)
		check(not core.load_game("user://broken.json") and core.state == before and core.save_error != "","Reject malformed "+defect)
	var legacy := saved.duplicate(true)
	legacy.version = 1
	legacy.erase("content_version"); legacy.erase("saved_at"); legacy.erase("developer")
	write("user://legacy.json",legacy)
	check(core.load_game("user://legacy.json") and core.state == before,"Legacy envelope migration")
	legacy.developer = "invalid"
	write("user://legacy.json",legacy)
	check(not core.load_game("user://legacy.json") and core.state == before,"Reject malformed legacy developer metadata")
	core.content.version = 2
	core.content.save_migrations = [{"from_version":1,"to_version":2,"renames":{"stats":{"old_INT":"INT"}}}]
	legacy = saved.duplicate(true)
	legacy.state.stats.old_INT = legacy.state.stats.INT
	legacy.state.stats.erase("INT")
	write("user://upgrade.json",legacy)
	check(core.load_game("user://upgrade.json") and core.state.stats.INT == 0,"Explicit content rename migration")
	core.content.save_migrations = []
	check(not core.load_game("user://upgrade.json") and core.save_error.begins_with("missing_content_migration"),"Missing chain refuses upgrade")
	core.content.version = 1
	var slots = preload("res://engine/save_slots.gd").new(core)
	check(slots.save(1),"Initial primary")
	var primary := FileAccess.get_file_as_string(slots.path(1))
	core.act({"op":"wait"})
	check(slots.save(1),"Overwrite creates backup")
	check(FileAccess.get_file_as_string(slots.path(1)+".bak") == primary,"Backup is previous valid primary")
	write(slots.path(1),"{incomplete")
	check(not slots.details(1).valid and slots.details(1).recoverable,"Corruption is visible with recovery option")
	check(slots.restore(1) and slots.load_slot(1) and core.state.period == "day","Explicit recovery")
	primary = FileAccess.get_file_as_string(slots.path(1))
	write(slots.path(1)+".tmp","interrupted data")
	check(slots.load_slot(1) and core.state.period == "day","Interrupted temp ignored")
	DirAccess.remove_absolute(slots.path(1)+".tmp")
	DirAccess.make_dir_absolute(slots.path(1)+".tmp")
	check(not slots.save(1) and FileAccess.get_file_as_string(slots.path(1)) == primary,"Write-open failure preserves primary")
	DirAccess.remove_absolute(slots.path(1)+".tmp")
	DirAccess.make_dir_absolute(slots.path(1)+".bak.tmp")
	check(not slots.save(1) and FileAccess.get_file_as_string(slots.path(1)) == primary,"Backup failure preserves primary")
	DirAccess.remove_absolute(slots.path(1)+".bak.tmp")
	check(slots.delete_slot(1) and not slots.details(1).exists and not slots.details(1).recoverable,"Delete primary backup and temps")
	check(not slots.delete_slot(99),"Invalid slot deletion rejected")
	# Search fixture changes only the goal, then traverses ordinary runtime commands.
	core.new_game(false)
	core.content.endings = {"tomorrow":{"conditions":[{"kind":"day","op":"gte","value":2}]}}
	var search = preload("res://engine/reachability.gd").new()
	var limits := {"max_states":1000,"max_depth":3,"seconds":5,"goal":"tomorrow"}
	var report: Dictionary = search.search(core,limits)
	check(report.status == "witness_found" and not report.guarantees_all_routes,"Bounded search finds one witness only")
	for step in report.steps: check(core.act(step).ok,"Witness replays through real rules")
	check(core.current_ending() == "tomorrow","Witness reaches goal")
	core.new_game(false)
	limits.max_states = 1
	check(search.search(core,limits).status == "inconclusive","State limit is inconclusive")
	limits.max_states = 1000; limits.max_depth = 1
	check(search.search(core,limits).reason == "depth_limit","Depth limit reported")
	limits.max_depth = 3; limits.seconds = 0
	check(search.search(core,limits).reason == "time_limit","Deadline is not success")
	print(JSON.stringify({"reliability_failures":failures}))
	quit(0 if failures.is_empty() else 1)
