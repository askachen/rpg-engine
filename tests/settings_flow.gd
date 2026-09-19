extends "res://engine/mouse_test.gd"
const Settings = preload("res://engine/player_settings.gd")

func run() -> void:
	app = load("res://engine/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	if "--verify-settings" in OS.get_cmdline_user_args():
		check(is_equal_approx(app.profile.music_volume,0.25),"Music setting survives process restart")
		check(app.profile.text_size == 36 and app.profile.text_speed == 10 and app.profile.auto_delay == 5,"Text settings survive process restart")
		check(app.profile.resolution == "1280x720","Resolution survives process restart")
		check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))),0.25),"Restart applies mixer values")
	else:
		var normalized := Settings.normalize({"volume":-5,"text_size":999,"text_speed":"wrong","resolution":"bad","fullscreen":7})
		check(normalized.volume == 0 and normalized.text_size == 36 and normalized.text_speed == 35 and normalized.resolution == "1920x1080" and not normalized.fullscreen,"Invalid settings have bounded defaults")
		await press("settings")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://test-results/settings-top.png")
		await press("fullscreen")
		check(app.profile.fullscreen,"Mouse enables saved fullscreen")
		if DisplayServer.get_name() != "headless": check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN,"Native window enters fullscreen")
		var fullscreen_button := find_button(app.overlay,app.t("fullscreen")+" ✓")
		await click(fullscreen_button.get_global_rect().get_center())
		check(not app.profile.fullscreen,"Mouse returns to windowed")
		if DisplayServer.get_name() != "headless": check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED,"Native window returns to windowed")
		var resolution_button := find_button(app.overlay,app.t("resolution")+": "+app.profile.resolution)
		await click(resolution_button.get_global_rect().get_center())
		check(app.profile.resolution == "2560x1440","Mouse changes resolution preset")
		var slider: HSlider = app.overlay.find_child("Setting_music_volume",true,false)
		var scroll: ScrollContainer = slider.get_parent().get_parent()
		scroll.ensure_control_visible(slider)
		await process_frame
		await click(slider.get_global_rect().position+Vector2(slider.size.x*0.25,20))
		check(absf(app.profile.music_volume-0.25)<0.03,"Mouse changes independent music volume")
		for key in ["volume","sfx_volume","voice_volume","text_size","text_speed","auto_delay"]:
			slider = app.overlay.find_child("Setting_"+key,true,false)
			var old_value: float = slider.value
			scroll.ensure_control_visible(slider)
			await process_frame
			await process_frame
			await click(slider.get_global_rect().position+Vector2(slider.size.x*0.7,20))
			check(slider.value != old_value and app.profile[key] == slider.value,"Mouse and scroll reach setting: "+key)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://test-results/settings-bottom.png")
		# Exact values below isolate persistence and playback behavior from slider pixel rounding.
		app.profile.music_volume = 0.25
		app.profile.sfx_volume = 0.0
		app.profile.voice_volume = 0.6
		app.profile.text_size = 36
		app.profile.text_speed = 10
		app.profile.auto_delay = 5.0
		app.profile.resolution = "1280x720"
		Settings.apply_audio(app.profile)
		Settings.apply_display(app.profile)
		app.save_profile()
		check(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")) and not AudioServer.is_bus_mute(AudioServer.get_bus_index("Voice")),"SFX mute does not mute voice")
		var count := AudioServer.bus_count
		Settings.apply_audio(app.profile)
		check(AudioServer.bus_count == count,"Repeated settings do not duplicate buses")
		app.close_modal()
		app.core.new_game()
		# Presentation-only fixture: a generated tone stands in for voice, no claimed narration.
		app.core.active_event = "a1"
		app.core.active_node = ""
		app.core.content.events.a1.sequence = [{"id":"voice_test","speaker":"a","text":"a1_text","voice":"res://games/demo/assets/coffee-ambience-v1.wav"},{"id":"after_voice","speaker":"a","text":"a1_text"}]
		app.show_game()
		var story = load("res://engine/dialogue_player.gd").new()
		story.setup(app,"a1")
		app.add_child(story)
		story.set_process(false)
		check(story.music.bus == "Music" and story.sound.bus == "SFX" and story.voice.bus == "Voice","Actual playback routes to separate buses")
		check(story.voice.playing,"Voice stream starts")
		story.paused = true
		story._process(0.1)
		check(story.voice.stream_paused,"History pauses voice")
		story.paused = false
		story._process(0.0)
		check(not story.voice.stream_paused,"Returning resumes voice")
		check(story.line_label.get_theme_font_size("font_size") == 36,"Dialogue uses chosen text size")
		story._process(0.2)
		check(story.line_label.visible_characters == 2,"Typing follows characters per second")
		story.reveal()
		story.auto = true
		story._process(6.0)
		check(story.cursor == 0,"Auto waits for voice even after delay")
		story.voice.stop()
		story.elapsed = 0
		story._process(4.0)
		check(story.cursor == 0,"Auto respects configured delay")
		story._process(1.1)
		check(story.cursor == 1 and not story.voice.playing,"Next line stops voice and advances after delay")
		var voice_player = story.voice
		story.queue_free()
		await process_frame
		check(not is_instance_valid(voice_player),"Closing presentation releases voice player")
	print(JSON.stringify({"settings_failures":failures}))
	quit(0 if failures.is_empty() else 1)
