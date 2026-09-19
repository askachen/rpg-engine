extends "res://engine/mouse_test.gd"

func start_film() -> void:
	Engine.time_scale = 30
	await target("mara_desk")
	await finish_lines()
	Engine.time_scale = 1
	await press("harbor_film")

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
	await start_film()
	var before: Dictionary = app.core.state.duplicate(true)
	var first = app.story.video_stage
	var deadline := Time.get_ticks_msec() + 7000
	while is_instance_valid(first) and Time.get_ticks_msec() < deadline:
		await process_frame
	check(not is_instance_valid(first) and app.story.cursor == 1, "Natural completion returns to next video exactly once")
	var stage = app.story.video_stage
	check(stage != null and stage.player.bus == "Master", "Video uses global audio bus")
	check(is_equal_approx(stage.player.volume,0.3), "Authored volume applied")
	await press("video_pause")
	var position_value: float = stage.player.stream_position
	await create_timer(0.25).timeout
	check(stage.player.paused and absf(stage.player.stream_position-position_value)<0.05, "Pause stops playback clock")
	check(absf(stage.frame.ratio-4.0/3.0)<0.01 and absf(stage.player.size.x/stage.player.size.y-4.0/3.0)<0.01, "4:3 video is letterboxed without stretching")
	var slider = app.story.controls.get_node("VideoVolume")
	await click(slider.get_global_rect().position + Vector2(slider.size.x*0.25,slider.size.y/2))
	check(absf(stage.player.volume-0.25)<0.06, "Mouse volume slider controls player")
	var key := InputEventKey.new()
	key.keycode = KEY_T
	key.pressed = true
	root.push_input(key,true)
	check(app.story.video_stage == stage and app.core.state == before, "World key cannot restart or mutate video event")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(not root.get_texture().get_image().get_pixel(960,300).is_equal_approx(Color.BLACK), "Actual video frame renders")
		root.get_texture().get_image().save_png("res://test-results/video-loop.png")
	await press("video_pause")
	deadline = Time.get_ticks_msec()+7000
	while stage.loops_completed==0 and Time.get_ticks_msec()<deadline:
		await process_frame
	check(stage.loops_completed>0 and app.story.cursor==1, "Loop restarts without advancing story")
	await press("story_cancel")
	check(not is_instance_valid(stage) and app.core.state==before and app.core.active_event=="", "Cancellation releases decoder and staged effects")
	await start_film()
	await press("video_skip")
	check(app.story.cursor==1, "Skip once moves to loop")
	await press("video_skip")
	check(app.story.cursor==2 and not is_instance_valid(app.story.video_stage), "Skip loop returns to ordinary dialogue")
	check(app.core.state==before, "Video completion does not grant event effects")
	await finish_lines()
	await press("harbor_chat_thanks")
	check(app.core.state.flags.get("chat_film",false) and app.core.state.completed.count("harbor_chat")==1, "Story commits once after video sequence")
	# A missing file must expose failure and still allow explicit skip.
	var missing = load("res://engine/story_video.gd").new()
	missing.setup({"path":"res://missing-video.ogv","loop":false,"volume":0.0})
	root.add_child(missing)
	check(missing.error != "", "Missing video reported")
	missing.complete("skipped")
	check(missing.done, "Failed video can be skipped")
	missing.queue_free()
	await process_frame
	print(JSON.stringify({"video_failures":failures}))
	quit(0 if failures.is_empty() else 1)
