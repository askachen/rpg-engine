extends "res://engine/mouse_test.gd"

func open_stats() -> void:
	var entry: Button = app.find_child("NumericStatus", true, false)
	check(entry != null, "Numeric status mouse entry")
	if entry != null: await click(entry.get_global_rect().get_center())

func run() -> void:
	Engine.time_scale = 30
	root.size = Vector2i(1920,1080)
	app = load("res://engine/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await press("new")
	check(app.core.active_event == "opening", "New game automatically presents opening")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/entry-opening.png")
	await finish_lines()
	await press("accept")
	await open_stats()
	check(app.overlay.find_child("Numeric_stats_INT",true,false).text.ends_with(": 0"), "Zero visible initially")
	check(app.overlay.find_child("Numeric_variables_internal_note",true,false) == null, "Internal variable hidden from player")
	await press("back")
	await target("coins")
	await event("guide_npc")
	await event("guide_npc")
	await open_stats()
	check(app.overlay.find_child("Numeric_stats_INT",true,false).text.ends_with(": 2"), "Mouse training updates stat display")
	check(app.overlay.find_child("Numeric_variables_focus",true,false).text.ends_with(": 0.5"), "Fractional variable displayed")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/numeric-status.png")
	await press("back")
	await event("guide_npc")
	check(app.core.state.stats.FIT == 1 and app.core.current_ending() == "friendship", "Numeric requirements allow normal completion")
	await press("menu")
	await press("save")
	await select_slot(2)
	await press("menu")
	await press("load")
	await select_slot(2)
	check(app.core.state.stats.INT == 2 and app.core.state.variables.focus == 0, "Mouse save/load retains values")
	await press("menu")
	await press("debug")
	var has_internal := false
	for row in app.overlay.find_children("*", "Label", true, false):
		if row.text.contains("internal_note"): has_internal = true
	check(has_internal, "Developer UI includes internal values")
	await press("back")
	app.language = "en"
	app.show_game()
	await open_stats()
	check(app.overlay.find_child("Numeric_stats_INT",true,false).text == "Intelligence: 2", "Localized numeric label")
	await press("back")
	await target("work_desk")
	check(app.core.active_event == "", "Work locked on Day 1")
	await press("wait")
	await event("work_desk")
	check(app.core.state.money == 19 and app.core.state.day == 2, "Non-NPC work sequence commits")
	await event("explore_spot")
	check(app.core.state.period == "late", "Empty exploration consumes period")
	await target("kiosk_counter")
	var buy: Button = app.overlay.find_child("ShopBuy_tea",true,false)
	await click(buy.get_global_rect().get_center())
	await target("course_station")
	await press("use_item")
	check(app.core.state.inventory.tea == 1 and app.core.active_event == "course", "Item prompt launches full event without consumption")
	await finish_lines()
	await press("accept")
	check(app.core.state.inventory.tea == 0 and app.core.state.stats.CHA == 1 and app.core.state.day == 3, "Object course consumes once and crosses day")
	# P1 continues the same ordinary mouse walkthrough.
	for i in range(3): await press("wait")
	check(app.core.format_day(int(app.core.state.day),app.language) == "Extra Day 1","Extra day reached through waiting")
	await target("kiosk_counter")
	var unlimited := false
	for row in app.overlay.find_children("*","Label",true,false):
		if row.text.contains("Unlimited"): unlimited = true
	check(unlimited,"Unlimited stock label")
	var snack: Button = app.overlay.find_child("ShopBuy_snack",true,false)
	await click(snack.get_global_rect().get_center())
	await target("milestone_board")
	await finish_lines()
	await press("accept")
	await finish_lines()
	await press("accept")
	check("milestone" in app.core.state.completed,"Nonlinear milestone completed")
	await press("menu")
	await press("save")
	await select_slot(3)
	await press("menu")
	await press("load")
	var extra_label := false
	for row in app.overlay.find_children("*","Button",true,false):
		if row.text.contains("Extra Day 1"): extra_label = true
	check(extra_label,"Save slot uses shared date formatter")
	await select_slot(3)
	var before: Dictionary = app.core.state.duplicate(true)
	var profile_before: Dictionary = app.profile.duplicate(true)
	var profile_disk := FileAccess.get_file_as_string(app.profile_path)
	var slot_disk := FileAccess.get_file_as_string(app.saves.path(0))
	await press("menu")
	await press("gallery")
	await press("milestone_title")
	check(app.gallery_view.replay != null,"Gallery launches complete event")
	if app.gallery_view.replay != null:
		app.execute({"op":"wait"})
		check(app.core.state == before,"World commands blocked during replay")
		await replay_lines()
		await press("special")
		await replay_lines()
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://test-results/p1-replay.png")
		await press("accept")
	check(app.gallery_view.replay == null,"Replay returns to gallery")
	check(app.core.state == before and app.profile == profile_before,"Replay leaves live state and profile untouched")
	check(FileAccess.get_file_as_string(app.profile_path) == profile_disk and FileAccess.get_file_as_string(app.saves.path(0)) == slot_disk,"Replay does not write profile or autosave")
	await press("milestone_title")
	await press("story_cancel")
	check(app.gallery_view.replay == null and app.core.state == before,"Replay cancellation cleans session")
	# Media fault/skip tests modify only the disposable replay's content.
	await press("milestone_title")
	await replay_media("res://games/fog_harbor/assets/video-check-v1.ogv")
	await press("video_skip")
	await press("story_cancel")
	check(app.gallery_view.replay == null,"Replay video skip and cancel return to gallery")
	await press("milestone_title")
	await replay_media("res://missing-replay-video.ogv")
	await process_frame
	await process_frame
	check(app.gallery_view.replay == null,"Missing replay media exits safely")
	check(app.core.state == before and app.profile == profile_before and FileAccess.get_file_as_string(app.profile_path) == profile_disk and FileAccess.get_file_as_string(app.saves.path(0)) == slot_disk,"Media skip/error preserve live state and files")
	await press("back")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/p1-world.png")
	print(JSON.stringify({"numeric_mouse_failures":failures}))
	quit(0 if failures.is_empty() else 1)

func replay_lines() -> void:
	var guard := 0
	while app.gallery_view.replay != null and app.gallery_view.replay.story.cursor < app.gallery_view.replay.story.lines.size() and guard < 100:
		await press("story_next")
		guard += 1
	check(guard < 100,"Replay advances through full dialogue")

func replay_media(path: String) -> void:
	var session = app.gallery_view.replay
	if session == null:
		check(false,"Missing replay for media test")
		return
	session.host.remove_child(session.story)
	session.story.queue_free()
	session.core.content.events.milestone.sequence = [{"id":"media","speaker":"guide","text":"milestone_text","video":{"path":path,"loop":true,"volume":0.0}}]
	session.show_story()
	await process_frame
