extends "res://engine/mouse_test.gd"

func run() -> void:
	app = load("res://engine/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await press("new")
	for map_id in ["room", "architecture", "utility"]:
		# Rendering fixture only; ordinary movement/exit behavior is tested by walkthrough.json.
		app.core.state.map = map_id
		app.core.state.position = [12, 15]
		app.show_game()
		await process_frame
		await process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://test-results/showroom_"+map_id+".png")
	print(JSON.stringify({"showroom_failures":failures}))
	quit(0 if failures.is_empty() else 1)
