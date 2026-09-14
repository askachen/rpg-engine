extends SceneTree
var failures: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, reason: String) -> void:
	if not value: failures.append(reason)

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/" + name + ".png")

func has_text(node: Node, value: String) -> bool:
	if node is Label and node.text == value: return true
	for child in node.get_children():
		if has_text(child, value): return true
	return false

func run() -> void:
	var app = load("res://engine/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	check(app.core.tr_key("title", "unsupported_locale") == app.core.tr_key("title", app.core.default_language()), "Fallback language ignored")
	check(app.core.protagonist_id() == "traveler", "Protagonist override ignored")
	check(not app.core.content.avatars.has("player") and not app.core.content.visuals.has("characters"), "Fixture retained legacy names")
	check(has_text(app, "Amber Letters"), "Configured title missing")
	check(app.appearance.palette("panel") == Color("473449"), "Palette not applied")
	check(app.card_style().bg_color == Color("473449"), "UI ignored palette")
	check(app.theme.default_font.resource_path == "res://tests/fixtures/ui_font.tres", "Font resource not applied")
	var portrait: TextureRect = app.portrait("traveler", Vector2(100, 100))
	check(portrait.texture == app.art.texture("cast", 2), "Avatar used old sheet/index")
	portrait.free()
	check(app.art.resolve({"path": "res://games/demo/assets/characters-v1.png"}) is Texture2D, "Standalone image failed to load")
	await capture("theme-title")
	app.show_game()
	var before: Dictionary = app.core.state.duplicate(true)
	await capture("theme-world")
	check(app.core.state == before, "Renderer changed state")
	app.execute({"op": "interact", "target": "ivy_npc"})
	app.story.reveal()
	app.story.advance()
	app.story.select("accept")
	check(app.dialogue_log.back().speaker == "traveler", "Choice history hardcoded player")
	check("arrival" in app.core.state.completed, "Themed game could not progress")
	app.show_gallery()
	check(has_text(app, app.t("gallery")), "Gallery failed with renamed characters")
	print(JSON.stringify({"presentation_failures": failures}))
	quit(0 if failures.is_empty() else 1)
