extends "res://engine/mouse_test.gd"

func capture(filename: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/" + filename + ".png")

func run() -> void:
	Engine.time_scale = 30
	root.size = Vector2i(1920,1080)
	app = load("res://engine/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await press("new")
	await target("locker_key_pickup")
	await target("harbor_locker")
	await press("use_item")
	await press("back")
	await target("mara_desk")
	app.story.set_process(false)
	var before: Dictionary = app.core.state.duplicate(true)
	var stage = app.story.visual_stage
	check(stage.actors.mara.size == Vector2(600,640), "Authored actor size")
	check(stage.actors.mara.position == Vector2(710,60), "Authored actor position")
	check(stage.get_node("Background").stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "Background preserves ratio")
	var clock: Dictionary = stage.clocks.mara
	var remaining: float = fposmod(5.1 - fposmod(clock.elapsed * 6.0, 8.0), 8.0) / 6.0
	stage.tick(remaining, false)
	check(clock.index == 5 and stage.actors.mara.texture == app.art.resolve({"sheet":"mara_expressions","index":1}), "Blink frame rendered")
	await capture("visual-blink")
	stage.tick(0.2,false)
	check(stage.actors.mara.texture == app.art.resolve({"sheet":"mara_expressions","index":0}), "Blink returns to open eyes")
	var paused_at: float = clock.elapsed
	await press("story_log")
	app.story._process(2.0)
	check(clock.elapsed == paused_at, "History pauses animation")
	await press("back")
	await press("story_hide")
	app.story._process(2.0)
	check(clock.elapsed == paused_at, "Hidden dialogue pauses animation")
	await capture("visual-background")
	await press("story_hide")
	app.story._process(0.2)
	check(clock.elapsed > paused_at, "Animation resumes")
	await press("story_cancel")
	check(not is_instance_valid(stage) and app.core.state == before, "Cancellation clears visuals without rewards")
	await target("mara_desk")
	await finish_lines()
	check(not is_instance_valid(app.story.visual_stage), "Choice screen clears line visuals")
	await press("harbor_chat_weather")
	app.story.set_process(false)
	stage = app.story.visual_stage
	check(stage.actors.is_empty() and stage.has_node("Background"), "Scenic CG suppresses default portrait")
	await capture("visual-cg")
	await press("story_next")
	await press("story_next")
	check(not is_instance_valid(stage), "Line replacement frees old stage")
	stage = app.story.visual_stage
	check(stage.actors.mara.position == Vector2(1090,160) and stage.actors.mara.size == Vector2(480,530), "Expression uses alternate position and scale")
	check(stage.actors.mara.texture == app.art.resolve({"sheet":"mara_expressions","index":2}), "Smile expression selected")
	await capture("visual-expression")
	await finish_lines()
	await press("harbor_chat_thanks")
	app.story.set_process(false)
	stage = app.story.visual_stage
	stage.tick(10.0,false)
	check(stage.clocks.mara.done and not stage.actors.mara.visible, "Finite animation hides on completion")
	check(app.core.state == before, "Animation completion does not submit rewards")
	await finish_lines()
	check(not is_instance_valid(stage) and app.core.state.flags.get("chat_weather",false), "Outro clears visual and commits story")
	await target("mara_desk")
	await finish_lines()
	await press("harbor_chat_work")
	await finish_lines()
	await press("harbor_chat_thanks")
	app.story.set_process(false)
	stage = app.story.visual_stage
	stage.tick(10.0,false)
	check(stage.clocks.mara.done and stage.actors.mara.visible and stage.clocks.mara.index == 7, "Finite animation holds last frame")
	var held = stage.actors.mara.texture
	stage.tick(10.0,false)
	check(stage.actors.mara.texture == held, "Completed animation remains on last frame")
	await finish_lines()
	check(app.core.state.flags.get("chat_work",false), "Work branch still completes")
	# Already-read skip disposes a looping visual immediately, without waiting for it.
	await target("mara_desk")
	app.story.set_process(false)
	stage = app.story.visual_stage
	app.story.skip = true
	app.story._process(0.01)
	await process_frame
	check(not is_instance_valid(stage) and app.story.cursor == app.story.lines.size(), "Read skip releases loop without hanging")
	await press("story_cancel")
	print(JSON.stringify({"visual_failures":failures}))
	quit(0 if failures.is_empty() else 1)
