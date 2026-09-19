extends "res://engine/mouse_test.gd"

func run() -> void:
	app = load("res://engine/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	if "--verify-gallery" not in OS.get_cmdline_user_args():
		await press("gallery")
		check(app.overlay.find_child("Gallery_signal_memory",true,false).disabled,"Locked entry disabled")
		check(app.overlay.find_child("Thumbnail_signal_memory",true,false).texture == null,"Locked thumbnail hidden")
		var locked_overlay = app.overlay
		app.gallery_view.show_card("signal_memory")
		check(app.overlay == locked_overlay,"Direct call cannot bypass gallery lock")
		await press("back")
		await press("new")
		# Setup follows the authored normal rules route; gallery interactions use mouse input below.
		var route: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://games/fog_harbor/tests/walkthrough.json"))
		for step in route.steps:
			if step.op in ["save","load","snapshot"]: continue
			var result: Dictionary = app.core.act(step)
			check(result.ok,"Authored route operation: "+str(step))
		app.show_game()
		check(app.profile.unlocked.size() == 2,"Completed conditions unlock both entries")
	else:
		check(app.profile.unlocked.size() == 2,"Unlocks survive fresh process")
		await press("new")
		check(app.core.state.completed.is_empty(),"Fresh run used for gallery independence")
	var before: Dictionary = app.core.state.duplicate(true)
	var profile_before: Dictionary = app.profile.duplicate(true)
	await press("menu")
	await press("gallery")
	await press("gallery_image")
	check(app.overlay.find_child("Gallery_signal_memory",true,false) != null and app.overlay.find_child("Gallery_letter_memory",true,false) == null,"Image filter excludes videos")
	await press("signal_memory")
	check(app.overlay.find_child("GalleryImage",true,false).texture != null,"CG opens in large viewer")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/gallery-cg.png")
	await press("back")
	await press("gallery_video")
	await press("letter_memory")
	var stage = app.overlay.find_child("GalleryVideo",true,false)
	check(stage != null and stage.player.is_playing(),"Gallery video starts")
	await press("video_pause")
	check(stage.player.paused,"Mouse pauses gallery video")
	var volume: HSlider = app.overlay.find_child("GalleryVolume",true,false)
	await click(volume.get_global_rect().position+Vector2(volume.size.x*0.3,20))
	check(absf(stage.player.volume-0.3)<0.06,"Mouse adjusts gallery video volume")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/gallery-video.png")
	await press("back")
	check(not is_instance_valid(stage),"Returning releases paused video")
	await press("letter_memory")
	stage = app.overlay.find_child("GalleryVideo",true,false)
	var deadline := Time.get_ticks_msec()+7000
	while not stage.done and Time.get_ticks_msec()<deadline: await process_frame
	check(stage.done,"Gallery video naturally completes")
	await press("gallery_replay")
	check(not is_instance_valid(stage),"Replay releases old player")
	stage = app.overlay.find_child("GalleryVideo",true,false)
	check(stage.player.is_playing(),"Replay creates active player")
	await press("back")
	await press("gallery_memory")
	check(app.overlay.find_children("Gallery_*","Button",true,false).is_empty(),"Empty category has no entries")
	await press("back")
	check(app.core.state == before and app.core.active_event == "","Gallery does not change current game")
	check(app.profile == profile_before,"Gallery playback does not mutate profile or read history")
	print(JSON.stringify({"gallery_failures":failures}))
	quit(0 if failures.is_empty() else 1)
