extends "res://engine/mouse_test.gd"
## Independent story uses existing viewport helpers without changing the engine.
func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/harbor-" + name + ".png")

func run() -> void:
	Engine.time_scale = 30
	root.size = Vector2i(1920, 1080)
	app = load("res://engine/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await capture("title")
	await press("new")
	await capture("quay")
	await target("grant")
	await target("mailbag")
	await event("mara_desk")
	await target("to_workshop")
	await capture("workshop")
	await target("supply_counter")
	var offer := find_button(app.overlay, app.t("repair_kit") + " — 15")
	check(offer != null, "Repair kit offer missing")
	if offer: await click(offer.get_global_rect().get_center())
	await target("power_panel")
	await target("chart_drawer")
	await target("workshop_return")
	await target("to_signal")
	await event("iris_station")
	await press("wait")
	await event("iris_station")
	await event("iris_station")
	await target("alignment")
	await event("iris_station")
	await capture("signal")
	await target("signal_return")
	await event("mara_desk")
	check(app.core.current_ending() == "harbor_reopens", "Harbor ending missing")
	check(app.core.state.characters.iris.stage == 4 and app.core.state.characters.mara.stage == 2, "Unequal route lengths failed")
	check(app.core.state.money == 25, "Harbor purchase amount incorrect")
	check(app.saves.details(0).valid, "Harbor autosave missing")
	check(app.profile.unlocked.has("signal_memory") and app.profile.unlocked.has("letter_memory"), "Harbor memories missing")
	await capture("ending")
	print(JSON.stringify({"harbor_mouse_failures": failures}))
	quit(0 if failures.is_empty() else 1)
