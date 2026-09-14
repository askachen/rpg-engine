extends "res://engine/mouse_test.gd"
## Reuses real viewport mouse helpers; no direct rule calls or state injection.
func run() -> void:
	Engine.time_scale = 30
	root.size = Vector2i(1920, 1080)
	app = load("res://engine/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await press("new")
	await target("coins")
	await event("guide_npc")
	await target("kiosk_counter")
	await click(find_button(app.overlay, app.t("tea") + " — 10").get_global_rect().get_center())
	await event("guide_npc")
	check(app.core.current_ending() == "friendship", "Starter mouse route did not reach ending")
	check(app.core.state.money == 10 and app.core.state.inventory.tea == 0, "Starter economy mismatch")
	check(app.saves.details(0).valid, "Starter autosave missing")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/starter-complete.png")
	print(JSON.stringify({"starter_mouse_failures": failures}))
	quit(0 if failures.is_empty() else 1)
