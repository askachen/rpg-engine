extends "res://engine/mouse_test.gd"

func run() -> void:
	Engine.time_scale = 30
	root.size = Vector2i(1920,1080)
	app = load("res://engine/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await press("new")
	await target("harbor_notice")
	check(is_instance_valid(app.overlay), "Inspection opens notice")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/objects-notice.png")
	await press("back")
	await target("harbor_locker")
	var use := find_button(app.overlay, app.t("use_item"))
	check(use != null and use.disabled, "Missing key disables use")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/objects-item.png")
	await press("back")
	await target("locker_key_pickup")
	await target("harbor_locker")
	await press("use_item")
	check(app.core.state.inventory.get("locker_key") == 0, "Mouse use consumes key")
	check(app.core.state.flags.get("harbor_note_found",false), "Mouse use applies flag")
	await press("back")
	await target("harbor_note")
	await press("back")
	await press("wait")
	await target("to_workshop")
	var found := false
	for object in app.core.map_objects():
		if object.id == "mara_desk": found = object.position == [19.0,12.0]
	check(found, "NPC moved to workshop")
	await target("mara_desk")
	check(is_instance_valid(app.story), "Relocated NPC receives mouse interaction")
	await press("story_cancel")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/objects-workshop.png")
	print(JSON.stringify({"objects_mouse_failures":failures}))
	quit(0 if failures.is_empty() else 1)
