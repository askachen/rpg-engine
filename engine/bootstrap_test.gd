extends SceneTree
var failures: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, reason: String) -> void:
	if not value: failures.append(reason)

func run() -> void:
	var Bootstrap = load("res://engine/game_bootstrap.gd")
	if "--legacy" in OS.get_cmdline_user_args():
		var old := FileAccess.open("user://story_garden_demo_profile.json", FileAccess.WRITE)
		old.store_string(JSON.stringify({"unlocked": ["a"], "read_lines": ["legacy_line"], "language": "en", "volume": 0.4}))
		old.close()
		var legacy = load("res://engine/main.tscn").instantiate()
		root.add_child(legacy)
		await process_frame
		check(legacy.core.content.id == "story_garden_demo", "Default content not loaded")
		check(legacy.language == "en" and legacy.profile.read_lines == ["legacy_line"] and legacy.profile.unlocked == ["a"], "Existing profile not restored")
		print(JSON.stringify({"bootstrap_failures": failures}))
		quit(0 if failures.is_empty() else 1)
		return
	var selected: String = Bootstrap.content_path()
	check(selected.ends_with("alternate.json"), "CLI did not override project default")
	var scene = load("res://engine/main.tscn")
	var app = scene.instantiate()
	root.add_child(app)
	await process_frame
	check(app.core.content.id == "alternate_game", "UI ignored selected content")
	app.profile.language = "en"
	app.language = "en"
	app.profile.read_lines = ["only_alternate"]
	app.profile.unlocked = ["a"]
	app.save_profile()
	app.core.state.money = 77
	check(app.saves.save(1), "Alternate save failed")
	var alternate_profile: String = app.profile_path
	app.queue_free()
	await process_frame
	# A fresh UI instance must restore this game's own profile and save.
	app = scene.instantiate()
	root.add_child(app)
	await process_frame
	check(app.language == "en" and app.profile.read_lines == ["only_alternate"], "Profile did not survive restart")
	check(app.saves.load_slot(1) and app.core.state.money == 77, "Save did not survive restart")
	var Core = load("res://engine/core.gd")
	var original = Core.new()
	check(original.load_content(str(ProjectSettings.get_setting("story_engine/content_path"))), "Project default invalid")
	var Slots = load("res://engine/save_slots.gd")
	var slots = Slots.new(original)
	check(not slots.details(1).exists, "Game save slots collided")
	check(not original.load_game(app.saves.path(1)), "Cross-game save accepted")
	check(Bootstrap.profile_path(original.content.id) != alternate_profile, "Profiles collided")
	check(Bootstrap.profile_path("story_garden_demo") == "user://story_garden_demo_profile.json", "Legacy profile path changed")
	check(not Bootstrap.valid_id("../escape") and not Bootstrap.valid_id(""), "Invalid ID accepted")
	check(Bootstrap.valid_id("game-2_v1"), "Legal ID rejected")
	check(not original.load_content("res://does-not-exist.json"), "Missing content accepted")
	print(JSON.stringify({"bootstrap_failures": failures}))
	quit(0 if failures.is_empty() else 1)
