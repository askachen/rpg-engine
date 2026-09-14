extends SceneTree
## Runs the actual UI with a renderer and saves screenshots; not a headless test.
var app: Control

func _initialize() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("res://test-results/" + name + ".png")

func run() -> void:
	app = load("res://engine/main.tscn").instantiate()
	root.add_child(app)
	await capture("title")
	app.core.new_game()
	app.show_game()
	await capture("game")
	for map_id in ["street", "shop", "garden"]:
		app.core.state.map = map_id
		app.core.state.position = app.core.content.maps[map_id].spawns.entry.duplicate()
		app.show_game()
		await capture(map_id)
	app.core.state.map = "shop"
	app.core.state.position = [18, 9]
	app.execute({"op": "interact", "target": "a_npc"})
	app.story.reveal()
	await capture("dialogue")
	app.execute({"op": "choose", "choice": "later"})
	app.core.new_game()
	app.show_game()
	app.show_settings()
	await capture("settings")
	app.close_modal()
	app.show_menu()
	await capture("menu")
	app.show_slots(true)
	await capture("save-slots")
	quit()
