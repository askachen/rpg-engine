extends "res://engine/mouse_test.gd"
## Separate OS processes share one user directory; setup uses actual mouse input.
var options: Dictionary = {}

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			options[arg.get_slice("=", 0).trim_prefix("--")] = arg.substr(arg.find("=") + 1)
	Engine.time_scale = 30
	root.size = Vector2i(1920, 1080)
	app = load("res://engine/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	if options.phase == "write":
		check(app.profile.unlocked.is_empty() and app.profile.read_lines.is_empty(), "Other game leaked initial memories/read lines")
		check(app.language == "zh_TW" and app.dash_enabled and is_equal_approx(app.profile.volume, 0.8), "Other game leaked settings")
		for slot in range(7): check(not app.saves.details(slot).exists, "Other game leaked slot %d" % slot)
		await press("new")
		var scenario: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(options.route))
		for step in scenario.steps:
			match step.op:
				"interact":
					await target(step.target)
					await finish_lines()
				"choose":
					await press("accept" if step.choice == "accept" else "later")
					await finish_lines()
				"buy":
					if not is_instance_valid(app.overlay):
						for object in app.core.content.maps[app.core.state.map].objects:
							if object.kind == "shop" and object.shop == step.shop:
								await target(object.id)
					var price = app.core.content.shops[step.shop][step.item].price
					var offer := find_button(app.overlay, app.t(step.item) + " — " + str(int(price)))
					check(offer != null, "Missing offer")
					if offer: await click(offer.get_global_rect().get_center())
				"wait": await press("wait")
				"save":
					await press("menu"); await press("save"); await select_slot(3)
				"load":
					await press("menu"); await press("load"); await select_slot(3)
				"move", "snapshot": pass # Navigation is mouse-driven; snapshots are bridge-only assertions.
				_: failures.append("Unsupported UI route operation: " + str(step.op))
		check(app.core.current_ending() != "", "Normal mouse route failed to finish")
		await press("menu"); await press("settings")
		if app.core.content.id == "story_garden_demo":
			var language_button := find_button(app.overlay, str(app.core.content.locale_names[app.language]))
			await click(language_button.get_global_rect().get_center())
		var slider := app.overlay.find_children("*", "HSlider", true, false)[0] as HSlider
		var fraction := 0.25 if app.core.content.id == "story_garden_demo" else 0.65
		await click(slider.get_global_rect().position + Vector2(slider.size.x * fraction, slider.size.y / 2))
		check(absf(app.profile.volume - fraction) < 0.08, "Volume mouse input failed")
		await press("back")
		if app.core.content.id == "story_garden_demo": await press("dash_on")
		await press("menu"); await press("save"); await select_slot(1)
		await press("wait")
		await press("menu"); await press("save"); await select_slot(2)
		var evidence := {"profile": app.profile.duplicate(true), "slots": {}, "user_dir": OS.get_user_data_dir()}
		for slot in [0, 1, 2]: evidence.slots[str(slot)] = app.saves.details(slot).data.state
		var file := FileAccess.open(options.evidence, FileAccess.WRITE)
		file.store_string(JSON.stringify(evidence)); file.close()
	else:
		var evidence: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(options.evidence))
		check(app.profile == evidence.profile, "Profile changed across game switch/restart")
		check(app.language == evidence.profile.language and app.dash_enabled == evidence.profile.dash, "Settings not applied")
		check(absf(db_to_linear(AudioServer.get_bus_volume_db(0)) - evidence.profile.volume) < 0.001, "Audio setting not applied")
		await press("continue")
		check(app.screen == "game", "Continue did not load selected game's save")
		check(app.core.state in evidence.slots.values(), "Continue loaded foreign state")
		for slot in [1, 2, 0]:
			await press("menu"); await press("load"); await select_slot(slot)
			check(app.core.state == evidence.slots[str(slot)], "Slot mismatch %d" % slot)
		var before: Dictionary = app.core.state.duplicate(true)
		check(not app.core.load_game(options.foreign), "Foreign game save accepted")
		check(app.core.state == before, "Rejected foreign load changed state")
		check(not app.saves.details(6).valid and app.saves.details(6).exists, "Renamed foreign slot not rejected")
		await press("menu"); await press("load")
		check(app.overlay.find_child("slot_6", true, false).disabled, "Foreign slot enabled in UI")
		await press("back")
	await press("menu"); await press("gallery")
	for id in app.core.content.gallery:
		var card := find_button(app.overlay, app.t(app.core.content.gallery[id].title))
		check(card != null and not card.disabled, "Own gallery card missing: " + id)
	check(app.profile.read_lines.size() > 0, "Dialogue did not persist read history")
	print(JSON.stringify({"isolation_failures": failures}))
	quit(0 if failures.is_empty() else 1)
