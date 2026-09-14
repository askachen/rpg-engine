extends SceneTree
## JSON scenario bridge. No state injection or alternate gameplay rules.
const Core = preload("res://engine/core.gd")
const Slots = preload("res://engine/save_slots.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("Expected scenario.json output.json")
		quit(2)
		return
	var scenario = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var core = Core.new()
	if not core.load_content(scenario.get("content", preload("res://engine/game_bootstrap.gd").content_path())):
		quit(2)
		return
	var responses: Array = []
	var snapshots: Dictionary = {}
	var save_path: String = args[1] + ".save"
	var slots = Slots.new(core, args[1].get_base_dir())
	for step in scenario.get("steps", []):
		var response: Dictionary
		match step.op:
			"path": response = core.path_to(Vector2i(int(step.x), int(step.y)))
			"save_slot": response = {"ok": slots.save(int(step.slot))}
			"load_slot": response = {"ok": slots.load_slot(int(step.slot))}
			"slot_info": response = {"ok": true, "info": slots.details(int(step.slot))}
			"latest_slot": response = {"ok": true, "slot": slots.latest()}
			"save": response = {"ok": core.save_game(save_path)}
			"load": response = {"ok": core.load_game(save_path)}
			"snapshot":
				snapshots[step.id] = core.state.duplicate(true)
				response = {"ok": true}
			"checks": response = {"ok": true, "checks": core.checks(core.content.events[step.event].conditions)}
			_: response = core.act(step)
		responses.append(response)
	var output := FileAccess.open(args[1], FileAccess.WRITE)
	output.store_string(JSON.stringify({"state": core.state, "responses": responses, "snapshots": snapshots, "history": core.history, "active_event": core.active_event}))
	output.close()
	quit(0)
