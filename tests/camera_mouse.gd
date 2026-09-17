extends "res://engine/mouse_test.gd"
## Walk a large authored fixture using screen clicks while the camera follows.
func settle() -> void:
	var guard := 0
	while (not app.walking.is_empty() or app.pending_target != "" or app.transitioning) and guard < 4000:
		await process_frame
		guard += 1
	check(guard < 4000, "World input did not settle")

func run() -> void:
	Engine.time_scale = 30
	root.size = Vector2i(1920, 1080)
	app = load("res://engine/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await press("new")
	check(app.camera == Vector2.ZERO, "Camera should clamp at top left")
	check(app.get_node("WorldWindow").clip_contents, "Map window must clip children")
	for goal in [Vector2i(18, 8), Vector2i(28, 14), Vector2i(38, 20), Vector2i(48, 26), Vector2i(54, 27)]:
		var screen_point: Vector2 = app.cell_to_screen(Vector2(goal))
		check(Rect2(app.ORIGIN, app.WORLD_SIZE).has_point(screen_point), "Fixture click outside camera")
		check(app.screen_to_cell(screen_point) == goal, "Camera coordinate inverse incorrect")
		await click(screen_point)
		await settle()
		check(app.core.state.position == [float(goal.x), float(goal.y)], "Screen click navigated to wrong tile")
	check(app.camera.x > 0 and app.camera.y > 0, "Large map did not scroll on both axes")
	check(app.world_surface.get_global_rect().intersects(app.get_node("WorldWindow").get_global_rect()), "Surface bounds were culled after scrolling")
	var motion := InputEventMouseMotion.new()
	motion.position = app.cell_to_screen(Vector2(55, 27))
	root.push_input(motion, true)
	await process_frame
	check(app.hovered_target().get("id") == "to_workshop", "Scrolled hover picked wrong object")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		check(not image.get_pixel(200, 400).is_equal_approx(app.appearance.palette("background")), "Scrolled world rendered blank")
		image.save_png("res://test-results/camera-far-corner.png")
	Engine.time_scale = 1
	await click(app.cell_to_screen(Vector2(55, 27)))
	check(app.transitioning, "Exit did not start transition")
	var before: Dictionary = app.core.state.duplicate(true)
	# Inject synchronously: yielding two frames can legitimately finish fade-out
	# on a busy machine and change maps before the state assertion.
	for pressed in [true, false]:
		var mouse := InputEventMouseButton.new()
		mouse.position = app.ORIGIN + Vector2(100, 100)
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = pressed
		root.push_input(mouse, true)
	var key := InputEventKey.new()
	key.keycode = KEY_T
	key.pressed = true
	root.push_input(key, true)
	check(app.core.state == before, "Input changed state during fade out")
	check(app.hovered_target().is_empty(), "Hover survived input lock")
	var phase_guard := 0
	while app.core.state.map != "workshop" and app.transitioning and phase_guard < 300:
		await process_frame
		phase_guard += 1
	check(app.transitioning and app.core.state.map == "workshop", "Expected destination during fade in")
	var during: Dictionary = app.core.state.duplicate(true)
	var wait_button := find_button(app, app.t("wait"))
	for pressed in [true, false]:
		var mouse := InputEventMouseButton.new()
		mouse.position = wait_button.get_global_rect().get_center()
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = pressed
		root.push_input(mouse, true)
	root.push_input(key, true)
	check(app.core.state == during, "HUD or keyboard bypassed fade-in lock")
	await settle()
	check(app.core.state.map == "workshop", "Exit failed to change map")
	check(app.camera == Vector2.ZERO, "Small destination retained previous camera")
	check(not app.transitioning and app.transition_layer == null, "Input lock not cleared")
	await press("wait")
	check(app.core.state.period == "evening", "Input did not resume after transition")
	print(JSON.stringify({"camera_failures": failures}))
	quit(0 if failures.is_empty() else 1)
