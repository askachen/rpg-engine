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
	print(JSON.stringify({"numeric_mouse_failures":failures}))
	quit(0 if failures.is_empty() else 1)
