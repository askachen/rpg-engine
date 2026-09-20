extends SceneTree
var failures: Array = []
var core = preload("res://engine/core.gd").new()

func check(value: bool, message: String) -> void:
	if not value: failures.append(message)

func write_save(data: Dictionary) -> void:
	var file := FileAccess.open("user://numeric.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func _initialize() -> void:
	check(core.load_content("res://games/numeric_lab/game.json"), "Load numeric content")
	check(core.state.stats == {"INT":0,"FIT":0,"CHA":0}, "Implicit zero defaults")
	check(core.state.variables.focus == 0 and core.state.variables.internal_note == 9, "Initial overrides declared default")
	check(core.act({"op":"interact","target":"coins"}).ok, "Collect funds")
	for i in range(2): check(core.act({"op":"move","dx":1,"dy":0}).ok, "Walk normally")
	var before: Dictionary = core.state.duplicate(true)
	check(core.act({"op":"interact","target":"guide_npc"}).event == "welcome", "Training selected before threshold")
	check(core.act({"op":"choose","choice":"later"}).ok and core.state == before, "Cancel has no numeric/cost/time effects")
	for i in range(2):
		check(core.act({"op":"interact","target":"guide_npc"}).ok, "Repeat training entry")
		check(core.act({"op":"choose","choice":"accept"}).ok, "Training committed")
	check(core.state.stats.INT == 2 and core.state.variables.focus == 0.5 and core.state.money == 16, "Training numeric and financial results")
	var values := {"eq":[2,1],"ne":[1,2],"lt":[3,2],"lte":[2,1],"gt":[1,2],"gte":[2,3]}
	for op in values:
		for index in range(2):
			var answer: Array = core.checks([{"kind":"stat","id":"INT","op":op,"value":values[op][index]}])
			check(answer[0].passed == (index == 0) and answer[0].actual == 2, "Comparison " + op)
	check(not core.satisfied([{"kind":"stat","id":"missing","op":"ne","value":0}]), "Unknown ID cannot satisfy ne")
	before = core.state.duplicate(true)
	for invalid in [{"kind":"stat","id":"INT","op":"add","value":2}, {"kind":"stat","id":"INT","op":"set","value":-1}, {"kind":"stat","id":"INT","op":"add","value":0.5}, {"kind":"variable","id":"focus","op":"set","value":INF}, {"kind":"variable","id":"focus","op":"set","value":true}, {"kind":"stat","id":"missing","op":"set","value":1}, {"kind":"stat","id":"INT","op":"multiply","value":1}]:
		check(not core.apply_effects([{"kind":"money","value":-1},{"kind":"stat","id":"CHA","op":"add","value":1}, invalid]), "Reject invalid numeric effect")
		check(core.state == before, "Rollback money and prior numeric effects")
	check(not core.apply_effects([{"kind":"stat","id":"CHA","op":"add","value":1},{"kind":"money","value":-999}]) and core.state == before, "Legacy financial failure rolls numeric effect back")
	check(core.act({"op":"interact","target":"guide_npc"}).event == "tea_time", "Threshold unlocks assessment")
	check(core.act({"op":"choose","choice":"accept"}).ok and core.state.stats.FIT == 1 and core.state.variables.focus == 0, "Set and negative delta")
	before = core.state.duplicate(true)
	check(core.act({"op":"choose","choice":"accept"}).message == "no_event" and core.state == before, "Duplicate completion no effects")
	check(core.save_game("user://numeric.json"), "Save")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://numeric.json"))
	check(core.load_game("user://numeric.json") and core.state == before, "Roundtrip")
	var slots = preload("res://engine/save_slots.gd").new(core)
	check(slots.save(1) and slots.details(1).valid, "Slot browser accepts numeric saves")
	for invalid in [null, true, "2", -1, 4, 0.5]:
		var damaged := saved.duplicate(true)
		damaged.state.stats.INT = invalid
		write_save(damaged)
		check(core.read_save("user://numeric.json").is_empty() and not core.load_game("user://numeric.json") and core.state == before, "Malformed stored INT rejected without mutation")
	for group in ["stats", "variables"]:
		var damaged := saved.duplicate(true)
		damaged.state[group] = []
		write_save(damaged)
		check(not core.load_game("user://numeric.json") and core.state == before, "Malformed numeric container rejected")
		damaged = saved.duplicate(true)
		damaged.state[group].unknown = 1
		write_save(damaged)
		check(not core.load_game("user://numeric.json") and core.state == before, "Unknown numeric save ID rejected")
	var legacy := saved.duplicate(true)
	legacy.state.erase("stats")
	legacy.state.erase("variables")
	write_save(legacy)
	check(core.load_game("user://numeric.json") and core.state.stats.INT == 0 and core.state.variables.internal_note == 9, "Legacy missing groups initialized")
	legacy = saved.duplicate(true)
	legacy.state.stats.erase("CHA")
	write_save(legacy)
	check(core.load_game("user://numeric.json") and core.state.stats.INT == 2 and core.state.stats.CHA == 0, "Missing new ID backfilled, existing values retained")
	core.state.stats.INT = NAN
	check(not core.save_game("user://invalid.json"), "Nonfinite live state cannot be saved")
	check(core.load_content("res://games/first_story/game.json") and not core.state.has("stats"), "Legacy games keep their original state shape")
	print(JSON.stringify({"numeric_contract_failures":failures}))
	quit(0 if failures.is_empty() else 1)
