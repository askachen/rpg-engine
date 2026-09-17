extends SceneTree
const Core = preload("res://engine/core.gd")
var core = Core.new()
var failures: Array = []

func check(value: bool, description: String) -> void:
	if not value: failures.append(description)

func walk(position: Vector2i, interaction: bool = false) -> void:
	var route: Dictionary = core.path_to(position, interaction)
	check(route.ok, "Path unavailable: " + str(position))
	for cell in route.path:
		var delta: Vector2i = cell - Vector2i(int(core.state.position[0]), int(core.state.position[1]))
		check(core.act({"op":"move", "dx":delta.x, "dy":delta.y}).ok, "Move failed")

func find(id: String, map_id: String = "") -> Dictionary:
	for target in core.map_objects(map_id):
		if target.id == id: return target
	return {}

func _initialize() -> void:
	check(core.load_content(OS.get_cmdline_user_args()[0]), "Load fixture")
	check(find("mara_desk").position == [14.0,7.0], "Default schedule")
	check(find("visitor").position == [18.0,8.0], "Day visitor present")
	walk(Vector2i(17,8))
	check(core.act({"op":"interact","target":"visitor"}).message == "event", "Start arrival event")
	var event_state: Dictionary = core.state.duplicate(true)
	check(core.act({"op":"choose","choice":"accept"}).message == "world_blocked", "Choice cannot spawn blocker on player")
	check(core.state == event_state and core.active_event == "", "Blocked choice must rollback and release exploration")
	walk(Vector2i(16,9))
	var before: Dictionary = core.state.duplicate(true)
	check(core.act({"op":"wait"}).message == "world_blocked", "Arrival on player must be rejected")
	check(core.state == before, "Rejected wait mutated state")
	walk(Vector2i(15,9))
	check(core.act({"op":"wait"}).ok, "Wait after moving")
	check(find("visitor").is_empty(), "Unmatched schedule must disappear")
	check(find("mara_desk").position == [16.0,9.0], "Evening position")
	check(core.walkable(Vector2i(14,7)) and not core.walkable(Vector2i(16,9)), "Collision moved with NPC")
	check(not core.act({"op":"move","dx":1,"dy":0}).ok, "Cannot walk through arriving NPC")
	check(core.path_to(Vector2i(14,7)).ok and not core.path_to(Vector2i(16,9)).ok, "Planner sees current position")
	check(core.save_game("user://schedule.json"), "Save evening")
	check(core.act({"op":"wait"}).ok, "Wait late")
	check(core.load_game("user://schedule.json"), "Restore evening")
	check(find("mara_desk").position == [16.0,9.0], "Schedule reconstructed after load")
	check(find("harbor_note").is_empty(), "Hidden note absent")
	check(not core.act({"op":"interact","target":"harbor_note"}).ok, "Hidden target cannot interact")
	walk(Vector2i(10,10), true)
	before = core.state.duplicate(true)
	check(core.act({"op":"interact","target":"harbor_locker"}).message == "item_required", "Missing item")
	check(core.state == before, "Missing item mutated state")
	walk(Vector2i(6,10), true)
	check(core.act({"op":"interact","target":"locker_key_pickup"}).ok, "Collect key")
	walk(Vector2i(8,10), true)
	before = core.state.duplicate(true)
	check(core.act({"op":"interact","target":"broken_locker","item":"locker_key"}).message == "effect_failed", "Failed effects rejected")
	check(core.state == before, "Failure must restore consumed item and flags")
	walk(Vector2i(10,10), true)
	before = core.state.duplicate(true)
	check(core.act({"op":"interact","target":"harbor_locker","item":"chart"}).message == "item_required", "Wrong item rejected")
	check(core.state == before, "Wrong item mutated state")
	check(core.act({"op":"interact","target":"harbor_locker","item":"locker_key"}).ok, "Use correct item")
	check(core.state.inventory.locker_key == 0 and core.state.flags.harbor_note_found, "Consume plus effects")
	check(find("mara_desk").is_empty() and find("mara_desk", "workshop").position == [19.0,12.0], "First matching AND schedule wins across maps")
	check(not find("harbor_note").is_empty(), "Flag reveals object")
	before = core.state.duplicate(true)
	check(core.act({"op":"interact","target":"harbor_locker"}).ok, "Completed inspection can be reread")
	check(core.state == before, "Reread must not repeat effects")
	print(JSON.stringify({"object_failures":failures}))
	quit(0 if failures.is_empty() else 1)
