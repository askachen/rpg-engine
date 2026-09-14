extends SceneTree
## Presentation fixtures isolate playback; mouse_test covers normal progression.
var app
var failures: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, reason: String) -> void:
	if not value: failures.append(reason)

func start_event() -> void:
	app.core.new_game()
	app.core.state.map = "shop"
	app.core.state.position = [18, 9]
	app.core.state.period = "evening"
	app.core.state.characters.a.stage = 1
	app.core.state.characters.a.affection = 10
	app.core.state.completed = ["a1"]
	app.core.state.inventory.coffee = 1
	app.execute({"op": "interact", "target": "a_npc"})
	app.story.set_process(false)

func play_lines(mode: String) -> void:
	var guard := 0
	while is_instance_valid(app.story) and app.story.cursor < app.story.lines.size() and guard < 100:
		var player = app.story
		match mode:
			"normal": player.advance(); player.advance()
			"auto": player.auto = true; player._process(100.0); player._process(2.0)
			"skip": player.skip = true; player._process(0.01)
		guard += 1
	check(guard < 100, "Playback stalled: " + mode)

func run() -> void:
	root.size = Vector2i(1920, 1080)
	app = load("res://engine/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.profile.read_lines = []
	start_event()
	var player = app.story
	var before: Dictionary = app.core.state.duplicate(true)
	player.select("accept")
	check(app.core.state == before and player.chosen == "", "Choice bypassed unread sequence")
	player.skip = true
	player._process(100.0)
	player._process(100.0)
	check(player.cursor == 0, "Skip advanced unread text")
	player.paused = true
	player.auto = true
	player._process(100.0)
	check(player.cursor == 0, "History did not pause playback")
	player.paused = false
	player.hidden_box = true
	player._process(100.0)
	check(player.cursor == 0, "Hidden UI did not pause playback")
	app.execute({"op": "choose", "choice": "later"})
	var results: Array = []
	for mode in ["normal", "auto", "skip"]:
		start_event()
		play_lines(mode)
		check(app.core.state.inventory.coffee == 1, "Intro consumed gift")
		check(app.core.active_event == "a2", "Auto/skip selected a choice")
		app.story.select("accept")
		check(app.core.state.inventory.coffee == 1, "Reward committed before outro")
		player = app.story
		play_lines(mode)
		player.commit()
		check(app.core.state.completed.count("a2") == 1, "Duplicate completion")
		check(app.core.state.inventory.coffee == 0, "Gift was not consumed exactly once")
		check(app.saves.details(0).valid, "Missing autosave after outro")
		results.append(app.core.state.duplicate(true))
	check(results[0] == results[1] and results[1] == results[2], "Playback modes changed outcome")
	start_event()
	play_lines("normal")
	before = app.core.state.duplicate(true)
	app.story.select("later")
	check(app.core.state == before and app.core.active_event == "", "Cancellation changed progression")
	print(JSON.stringify({"dialogue_test_failures": failures}))
	quit(0 if failures.is_empty() else 1)
