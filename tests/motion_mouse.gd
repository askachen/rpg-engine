extends "res://engine/mouse_test.gd"

func run() -> void:
	Engine.time_scale = 1
	root.size = Vector2i(1920, 1080)
	app = load("res://engine/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await press("new")
	var hero: String = app.core.protagonist_id()
	var avatar: Dictionary = app.core.content.avatars[hero]
	for sample in [{"cell":Vector2(2,6),"direction":"up"}, {"cell":Vector2(2,8),"direction":"down"}, {"cell":Vector2(1,8),"direction":"left"}, {"cell":Vector2(2,8),"direction":"right"}]:
		await click(app.cell_to_screen(sample.cell))
		var guard := 0
		while (not app.walking.is_empty() or app.motion.remaining > 0) and guard < 500:
			await process_frame
			guard += 1
		check(guard < 500, "Walk did not stop")
		check(app.motion.facing.get(hero) == sample.direction, "Wrong movement facing")
		check(app.motion.image_spec(avatar, hero, false) == avatar.walk[sample.direction][1], "Idle pose did not retain direction")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://test-results/motion-" + sample.direction + ".png")
	var seen: Dictionary = {}
	await click(app.cell_to_screen(Vector2(11, 8)))
	while not app.walking.is_empty() or app.motion.remaining > 0:
		var spec = app.motion.image_spec(avatar, hero, app.motion.remaining > 0)
		if app.motion.remaining > 0: seen[JSON.stringify(spec)] = true
		await process_frame
	check(seen.size() >= 2, "Actual mouse movement never advanced sprite frames")
	# Normal mouse navigation to NPC turns both participants.
	Engine.time_scale = 30
	await target("mara_desk")
	check(app.motion.remaining == 0, "Interaction did not stop walking animation")
	var delta := Vector2i(14 - int(app.core.state.position[0]), 7 - int(app.core.state.position[1]))
	var expected = load("res://engine/actor_motion.gd").new()
	expected.face(hero, delta)
	expected.face("mara", -delta)
	check(app.motion.facing[hero] == expected.facing[hero] and app.motion.facing.mara == expected.facing.mara, "Interaction facing not reciprocal")
	# Clock behavior is deterministic independently of renderer FPS.
	var clock = load("res://engine/actor_motion.gd").new()
	clock.step(hero, Vector2i.RIGHT, 0.11, true)
	clock.tick(0.08, false)
	var walking = clock.image_spec(avatar, hero, true)
	clock.stop()
	clock.step(hero, Vector2i.RIGHT, 0.045, true)
	clock.tick(0.08, false)
	check(clock.image_spec(avatar, hero, true) != walking, "Dash did not accelerate frame clock")
	clock.step(hero, Vector2i.UP, 0.11, false)
	check(clock.remaining == 0 and clock.facing[hero] == "up", "Blocked movement should turn without walking")
	clock.step(hero, Vector2i.LEFT, 0.11, true)
	clock.tick(0.01, true)
	check(clock.remaining == 0, "Pause did not stop animation")
	check(clock.image_spec({"sprite": avatar.sprite}, hero, true) == avatar.sprite, "Legacy sprite fallback changed")
	print(JSON.stringify({"motion_failures": failures}))
	quit(0 if failures.is_empty() else 1)
