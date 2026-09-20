extends RefCounted
## Read-only presentation of profile unlocks. No core commands or rewards.
var app
var filter_kind := "all"
var replay

func setup(owner_app) -> void:
	app = owner_app

func show_list(kind: String = "all") -> void:
	filter_kind = kind
	var box: VBoxContainer = app.modal(app.t("gallery"))
	var filters := HBoxContainer.new()
	box.add_child(filters)
	for value in ["all","memory","image","video"]:
		filters.add_child(app.button(app.t("gallery_"+value),func(): show_list(value)))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation",20)
	grid.add_theme_constant_override("v_separation",20)
	box.add_child(grid)
	var shown := 0
	for id in app.core.content.get("gallery",{}):
		var card: Dictionary = app.core.content.gallery[id]
		var media: Dictionary = card.get("media",{})
		if kind != "all" and media.get("kind","memory") != kind: continue
		shown += 1
		var tile := VBoxContainer.new()
		tile.custom_minimum_size.x = 470
		grid.add_child(tile)
		var unlocked: bool = id in app.profile.unlocked
		var picture := TextureRect.new()
		picture.name = "Thumbnail_"+id
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.custom_minimum_size = Vector2(470,240)
		if unlocked:
			if not media.is_empty(): picture.texture = load(media.thumbnail)
			else:
				var portrait: TextureRect = app.portrait(card.character,Vector2(470,240))
				picture.texture = portrait.texture
				portrait.free()
		tile.add_child(picture)
		var entry: Button = app.button(app.t(card.title) if unlocked else app.t("locked"),func(): show_card(id))
		entry.name = "Gallery_"+id
		entry.disabled = not unlocked
		tile.add_child(entry)
	if shown == 0: box.add_child(app.label(app.t("gallery_no_entries"),22))
	box.add_child(app.button(app.t("back"),app.close_modal))

func show_card(id: String) -> void:
	# Enforce lock even if called without using the disabled list button.
	if id not in app.profile.unlocked or not app.core.content.get("gallery",{}).has(id): return
	var card: Dictionary = app.core.content.gallery[id]
	if card.has("event"):
		replay = preload("res://engine/replay_presenter.gd").new()
		replay.start(app, self, id)
		return
	var media: Dictionary = card.get("media",{})
	if media.is_empty():
		var box: VBoxContainer = app.modal(app.t(card.title))
		box.add_child(app.portrait(card.character,Vector2(450,500)))
		var quote: Label = app.label(app.t(card.text),int(app.profile.text_size))
		quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(quote)
		box.add_child(app.button(app.t("back"),func(): show_list(filter_kind)))
		return
	var unused: VBoxContainer = app.modal(app.t(card.title))
	unused.hide()
	var matte := ColorRect.new()
	matte.color = Color.BLACK
	matte.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	app.overlay.add_child(matte)
	var stage: Control
	if media.kind == "image":
		var picture := TextureRect.new()
		picture.name = "GalleryImage"
		picture.texture = load(media.path)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.position = Vector2(80,50)
		picture.size = Vector2(1760,850)
		app.overlay.add_child(picture)
	else:
		stage = preload("res://engine/story_video.gd").new()
		stage.name = "GalleryVideo"
		stage.setup({"path":media.path,"loop":false,"volume":1.0})
		app.overlay.add_child(stage)
	var footer := ColorRect.new()
	footer.color = Color(0,0,0,0.92)
	footer.position = Vector2(0,900)
	footer.size = Vector2(1920,180)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	app.overlay.add_child(footer)
	var controls := HBoxContainer.new()
	controls.position = Vector2(80,975)
	controls.add_theme_constant_override("separation",20)
	app.overlay.add_child(controls)
	controls.add_child(app.button(app.t("back"),func(): show_list(filter_kind)))
	if stage != null:
		controls.add_child(app.button(app.t("gallery_replay"),func(): show_card(id)))
		controls.add_child(app.button(app.t("video_pause"),func(): stage.player.paused = not stage.player.paused))
		var volume := HSlider.new()
		volume.name = "GalleryVolume"
		volume.custom_minimum_size = Vector2(280,48)
		volume.min_value = 0
		volume.max_value = 1
		volume.step = 0.01
		volume.value = 1
		volume.value_changed.connect(func(value): stage.player.volume = value)
		controls.add_child(app.label(app.t("video_volume"),22))
		controls.add_child(volume)
	var caption: Label = app.label(app.t(card.title)+" — "+app.t(card.text),24)
	caption.position = Vector2(80,910)
	caption.size = Vector2(1760,60)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	app.overlay.add_child(caption)
	if stage != null:
		stage.failed.connect(func(): caption.text = app.t("gallery_failed"))
		if stage.error != "": caption.text = app.t("gallery_failed")
