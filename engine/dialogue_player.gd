extends Control
## Presentation never applies rewards. Exactly one choice is committed on finish.
var app
var event_id: String
var event: Dictionary
var lines: Array = []
var cursor := 0
var chosen := ""
var finished := false
var auto := false
var skip := false
var paused := false
var hidden_box := false
var elapsed := 0.0
var visible_count := 0.0
var was_read := false
var line_label: Label
var body: VBoxContainer
var controls: HBoxContainer
var read_ids: Array
var music: AudioStreamPlayer
var sound: AudioStreamPlayer
var music_path := ""

func setup(owner_app, id: String) -> void:
	app = owner_app
	event_id = id
	event = app.core.content.events[id]
	lines = event.get("sequence", [{"id": id + "_legacy", "text": event.text, "speaker": event.character}]).duplicate(true)
	read_ids = app.profile.get("read_lines", []).duplicate()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	music = AudioStreamPlayer.new()
	sound = AudioStreamPlayer.new()
	add_child(music)
	add_child(sound)
	music.finished.connect(func():
		if not finished and music_path != "": music.play())
	show_line()

func line_id() -> String:
	return event_id + ":" + str(lines[cursor].id) + ":" + app.language + ":" + app.t(lines[cursor].text)

func clear() -> void:
	for child in get_children():
		if child is AudioStreamPlayer: continue
		remove_child(child)
		child.queue_free()

func show_line() -> void:
	clear()
	elapsed = 0.0
	visible_count = 0.0
	paused = false
	hidden_box = false
	var shade := ColorRect.new()
	shade.color = app.appearance.palette("shade")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	if cursor < lines.size():
		var line: Dictionary = lines[cursor]
		if line.has("bgm") and line.bgm != music_path:
			music_path = line.bgm
			music.stop()
			if music_path != "":
				music.stream = load(music_path)
				music.volume_db = -18.0
				music.play()
		if line.has("sfx"):
			sound.stream = load(line.sfx)
			sound.volume_db = -12.0
			sound.play()
		if line.has("background"):
			var bg := TextureRect.new()
			bg.texture = load(line.background)
			bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			add_child(bg)
		var who: String = line.get("speaker", event.character)
		var portrait: TextureRect = app.portrait(who, Vector2(500, 660))
		portrait.position = Vector2(710, 70)
		portrait.size = Vector2(500, 660)
		add_child(portrait)
		if line.has("portrait"):
			portrait.texture = load(line.portrait)
		portrait.modulate.a = 0.0
		create_tween().tween_property(portrait, "modulate:a", 1.0, 0.2)
		was_read = line_id() in read_ids
	var panel := PanelContainer.new()
	panel.position = Vector2(150, 700)
	panel.size = Vector2(1620, 245)
	panel.add_theme_stylebox_override("panel", app.card_style())
	panel.gui_input.connect(func(input):
		if input is InputEventMouseButton and input.pressed and input.button_index == MOUSE_BUTTON_LEFT:
			advance())
	add_child(panel)
	body = VBoxContainer.new()
	panel.add_child(body)
	if cursor < lines.size():
		var line: Dictionary = lines[cursor]
		body.add_child(app.label(app.t(line.get("speaker", event.character)), 28))
		line_label = app.label(app.t(line.text), 28)
		line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line_label.custom_minimum_size.y = 110
		line_label.visible_characters = 0
		body.add_child(line_label)
	else:
		line_label = null
		body.add_child(app.label(app.t(event.title), 26))
		for choice in event.choices:
			var option: Button = app.button(app.t(choice.text), func(): select(choice.id))
			option.disabled = not app.core.satisfied(choice.get("conditions", []))
			body.add_child(option)
	controls = HBoxContainer.new()
	controls.position = Vector2(150, 975)
	controls.add_theme_constant_override("separation", 18)
	add_child(controls)
	if cursor < lines.size():
		controls.add_child(app.button(app.t("story_next"), advance))
		controls.add_child(app.button(app.t("story_auto"), func(): auto = not auto; skip = false; update_controls()))
		controls.add_child(app.button(app.t("story_skip"), func(): skip = not skip; auto = false; update_controls()))
	controls.add_child(app.button(app.t("story_log"), show_log))
	controls.add_child(app.button(app.t("story_hide"), func(): hidden_box = not hidden_box; body.get_parent().visible = not hidden_box))
	update_controls()

func update_controls() -> void:
	for child in controls.get_children():
		if child.text.begins_with(app.t("story_auto")): child.text = app.t("story_auto") + (" ✓" if auto else "")
		if child.text.begins_with(app.t("story_skip")): child.text = app.t("story_skip") + (" ✓" if skip else "")

func reveal() -> void:
	if not is_instance_valid(line_label): return
	visible_count = line_label.text.length()
	line_label.visible_characters = -1
	if line_id() not in read_ids:
		read_ids.append(line_id())
		app.profile.read_lines = read_ids.duplicate()
		app.save_profile()

func advance() -> void:
	if finished or paused or hidden_box or cursor >= lines.size(): return
	if line_label.visible_characters != -1:
		reveal()
		return
	app.dialogue_log.append({"speaker": lines[cursor].get("speaker", event.character), "text": lines[cursor].text})
	cursor += 1
	if cursor >= lines.size() and chosen != "":
		commit()
	else: show_line()

func select(id: String) -> void:
	if finished or cursor < lines.size() or chosen != "": return
	for choice in event.choices:
		if choice.id != id: continue
		if not app.core.satisfied(choice.get("conditions", [])): return
		chosen = id
		app.dialogue_log.append({"speaker": app.core.protagonist_id(), "text": choice.text})
		if choice.get("cancel", false):
			commit()
		else:
			lines = choice.get("sequence", []).duplicate(true)
			cursor = 0
			if lines.is_empty(): commit()
			else: show_line()
		return

func commit() -> void:
	if finished: return
	finished = true
	app.execute({"op": "choose", "choice": chosen})

func _process(delta: float) -> void:
	if is_instance_valid(music):
		music.stream_paused = paused or hidden_box
		sound.stream_paused = paused or hidden_box
	if finished or paused or hidden_box or not is_instance_valid(line_label): return
	if line_label.visible_characters != -1:
		visible_count += delta * 35.0
		line_label.visible_characters = int(visible_count)
		if visible_count >= line_label.text.length(): reveal()
	else: elapsed += delta
	if skip and was_read:
		reveal()
		advance()
	elif auto and elapsed >= 1.4:
		advance()

func show_log() -> void:
	paused = true
	var box: VBoxContainer = app.modal(app.t("story_log"))
	for entry in app.dialogue_log:
		var text: Label = app.label(app.t(entry.speaker) + "：" + app.t(entry.text), 22)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(text)
	box.add_child(app.button(app.t("back"), func(): app.close_modal(); paused = false))
