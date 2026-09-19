extends SceneTree
## End-to-end input test: sends mouse events through the viewport, never core.act.
var app: Control
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, explanation: String) -> void:
	if not condition: failures.append(explanation)

func click(position: Vector2, mouse_button: int = MOUSE_BUTTON_LEFT) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = mouse_button
		event.pressed = pressed
		root.push_input(event, true)
	await process_frame
	await process_frame

func find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text: return node
	for child in node.get_children():
		var found := find_button(child, text)
		if found: return found
	return null

func press(key: String) -> void:
	await process_frame
	await process_frame
	var target := find_button(app.overlay if is_instance_valid(app.overlay) else app, app.t(key))
	if target == null:
		failures.append("Missing button: " + key)
		return
	var ancestor := target.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(target)
			await process_frame
			await process_frame
		ancestor = ancestor.get_parent()
	await click(target.get_global_rect().get_center())

func target(id: String) -> void:
	var found := false
	for object in app.core.map_objects():
		if object.id == id:
			await click(app.cell_to_screen(Vector2(object.position[0], object.position[1])))
			found = true
			break
	if not found:
		failures.append("Missing map target: " + id)
		return
	var frames := 0
	while (not app.walking.is_empty() or app.pending_target != "" or app.transitioning) and frames < 3000:
		await process_frame
		frames += 1
	check(frames < 3000, "Navigation timed out: " + id)
	await process_frame
	await process_frame

func event(npc: String) -> void:
	await target(npc)
	if npc == "b_npc" and app.core.state.completed.is_empty():
		await press("story_log")
		check(app.story.paused, "History failed to pause dialogue")
		await press("back")
		check(not app.story.paused, "History failed to resume dialogue")
		await press("story_hide")
		check(app.story.hidden_box, "Mouse hide failed")
		await press("story_next")
		check(app.story.cursor == 0, "Hidden dialogue advanced")
		await press("story_hide")
	await finish_lines()
	await press("accept")
	await finish_lines()

func finish_lines() -> void:
	var guard := 0
	while is_instance_valid(app.story) and app.story.cursor < app.story.lines.size() and guard < 100:
		await press("story_next")
		guard += 1
	check(guard < 100, "Dialogue did not reach choice or finish")

func select_slot(slot: int) -> void:
	await process_frame
	await process_frame
	var entry := app.overlay.find_child("slot_%d" % slot, true, false) as Button
	if entry == null:
		failures.append("Missing slot button: %d" % slot)
		return
	await click(entry.get_global_rect().get_center())

func timed_walk(destination: Vector2i) -> int:
	# Fixed frame deltas isolate speed from machine load; mouse still starts the route.
	app.set_process(false)
	await click(app.ORIGIN + (Vector2(destination) + Vector2(0.5, 0.5)) * app.tile_size())
	var frames := 0
	while not app.walking.is_empty() and frames < 2000:
		app._process(1.0 / 60.0)
		frames += 1
	app.set_process(true)
	return frames

func run() -> void:
	Engine.time_scale = 30
	root.size = Vector2i(1920, 1080)
	app = load("res://engine/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await press("new")
	check(app.screen == "game", "Mouse new game failed")
	await press("dash_on")
	var walk_frames := await timed_walk(Vector2i(8, 3))
	await press("dash_off")
	var dash_frames := await timed_walk(Vector2i(2, 8))
	check(dash_frames < walk_frames * 0.6, "Dash must be at least twice as fast on the same path")
	check(app.dash_enabled, "Mouse dash toggle failed")
	# A wall is unreachable; no teleport and no pending movement.
	await click(app.ORIGIN + Vector2(9.5, 3.5) * app.tile_size())
	check(app.walking.is_empty(), "Wall must reject a destination")
	check(app.core.state.position == app.core.content.initial.position, "Wall click moved player")
	await click(app.ORIGIN + Vector2(8.5, 3.5) * app.tile_size())
	var movement_frames := 0
	while not app.walking.is_empty() and movement_frames < 3000:
		await process_frame
		movement_frames += 1
	check(int(app.core.state.position[0]) == 8 and int(app.core.state.position[1]) == 3, "Ground click did not navigate around wall")
	await target("money_pickup")
	check(app.core.state.money == 100, "Pickup click failed")
	await target("home_exit")
	check(app.core.state.map == "street", "Mouse exit failed")
	await event("b_npc")
	await target("lamp")
	await event("b_npc")
	await target("street_shop")
	await event("a_npc")
	await target("counter")
	await click(find_button(app.overlay, app.t("coffee") + " — 20").get_global_rect().get_center())
	await target("counter")
	await click(find_button(app.overlay, app.t("letter") + " — 30").get_global_rect().get_center())
	await press("wait")
	await event("a_npc")
	await event("a_npc")
	await target("shop_exit")
	await press("wait")
	await event("b_npc")
	check(app.core.state.completed.size() == 6, "Mouse-only route did not complete all six events")
	check(app.core.state.money == 50, "Mouse purchases charged wrong amount")
	check(app.saves.details(0).valid, "Event did not create autosave")
	check(not app.saves.details(1).exists, "Autosave overwrote manual slot")
	await press("menu")
	await press("save")
	await select_slot(1)
	var saved: Dictionary = app.core.state.duplicate(true)
	await press("wait")
	var second: Dictionary = app.core.state.duplicate(true)
	await press("menu")
	await press("save")
	await select_slot(2)
	await press("menu")
	await press("load")
	check(app.overlay.find_child("slot_6", true, false).disabled, "Empty slot must be disabled in load mode")
	await select_slot(1)
	check(app.core.state == saved, "Mouse save/load failed")
	await press("wait")
	await press("wait")
	await press("menu")
	await press("save")
	await select_slot(1)
	await press("cancel")
	check(app.saves.details(1).data.state == saved, "Cancel overwrote manual slot")
	await select_slot(1)
	await press("confirm_overwrite")
	check(app.saves.details(1).data.state == app.core.state, "Confirmed overwrite failed")
	check(app.saves.details(2).data.state == second, "Overwrite changed a different slot")
	check(app.saves.details(0).data.state == saved, "Manual save changed autosave")
	await press("menu")
	await press("load")
	await select_slot(2)
	check(app.core.state == second, "Second slot did not restore its own state")
	await press("menu")
	await press("gallery")
	await press("gallery_a")
	await press("back")
	await press("back")
	check(not is_instance_valid(app.overlay), "Gallery could not close with mouse")
	# A right click cancels movement, and menu opening cancels any queued route.
	await click(app.ORIGIN + Vector2(9.5, 6.5) * app.tile_size())
	await click(Vector2(750, 620), MOUSE_BUTTON_RIGHT)
	check(app.walking.is_empty() and app.pending_target == "", "Right click did not stop navigation")
	await click(app.ORIGIN + Vector2(1.5, 1.5) * app.tile_size())
	await press("menu")
	check(app.walking.is_empty(), "Menu failed to cancel navigation")
	await press("settings")
	await press("back")
	print(JSON.stringify({"mouse_test_failures": failures, "completed_events": app.core.state.completed}))
	quit(0 if failures.is_empty() else 1)
