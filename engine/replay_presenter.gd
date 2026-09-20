extends RefCounted
## A narrow presentation adapter: no live core/profile/save-slot references are exposed.
var host
var gallery
var core
var profile: Dictionary
var language: String
var dialogue_log: Array = []
var art
var appearance
var story

func start(owner_app, gallery_view, card_id: String) -> void:
	host = owner_app
	gallery = gallery_view
	core = host.core.replay_session(card_id,host.profile.unlocked)
	if core == null:
		gallery.replay = null
		return
	profile = host.profile.duplicate(true)
	language = host.language
	art = host.art
	appearance = host.appearance
	host.cancel_walk()
	host.close_modal()
	show_story()

func show_story() -> void:
	story = preload("res://engine/dialogue_player.gd").new()
	story.name = "GalleryEventReplay"
	story.setup(self,core.active_event)
	host.add_child(story)

func execute(command: Dictionary) -> void:
	var response: Dictionary = core.act(command)
	if is_instance_valid(story):
		host.remove_child(story)
		story.queue_free()
		story = null
	if response.ok and response.message == "event_branch":
		show_story()
	else:
		core.clear_event()
		host.close_modal()
		gallery.replay = null
		gallery.show_list(gallery.filter_kind)

func save_profile() -> void:
	pass # Read markers are isolated in the copied profile.

func t(key: String) -> String:
	return core.tr_key(key,language)

func portrait(who: String, dimensions: Vector2) -> TextureRect:
	return host.portrait(who,dimensions)

func card_style() -> StyleBoxFlat:
	return host.card_style()

func label(text: String, size: int = 18, color: Color = Color.TRANSPARENT) -> Label:
	return host.label(text,size,color)

func button(text: String, action: Callable) -> Button:
	return host.button(text,action)

func modal(title: String) -> VBoxContainer:
	return host.modal(title)

func close_modal() -> void:
	host.close_modal()
