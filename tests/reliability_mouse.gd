extends "res://engine/mouse_test.gd"

func named(id: String) -> void:
	await process_frame
	var entry: Button = app.find_child(id,true,false)
	check(entry != null,"Button "+id)
	if entry != null:
		var ancestor := entry.get_parent()
		while ancestor != null:
			if ancestor is ScrollContainer: ancestor.ensure_control_visible(entry)
			ancestor = ancestor.get_parent()
		await process_frame
		await click(entry.get_global_rect().get_center())

func run() -> void:
	Engine.time_scale = 30
	root.size = Vector2i(1920,1080)
	app = load("res://engine/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await press("new")
	await finish_lines(); await press("accept")
	await press("menu"); await press("save"); await select_slot(1)
	await press("wait")
	await press("menu"); await press("save"); await select_slot(1); await press("confirm_overwrite")
	check(app.saves.details(1).recoverable,"GUI overwrite creates recoverable backup")
	# Deliberate disk corruption; no gameplay state injection.
	var file := FileAccess.open(app.saves.path(1),FileAccess.WRITE)
	file.store_string("{interrupted"); file.close()
	await press("menu"); await press("load")
	check(app.overlay.find_child("slot_1",true,false).disabled,"Corrupt primary disabled")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/s6-recovery.png")
	await named("RestoreSlot_1"); await named("ConfirmSlotAction")
	await select_slot(1)
	check(app.core.state.period == "day","Restored backup loads through mouse")
	await press("menu"); await press("load")
	await named("DeleteSlot_1"); await press("cancel")
	check(app.saves.details(1).valid,"Delete cancellation preserves slot")
	await named("DeleteSlot_1"); await named("ConfirmSlotAction")
	check(not app.saves.details(1).exists and not app.saves.details(1).recoverable,"Confirmed deletion removes both generations")
	check(app.overlay.find_child("slot_1",true,false).disabled,"Deleted slot summary refreshes")
	await press("back")
	await press("menu"); await press("debug")
	check(app.overlay.find_child("DebugCommand",true,false) == null,"Default developer panel is read-only")
	print(JSON.stringify({"reliability_mouse_failures":failures}))
	quit(0 if failures.is_empty() else 1)
