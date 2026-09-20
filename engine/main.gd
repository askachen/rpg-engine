extends Control

const Core = preload("res://engine/core.gd")
var core = Core.new()
const Slots = preload("res://engine/save_slots.gd")
var saves
var language := "zh_TW"
var screen := "title"
var message := ""
var panel: Control
var status: Label
var side: VBoxContainer
var overlay: Control
var debug_open := false
var walking: Array = []
var pending_target := ""
var walk_elapsed := 0.0
var dash_enabled := true
var dash_button: Button
const Art = preload("res://engine/art_library.gd")
var art = Art.new()
var avatar_time := 0.0
const Dialogue = preload("res://engine/dialogue_player.gd")
var story
var dialogue_log: Array = []
var profile: Dictionary = {"unlocked": [], "language": "zh_TW", "volume": 0.8}
const ORIGIN = Vector2(60, 180)
const TILE = 55.0
const Bootstrap = preload("res://engine/game_bootstrap.gd")
var profile_path := ""
const Appearance = preload("res://engine/presentation_theme.gd")
var appearance = Appearance.new()
const Profiles = preload("res://engine/profile_store.gd")
const Settings = preload("res://engine/player_settings.gd")
const World = preload("res://engine/world_renderer.gd")
var world = World.new()
const ActorMotion = preload("res://engine/actor_motion.gd")
var motion = ActorMotion.new()
const WorldSurface = preload("res://engine/world_surface.gd")
const WORLD_SIZE = Vector2(1320, 760)
var camera := Vector2.ZERO
var world_surface: Control
var transitioning := false
var transition_layer: ColorRect
var pointer_position := Vector2(-100, -100)
var collapsed_routes: Dictionary = {}
var quit_confirmation_open := false

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		pointer_position = get_global_transform_with_canvas().affine_inverse() * event.position

func update_camera() -> void:
	var area: Dictionary = core.content.maps[core.state.map]
	var extent := Vector2(area.width, area.height) * tile_size()
	var focus := (Vector2(core.state.position[0], core.state.position[1]) + Vector2(0.5, 0.5)) * tile_size()
	camera = Vector2(clampf(focus.x - WORLD_SIZE.x / 2, 0, maxf(0, extent.x - WORLD_SIZE.x)), clampf(focus.y - WORLD_SIZE.y / 2, 0, maxf(0, extent.y - WORLD_SIZE.y)))

func cell_to_screen(cell: Vector2) -> Vector2:
	return ORIGIN + (cell + Vector2(0.5, 0.5)) * tile_size() - camera

func screen_to_cell(point: Vector2) -> Vector2i:
	return Vector2i(((point - ORIGIN + camera) / tile_size()).floor())

func hovered_target() -> Dictionary:
	if screen != "game" or transitioning or is_instance_valid(overlay) or core.active_event != "": return {}
	var point := pointer_position
	if not Rect2(ORIGIN, WORLD_SIZE).has_point(point): return {}
	var cell := screen_to_cell(point)
	for target in core.map_objects():
		if Vector2i(int(target.position[0]), int(target.position[1])) == cell and not core.object_removed(target): return target
	return {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_tree().auto_accept_quit = false
	get_window().close_requested.connect(confirm_quit)
	if not core.load_content(Bootstrap.content_path()):
		push_error(core.load_error)
		return
	profile_path = Bootstrap.profile_path(str(core.content.id))
	saves = Slots.new(core)
	art.configure(core.content.get("visuals", {}))
	appearance.configure(core.content, art)
	theme = Theme.new()
	theme.default_font = appearance.font
	RenderingServer.set_default_clear_color(appearance.palette("background"))
	profile = Profiles.read(profile_path, core.default_language())
	language = str(profile.language)
	dash_enabled = bool(profile.dash)
	if language not in core.content.locales: language = core.default_language()
	Settings.apply_audio(profile)
	Settings.apply_display(profile)
	show_title()

func t(key: String) -> String:
	return core.tr_key(key, language)

func label(text: String, size: int = 18, color: Color = Color.TRANSPARENT) -> Label:
	return appearance.label(text, size, color)

func portrait(who: String, dimensions: Vector2) -> TextureRect:
	return appearance.portrait(who, dimensions)

func card_style() -> StyleBoxFlat:
	return appearance.card_style()

func button(text: String, action: Callable) -> Button:
	return appearance.button(text, action)

func clear_ui() -> void:
	for child in get_children():
		if child == transition_layer: continue
		remove_child(child)
		child.queue_free()
	overlay = null

func stack(parent: Node, position_value: Vector2, dimensions: Vector2) -> VBoxContainer:
	var node := VBoxContainer.new()
	node.position = position_value
	node.size = dimensions
	node.add_theme_constant_override("separation", 10)
	parent.add_child(node)
	return node

func show_title() -> void:
	cancel_walk()
	screen = "title"
	core.clear_event()
	clear_ui()
	var box := stack(self, Vector2(170, 150), Vector2(590, 750))
	box.add_child(label(t(appearance.title_text("eyebrow", "title")), 18, appearance.palette("accent")))
	box.add_child(label(t(appearance.title_text("title", "title")), 82))
	box.add_child(label(t(appearance.title_text("subtitle", "subtitle")), 19))
	box.add_child(label(" ", 12))
	box.add_child(button(t("new"), func(): core.new_game(); motion.reset(); dialogue_log.clear(); message = ""; show_game()))
	var continue_button := button(t("continue"), func():
		if saves.load_slot(saves.latest()): motion.reset(); show_game()
		else: show_notice(t("load_failed")))
	continue_button.disabled = saves.latest() < 0
	box.add_child(continue_button)
	box.add_child(button(t("load"), func(): show_slots(false)))
	box.add_child(button(t("gallery"), show_gallery))
	box.add_child(button(t("settings"), show_settings))
	box.add_child(button(t("credits"), show_credits))
	box.add_child(button(t("quit"), confirm_quit))
	var foot := label(t(appearance.title_text("chapter", "chapter")), 18, appearance.palette("muted"))
	foot.position = Vector2(170, 1005)
	add_child(foot)
	queue_redraw()

func show_game() -> void:
	sync_gallery_unlocks()
	screen = "game"
	clear_ui()
	update_camera()
	var window := Control.new()
	window.name = "WorldWindow"
	window.position = ORIGIN
	window.size = WORLD_SIZE
	window.clip_contents = true
	window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(window)
	world_surface = WorldSurface.new()
	world_surface.host = self
	world_surface.position = -ORIGIN - camera
	var area: Dictionary = core.content.maps[core.state.map]
	world_surface.size = Vector2(area.width, area.height) * tile_size() + ORIGIN
	world_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window.add_child(world_surface)
	var hero := portrait(core.protagonist_id(), Vector2(80, 100))
	hero.position = Vector2(60, 35)
	hero.size = Vector2(80, 100)
	add_child(hero)
	var heading := label(t(core.state.map), 30)
	heading.position = Vector2(162, 44)
	add_child(heading)
	var info := label("DAY %02d   /   %s     ·     %s %d" % [core.state.day, t(core.state.period), t("money"), core.state.money], 18, appearance.palette("success"))
	info.position = Vector2(162, 105)
	add_child(info)
	var menu_button := button(t("menu"), show_menu)
	menu_button.position = Vector2(1655, 44)
	menu_button.size.x = 205
	add_child(menu_button)
	dash_button = button(t("dash_on") if dash_enabled else t("dash_off"), toggle_dash)
	dash_button.position = Vector2(1440, 44)
	dash_button.size = Vector2(195, 56)
	add_child(dash_button)
	var wait_button := button(t("wait"), func(): execute({"op": "wait"}))
	wait_button.position = Vector2(1440, 110)
	wait_button.size = Vector2(420, 56)
	add_child(wait_button)
	var route_scroll := ScrollContainer.new()
	route_scroll.position = Vector2(1440, 195)
	route_scroll.size = Vector2(420, 745)
	add_child(route_scroll)
	side = VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 10)
	route_scroll.add_child(side)
	side.add_child(label(t("progress"), 29))
	for who in core.content.characters:
		var character: Dictionary = core.state.characters[who]
		var route: Dictionary = core.route_progress(who)
		var toggle := button(t(who) + (" ＋" if collapsed_routes.get(who,false) else " −"),func():
			collapsed_routes[who] = not collapsed_routes.get(who,false)
			show_game())
		toggle.name = "RouteToggle_"+who
		side.add_child(toggle)
		if collapsed_routes.get(who,false): continue
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", card_style())
		side.add_child(panel)
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation", 10)
		panel.add_child(body)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 15)
		body.add_child(row)
		row.add_child(portrait(who, Vector2(90, 110)))
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(details)
		details.add_child(label(t(who), 27, Color(core.content.characters[who].color)))
		details.add_child(label("%s %d / %d   ·   %s %d" % [t("route_progress"), route.completed, route.total, t("affection"), character.affection], 17))
		var progress := ProgressBar.new()
		progress.max_value = max(1, route.total)
		progress.value = route.completed
		progress.show_percentage = false
		progress.custom_minimum_size.y = 7
		details.add_child(progress)
		if route.complete:
			body.add_child(label("✓ " + t("complete"), 19))
		elif route.next_event != "":
			var event_id: String = route.next_event
			var event: Dictionary = core.content.events[event_id]
			body.add_child(label(t("next_event") + "  /  " + t(event.title), 19, appearance.palette("accent")))
			for check in core.checks(event.conditions):
				var detail := "%s %s: %s / %s" % [t(check.condition.kind), t(str(check.condition.get("id", ""))), str(check.actual), t(str(check.expected))]
				if check.condition.kind in ["flag", "completed"]:
					detail = t(str(check.condition.id))
				elif check.condition.kind == "stage": detail = t("stage_requirement") % [int(check.expected), int(check.actual)]
				elif check.condition.kind == "period": detail = t("period") + " · " + t(str(check.expected))
				var line := label(("✓ " if check.passed else "○ ") + detail, 17, appearance.palette("success") if check.passed else appearance.palette("warning"))
				line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				body.add_child(line)
	var inv := button(t("inventory"),show_inventory)
	inv.position = Vector2(60, 944)
	add_child(inv)
	status = label(message, 20, appearance.palette("warning"))
	status.position = Vector2(60, 1004)
	add_child(status)
	var help := label(t("help"), 17, appearance.palette("muted"))
	help.position = Vector2(60, 1046)
	add_child(help)
	var ending: String = core.current_ending()
	if ending != "":
		status.text = t(core.content.endings[ending].text)
	if is_instance_valid(transition_layer): move_child(transition_layer, get_child_count() - 1)
	queue_redraw()

func modal(title: String) -> VBoxContainer:
	cancel_walk()
	if is_instance_valid(overlay):
		remove_child(overlay)
		overlay.queue_free()
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var shade := ColorRect.new()
	shade.color = appearance.palette("shade")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(460, 85)
	scroll.size = Vector2(1000, 910)
	overlay.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 15)
	scroll.add_child(box)
	var heading := label(title, 30)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(heading)
	return box

func close_modal() -> void:
	if is_instance_valid(overlay):
		remove_child(overlay)
		overlay.queue_free()
	overlay = null

func show_notice(text: String) -> void:
	var box := modal(text)
	box.add_child(button(t("back"), close_modal))

func show_menu() -> void:
	var box := modal(t("menu"))
	box.add_child(button(t("back"), close_modal))
	box.add_child(button(t("save"), func(): show_slots(true)))
	box.add_child(button(t("load"), func(): show_slots(false)))
	box.add_child(button(t("wait"), func(): close_modal(); execute({"op": "wait"})))
	box.add_child(button(t("settings"), show_settings))
	box.add_child(button(t("gallery"), show_gallery))
	box.add_child(button(t("inventory"), show_inventory))
	box.add_child(button(t("credits"), show_credits))
	box.add_child(button(t("quit"), confirm_quit))
	if OS.is_debug_build():
		box.add_child(button(t("debug"), show_debug))
	box.add_child(button(t("home_return"), func():
		var confirm := modal(t("confirm_title"))
		confirm.add_child(button(t("yes"), show_title))
		confirm.add_child(button(t("no"), show_menu))))

func confirm_quit() -> void:
	if quit_confirmation_open: return
	quit_confirmation_open = true
	var active_story = story if is_instance_valid(story) else null
	var previous_pause := false
	var video_player = null
	var previous_video_pause := false
	if active_story != null:
		previous_pause = active_story.paused
		active_story.paused = true
		if is_instance_valid(active_story.video_stage):
			video_player = active_story.video_stage.player
			previous_video_pause = video_player.paused
			video_player.paused = true
	var box := modal(t("quit_confirm"))
	box.add_child(button(t("yes"),func(): get_tree().quit()))
	box.add_child(button(t("no"),func():
		quit_confirmation_open = false
		close_modal()
		if is_instance_valid(active_story): active_story.paused = previous_pause
		if is_instance_valid(video_player): video_player.paused = previous_video_pause))

func show_credits() -> void:
	var box := modal(t("credits"))
	for key in core.content.get("credits",["credits_empty"]):
		var entry := label(t(key),24)
		entry.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(entry)
	box.add_child(button(t("back"),close_modal))

var inventory_view = preload("res://engine/inventory_view.gd").new()

func show_inventory() -> void:
	inventory_view.setup(self)
	inventory_view.show_inventory()

func save_profile() -> void:
	profile.language = language
	if not Profiles.write(profile_path, profile): push_warning("Profile write failed: " + profile_path)

func slot_title(slot: int) -> String:
	return t("auto_slot") if slot == 0 else t("manual_slot") % slot

func show_slots(saving: bool) -> void:
	var box := modal(t("save") if saving else t("load"))
	box.add_child(label(t("choose_save_slot") if saving else t("choose_load_slot"), 19))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	box.add_child(grid)
	for slot in range(1, Slots.COUNT + 1):
		grid.add_child(slot_button(slot, saving))
	box.add_child(slot_button(0, saving))
	box.add_child(button(t("back"), close_modal))

func slot_button(slot: int, saving: bool) -> Button:
	var info: Dictionary = saves.details(slot)
	var summary := t("empty_slot")
	if info.exists:
		if not info.valid:
			summary = t("invalid_slot")
		else:
			var state: Dictionary = info.data.state
			var stamp := Time.get_datetime_string_from_unix_time(int(info.saved_at), true) + " UTC"
			summary = "%s  ·  DAY %d / %s\n%s" % [t(state.map), state.day, t(state.period), stamp]
	var entry := button(slot_title(slot) + "\n" + summary, func():
		if saving:
			if info.exists:
				var confirm := modal(t("overwrite_title") % slot_title(slot))
				confirm.add_child(label(t("overwrite_description"), 19))
				confirm.add_child(button(t("confirm_overwrite"), func(): write_slot(slot)))
				confirm.add_child(button(t("cancel"), func(): show_slots(true)))
			else: write_slot(slot)
		else:
			if saves.load_slot(slot):
				motion.reset()
				message = t("loaded") + " · " + slot_title(slot)
				show_game()
			else: show_notice(t("load_failed")))
	entry.name = "slot_%d" % slot
	entry.alignment = HORIZONTAL_ALIGNMENT_LEFT
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.custom_minimum_size = Vector2(475, 135)
	entry.disabled = slot == 0 if saving else not info.valid
	return entry

func write_slot(slot: int) -> void:
	message = (t("saved") + " · " + slot_title(slot)) if saves.save(slot) else t("save_failed")
	show_game()

func show_debug() -> void:
	var box := modal(t("debug"))
	box.add_child(label(JSON.stringify(core.state, "  "), 14))
	var diagnostics: Dictionary = {}
	for who in core.content.characters: diagnostics[who] = core.event_candidates(who)
	box.add_child(label(JSON.stringify({"event_candidates": diagnostics}, "  "), 14))
	box.add_child(button(t("back"), close_modal))

func show_settings() -> void:
	var box := modal(t("settings"))
	box.add_child(label(t("language")))
	box.add_child(button(str(core.content.get("locale_names", {}).get(language, language)), func():
		var locales: Array = core.content.locales.keys()
		language = str(locales[(locales.find(language) + 1) % locales.size()])
		save_profile()
		if screen == "title": show_title()
		else: show_game()
		show_settings()))
	box.add_child(button(t("fullscreen") + (" ✓" if profile.fullscreen else ""), func():
		profile.fullscreen = not profile.fullscreen
		Settings.apply_display(profile)
		save_profile()
		show_settings()))
	box.add_child(button(t("resolution") + ": " + profile.resolution, func():
		var ids: Array = []
		for dimensions in Settings.RESOLUTIONS: ids.append("%dx%d" % [dimensions.x,dimensions.y])
		profile.resolution = ids[(ids.find(profile.resolution)+1)%ids.size()]
		Settings.apply_display(profile)
		save_profile()
		show_settings()))
	for key in Settings.RANGES: settings_slider(box,key)
	var preview := label(t("text_preview"),int(profile.text_size))
	preview.name = "TextPreview"
	preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(preview)
	var hint := label(t("settings_hint"),18)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	box.add_child(button(t("back"), close_modal))

func settings_slider(box: VBoxContainer, key: String) -> void:
	var heading := label(t(key) + ": " + str(profile[key]),22)
	box.add_child(heading)
	var slider := HSlider.new()
	slider.name = "Setting_" + key
	slider.custom_minimum_size.y = 40
	slider.min_value = Settings.RANGES[key][0]
	slider.max_value = Settings.RANGES[key][1]
	slider.step = 1.0 if key in ["text_size","text_speed"] else 0.1 if key == "auto_delay" else 0.01
	slider.value = profile[key]
	slider.value_changed.connect(func(value):
		profile[key] = value
		heading.text = t(key) + ": " + str(snappedf(value,0.01))
		if key == "text_size":
			var preview := box.find_child("TextPreview",true,false)
			if preview != null: preview.add_theme_font_size_override("font_size",int(value))
		Settings.apply_audio(profile)
		save_profile())
	box.add_child(slider)

var gallery_view = preload("res://engine/gallery_view.gd").new()

func show_gallery() -> void:
	gallery_view.setup(self)
	gallery_view.show_list()

func sync_gallery_unlocks() -> void:
	if core.active_event != "": return
	var changed := false
	for id in core.content.get("gallery", {}):
		if core.satisfied(core.content.gallery[id].conditions) and id not in profile.unlocked:
			profile.unlocked.append(id)
			changed = true
	if changed: save_profile()

func execute(command: Dictionary) -> void:
	if transitioning: return
	if command.get("op") == "interact":
		for target in core.map_objects():
			if target.id == command.get("target") and target.kind == "exit" and core.adjacent(target.position) and core.target_visible(target):
				await change_map(command)
				return
	execute_immediate(command)

func change_map(command: Dictionary) -> void:
	transitioning = true
	cancel_walk()
	transition_layer = ColorRect.new()
	transition_layer.name = "MapTransition"
	transition_layer.color = Color(0, 0, 0, 0)
	transition_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transition_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	transition_layer.z_index = 100
	add_child(transition_layer)
	var fade := create_tween()
	fade.tween_property(transition_layer, "color:a", 1.0, 0.18)
	await fade.finished
	execute_immediate(command)
	var reveal := create_tween()
	reveal.tween_property(transition_layer, "color:a", 0.0, 0.18)
	await reveal.finished
	transition_layer.queue_free()
	transition_layer = null
	transitioning = false

func execute_immediate(command: Dictionary) -> void:
	if command.get("op") == "interact":
		for target in core.map_objects():
			if target.id == command.get("target") and core.adjacent(target.position):
				var delta := Vector2i(int(target.position[0] - core.state.position[0]), int(target.position[1] - core.state.position[1]))
				motion.face(core.protagonist_id(), delta)
				if target.kind == "npc": motion.face(target.character, -delta)
	if is_instance_valid(story):
		remove_child(story)
		story.queue_free()
		story = null
	cancel_walk()
	var response: Dictionary = core.act(command)
	if command.get("op") == "move":
		motion.step(core.protagonist_id(), Vector2i(command.dx, command.dy), movement_interval(), response.ok)
	message = t(response.message)
	show_game()
	match response.message:
		"inspected": show_notice(t(response.text))
		"item_required":
			var requirement: Dictionary = response.requirement
			var box := modal(t("item_required"))
			box.add_child(label("%s × %d" % [t(requirement.id), requirement.count], 24))
			box.add_child(label(t("item_consumed") if requirement.consume else t("item_kept"), 20))
			var use := button(t("use_item"), func(): execute({"op": "interact", "target": response.target, "item": requirement.id}))
			use.disabled = core.state.inventory.get(requirement.id, 0) < requirement.count
			box.add_child(use)
			box.add_child(button(t("back"), close_modal))
		"event", "event_branch":
			story = Dialogue.new()
			story.setup(self, response.event)
			add_child(story)
		"smalltalk": show_notice(t("smalltalk"))
		"shop":
			inventory_view.setup(self)
			inventory_view.show_shop(response.shop)
		"event_completed":
			save_profile()
			if not saves.save(0): message = t("save_failed"); status.text = message
	# Failed terminal effects keep the current node available for another choice/cancel.
	if not response.ok and core.active_event != "":
		story = Dialogue.new()
		story.setup(self, core.active_event)
		add_child(story)

func cancel_walk() -> void:
	motion.stop()
	walking.clear()
	pending_target = ""
	walk_elapsed = 0.0
	queue_redraw()

func tile_size() -> float:
	return float(core.content.maps[core.state.map].get("cell_size", TILE))

func movement_interval() -> float:
	return 0.045 if dash_enabled or Input.is_key_pressed(KEY_SHIFT) else 0.11

func toggle_dash() -> void:
	dash_enabled = not dash_enabled
	profile.dash = dash_enabled
	save_profile()
	if is_instance_valid(dash_button):
		dash_button.text = t("dash_on") if dash_enabled else t("dash_off")

func _unhandled_input(event: InputEvent) -> void:
	if transitioning or screen != "game" or is_instance_valid(overlay) or core.active_event != "":
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_walk()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
			if not Rect2(ORIGIN, WORLD_SIZE).has_point(local): return
			var cell := screen_to_cell(local)
			var area: Dictionary = core.content.maps[core.state.map]
			if cell.x >= 0 and cell.y >= 0 and cell.x < area.width and cell.y < area.height:
				click_cell(cell)
				get_viewport().set_input_as_handled()

func click_cell(cell: Vector2i) -> void:
	if transitioning or screen != "game" or is_instance_valid(overlay) or core.active_event != "": return
	cancel_walk()
	for target in core.map_objects():
		if Vector2i(int(target.position[0]), int(target.position[1])) == cell and not core.object_removed(target):
			pending_target = target.id
			break
	var plan: Dictionary = core.path_to(cell, pending_target != "")
	if not plan.ok:
		cancel_walk()
		message = t("no_path")
		status.text = message
		return
	walking = plan.path
	walk_elapsed = movement_interval()
	queue_redraw()

func _process(delta: float) -> void:
	avatar_time += delta
	motion.tick(delta, transitioning or screen != "game" or is_instance_valid(overlay) or core.active_event != "")
	if is_instance_valid(world_surface): world_surface.queue_redraw()
	if transitioning: return
	if screen != "game" or is_instance_valid(overlay) or core.active_event != "": return
	if not walking.is_empty():
		walk_elapsed += delta
		var interval := movement_interval()
		if walk_elapsed < interval: return
		walk_elapsed = minf(walk_elapsed - interval, interval)
		var next: Vector2i = walking.pop_front()
		var direction := next - Vector2i(int(core.state.position[0]), int(core.state.position[1]))
		var response: Dictionary = core.act({"op": "move", "dx": direction.x, "dy": direction.y})
		motion.step(core.protagonist_id(), direction, interval, response.ok)
		if not response.ok:
			cancel_walk()
			message = t(response.message)
		show_game()
	if walking.is_empty() and pending_target != "":
		var target := pending_target
		pending_target = ""
		execute({"op": "interact", "target": target})

func _unhandled_key_input(event: InputEvent) -> void:
	if transitioning: return
	if core.active_event != "": return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if screen != "game": return
	if event.keycode == KEY_SHIFT: return
	if is_instance_valid(overlay):
		if event.keycode == KEY_ESCAPE and core.active_event == "": close_modal()
		return
	cancel_walk()
	match event.keycode:
		KEY_UP, KEY_W: execute({"op": "move", "dx": 0, "dy": -1})
		KEY_DOWN, KEY_S: execute({"op": "move", "dx": 0, "dy": 1})
		KEY_LEFT, KEY_A: execute({"op": "move", "dx": -1, "dy": 0})
		KEY_RIGHT, KEY_D: execute({"op": "move", "dx": 1, "dy": 0})
		KEY_T: execute({"op": "wait"})
		KEY_ESCAPE: show_menu()
		KEY_E, KEY_ENTER:
			for target in core.map_objects():
				if core.adjacent(target.position) and not core.object_removed(target):
					execute({"op": "interact", "target": target.id})
					break
		KEY_F3:
			if OS.is_debug_build():
				show_debug()

func _draw() -> void:
	if core.content.is_empty(): return
	if screen == "title": appearance.draw_title(self)
