extends "res://tests/world_objects.gd"

func _initialize() -> void:
	check(core.load_content("res://games/numeric_lab/game.json"), "Load combined fixture")
	check(core.active_event == "", "Content load does not launch opening")
	core.new_game()
	check(core.active_event == "opening" and not core.save_game("user://opening.json"), "New game launches opening and locks saving")
	check(core.act({"op":"wait"}).message == "event_busy", "Opening locks world")
	check(core.act({"op":"cancel_event"}).ok and core.state.completed.is_empty(), "Opening cancellation skips without effects")
	core.new_game()
	check(core.act({"op":"choose","choice":"accept"}).ok and "opening" in core.state.completed, "Opening completes through shared event transaction")
	check(core.save_game("user://opening.json") and core.load_game("user://opening.json") and core.active_event == "", "Loading never replays opening")
	var ops := {"eq":[1,2],"ne":[2,1],"lt":[2,1],"lte":[1,0],"gt":[0,1],"gte":[1,2]}
	# Runtime comparison boundary tests include zero as an operand; authored day must be >= 1.
	for op in ops:
		check(core.satisfied([{"kind":"day","op":op,"value":ops[op][0]}]), "Day positive " + op)
		check(not core.satisfied([{"kind":"day","op":op,"value":ops[op][1]}]), "Day negative " + op)
	walk(Vector2i(3,5),true)
	check(core.act({"op":"interact","target":"work_desk"}).message == "unavailable", "Work locked before day two")
	for i in range(3): check(core.act({"op":"wait"}).ok, "Ordinary wait across midnight")
	check(core.state.day == 2 and core.state.period == "day", "Date advances at midnight")
	check(not core.satisfied(core.content.events.work.conditions), "Absent target context fails closed")
	check(core.act({"op":"interact","target":"work_desk"}).event == "work", "Non-character event entry")
	var before: Dictionary = core.state.duplicate(true)
	check(core.act({"op":"choose","choice":"later"}).ok and core.state == before, "Object event cancel costs nothing")
	check(core.act({"op":"interact","target":"work_desk"}).ok, "Work retry")
	check(core.act({"op":"choose","choice":"accept"}).ok and core.state.money == before.money+3 and core.state.period == "evening", "Work rewards and time committed once")
	check(core.act({"op":"choose","choice":"accept"}).message == "no_event", "Duplicate callback rejected")
	check(core.act({"op":"interact","target":"work_desk"}).ok, "Repeatable object starts again")
	core.act({"op":"cancel_event"})
	walk(Vector2i(7,5),true)
	before = core.state.duplicate(true)
	check(core.act({"op":"interact","target":"explore_spot"}).ok, "Empty exploration entry")
	check(core.act({"op":"choose","choice":"accept"}).ok and core.state.money == before.money and core.state.period == "late", "No reward exploration still costs a period")
	check(not core.satisfied([{"kind":"map","id":"absent"}]), "Wrong map rejected")
	# Zone membership uses player position with right/bottom excluded.
	walk(Vector2i(8,4))
	check(core.satisfied([{"kind":"zone","map":"room","id":"lobby"}]), "Inside zone")
	walk(Vector2i(9,4))
	check(not core.satisfied([{"kind":"zone","map":"room","id":"lobby"}]) and core.satisfied([{"kind":"zone","map":"room","id":"classroom"}]), "Right boundary excluded")
	walk(Vector2i(10,5),true)
	check(core.act({"op":"interact","target":"course_station","item":"tea"}).message == "item_required", "Missing required item")
	walk(Vector2i(3,3),true)
	core.act({"op":"interact","target":"coins"})
	walk(Vector2i(7,3),true)
	check(core.act({"op":"buy","shop":"kiosk","item":"tea"}).ok, "Acquire item through normal shop")
	walk(Vector2i(10,5),true)
	before = core.state.duplicate(true)
	check(core.act({"op":"interact","target":"course_station","item":"tea"}).ok and core.state == before, "Item consumption deferred")
	check(core.act({"op":"choose","choice":"later"}).ok and core.state == before, "Cancel preserves item")
	check(core.act({"op":"interact","target":"course_station","item":"tea"}).ok, "Course retry")
	core.content.events.course.choices[0].effects = [{"kind":"money","value":-999}]
	check(core.act({"op":"choose","choice":"accept"}).message == "effect_failed" and core.state == before, "Failed course rolls back pending item consumption")
	core.content.events.course.choices[0].erase("effects")
	check(core.act({"op":"choose","choice":"accept"}).ok and core.state.inventory.tea == 0 and core.state.stats.CHA == 1 and core.state.day == 3, "Item/stat/time atomic commit across midnight")
	# Context changes are failure fixtures, never used to claim a normal walkthrough.
	core.content.events.welcome.conditions = [{"kind":"target","id":"guide_npc"},{"kind":"map","id":"room"}]
	walk(Vector2i(5,3),true)
	check(not core.event_candidates("guide")[0].eligible, "Candidate without context not eligible")
	var candidates: Array = core.event_candidates("guide", {"target":"guide_npc"})
	check(candidates.any(func(c): return c.id == "welcome" and c.selected), "Candidate with matching context selected")
	var response: Dictionary = core.act({"op":"interact","target":"guide_npc"})
	check(response.event == "welcome" and response.candidates == candidates, "Trigger preserves candidate diagnostics and uses same context")
	before = core.state.duplicate(true)
	core.state.position = [1,1]
	var changed: Dictionary = core.state.duplicate(true)
	check(core.act({"op":"choose","choice":"accept"}).message == "effect_failed" and core.state == changed, "Moved away before commit cannot apply effects")
	core.act({"op":"cancel_event"})
	core.state = before
	# Day condition in schedule shares the same evaluator and stops appearing after day three.
	var npc: Dictionary = core.content.maps.room.objects.filter(func(o): return o.id == "guide_npc")[0]
	npc.schedule = [{"map":"room","position":[5,3],"conditions":[{"kind":"day","op":"lt","value":4}]}]
	check(core.map_objects().any(func(o): return o.id == "guide_npc"), "Schedule before boundary")
	for i in range(3): core.act({"op":"wait"})
	check(not core.map_objects().any(func(o): return o.id == "guide_npc"), "Schedule updates on date boundary")
	core.content.maps.other = core.content.maps.room.duplicate(true)
	core.content.maps.other.objects = []
	npc.schedule = [{"map":"other","position":[5,3],"conditions":[]}]
	core.state.map = "other"
	core.state.position = [4,3]
	check(core.act({"op":"interact","target":"guide_npc"}).message == "smalltalk", "Same NPC moved to another map cannot trigger room-specific event")
	print(JSON.stringify({"entry_failures":failures}))
	quit(0 if failures.is_empty() else 1)
