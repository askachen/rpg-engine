extends SceneTree
## Uses authored fixture initial state, then normal interactions and choices.
var failures: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, reason: String) -> void:
	if not value: failures.append(reason)

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/" + name + ".png")

func run() -> void:
	var app = load("res://engine/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.show_game()
	await capture("routes-start")
	check(app.core.content.characters.size() == 3, "Fixture must have three characters")
	check(app.core.route_progress("ivy").total == 1, "One-event route unsupported")
	check(app.core.route_progress("mira").total == 2, "Two-event route unsupported")
	check(app.core.route_progress("noa").total == 4, "Four-event route unsupported")
	check(app.core.current_ending() == "", "Ending unlocked on new game")
	for who in ["ivy", "mira", "noa"]:
		var route: Array = app.core.content.routes[who].events
		for id in route:
			var progress: Dictionary = app.core.route_progress(who)
			check(progress.next_event == id, "Wrong next event: " + who)
			app.execute({"op": "interact", "target": who + "_npc"})
			check(app.core.active_event == id, "Higher priority future event skipped route order")
			app.execute({"op": "choose", "choice": "accept"})
			check(id in app.core.state.completed, "Event not completed: " + id)
			if app.core.state.completed.size() == 6:
				check(app.core.current_ending() == "", "Six events incorrectly triggered ending")
		check(app.core.route_progress(who).complete, "Route did not finish: " + who)
	check(app.core.current_ending() == "reunion", "Configured ending did not trigger")
	check(app.status.text == app.t("fixture_end"), "HUD ignored ending text")
	await capture("routes-end")
	check(app.profile.unlocked.has("keepsake_ivy") and app.profile.unlocked.has("keepsake_noa"), "Configured gallery did not unlock")
	app.show_gallery()
	app.close_modal()
	check(app.saves.save(2), "Save failed")
	app.core.new_game()
	check(not app.core.route_progress("noa").complete, "Route state survived new game")
	check(app.saves.load_slot(2), "Load failed")
	check(app.core.route_progress("noa").complete and app.core.current_ending() == "reunion", "Progress not restored")
	# Stage numbers alone are not evidence that route events were completed.
	app.core.new_game()
	app.core.state.characters.noa.stage = 99
	check(not app.core.route_progress("noa").complete and app.core.current_ending() == "", "Numeric stage falsely completed route")
	print(JSON.stringify({"route_failures": failures}))
	quit(0 if failures.is_empty() else 1)
