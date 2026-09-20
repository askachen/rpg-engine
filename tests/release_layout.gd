extends "res://engine/mouse_test.gd"

func run() -> void:
	app = load("res://engine/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	for language in ["zh_TW", "en"]:
		app.language = language
		app.profile.text_size = 36
		var key: String = app.core.content.events.opening.sequence[0].text
		app.core.content.locales[language][key] = ("這是一段用來檢查大字體捲動的長對話。" if language == "zh_TW" else "A long dialogue must remain readable without covering the mouse controls. ").repeat(100)
		app.start_new_game()
		app.story.reveal()
		for frame in range(8): await process_frame
		var scroll: ScrollContainer = app.story.find_child("DialogueScroll",true,false)
		check(scroll != null,"Dialogue scroll exists")
		check(scroll.get_parent().size.y <= 246,"Long text cannot grow beyond dialogue frame")
		check(scroll.get_v_scroll_bar().max_value > scroll.size.y,"Overflow is scrollable")
		check(app.story.controls.get_global_rect().end.y <= 1080,"Mouse controls stay visible")
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
		await process_frame
		check(scroll.scroll_vertical > 0,"Long text can be scrolled to the end")
		await press("story_cancel")
	print(JSON.stringify({"release_layout_failures":failures}))
	quit(0 if failures.is_empty() else 1)
