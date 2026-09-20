extends "res://tests/platform_base.gd"
const SIZES = [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440),Vector2i(3840,2160),Vector2i(1920,1200),Vector2i(2560,1080)]
var cases: Array = []

func physical_click(point: Vector2) -> void:
	# Native pixel input: let Godot invert its real letterbox/stretch transform.
	var physical := root.get_final_transform() * point
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = physical
		event.global_position = physical
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,false)
	await settle()

func visible_button(key: String) -> Button:
	return find_button(app.overlay if is_instance_valid(app.overlay) else app,app.t(key))

func press_pixel(key: String) -> void:
	var button := visible_button(key)
	check(button != null,"Missing "+key)
	if button == null: return
	var parent := button.get_parent()
	while parent != null:
		if parent is ScrollContainer: parent.ensure_control_visible(button)
		parent = parent.get_parent()
	await settle()
	var bounds := button.get_global_rect()
	check(Rect2(0,0,1920,1080).encloses(bounds),"Button outside logical viewport: "+key)
	await physical_click(bounds.get_center())

func run() -> void:
	await configure()
	# These model the physical pixel sizes of 100/125/150/200% Windows logical windows.
	# They do not change the user's desktop DPI settings.
	for dimensions in ([SIZES[0],SIZES[5]] if request.get("quick",false) else SIZES):
		for dpi in ([1.0,2.0] if request.get("quick",false) else [1.0,1.25,1.5,2.0]):
			root.size = Vector2i(Vector2(dimensions)*dpi)
			await settle()
			check(root.size == Vector2i(Vector2(dimensions)*dpi),"Requested physical size was clamped")
			for locale in ["zh_TW","en"]:
				for font_size in ([36] if request.get("quick",false) else [22,36]):
					var before := failures.size()
					app.language = locale
					app.profile.text_size = font_size
					app.show_title()
					await settle()
					await press_pixel("settings")
					check(is_instance_valid(app.overlay),"Settings physical click failed")
					await press_pixel("back")
					check(not is_instance_valid(app.overlay),"Settings return failed")
					var key: String = app.core.content.events.opening.sequence[0].text
					app.core.content.locales[locale][key] = ("長篇對話仍須能捲動閱讀，選項與控制必須可操作。" if locale == "zh_TW" else "Long translated dialogue must remain readable with every mouse control reachable. ").repeat(45)
					app.core.content.locales[locale].accept = ("這個選項包含很長的說明文字，仍不可遮住其他選項。" if locale == "zh_TW" else "An unusually long translated choice must wrap and keep the following choice accessible. ").repeat(20)
					await press_pixel("new")
					app.story.reveal()
					await settle()
					var scroll: ScrollContainer = app.story.find_child("DialogueScroll",true,false)
					check(scroll.get_parent().size.y <= 246,"Long dialogue pushes controls offscreen")
					check(scroll.get_v_scroll_bar().max_value > scroll.size.y,"Long text has no scroll range")
					scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
					await settle()
					check(scroll.scroll_vertical > 0,"Long text end unreachable")
					check(Rect2(0,0,1920,1080).encloses(app.story.controls.get_global_rect()),"Story controls overflow")
					if dpi == 1.0 and font_size == 36: await screenshot("%dx%d-%s"%[dimensions.x,dimensions.y,locale])
					await press_pixel("story_next")
					await press_pixel("later")
					check(app.core.active_event == "","Last choice physical click failed after long choice")
					if app.core.active_event != "":
						await screenshot("failed-choice")
						finish({"cases":cases,"performance_verified":false})
						return
					await press_pixel("menu")
					await press_pixel("save")
					var last: Button = app.overlay.find_child("slot_6",true,false)
					check(last != null,"Last manual save slot missing")
					await physical_click(last.get_global_rect().get_center())
					if is_instance_valid(app.overlay): await press_pixel("confirm_overwrite")
					check(app.saves.details(6).valid,"Save physical click failed")
					app.show_gallery()
					await press_pixel("back")
					check(not is_instance_valid(app.overlay),"Gallery return failed")
					cases.append({"resolution":[dimensions.x,dimensions.y],"dpi_model":dpi,"physical":[root.size.x,root.size.y],"locale":locale,"font":font_size,"ok":failures.size()==before})
	finish({"cases":cases,"dpi_scope":"physical pixel model; native DPI awareness and current-monitor input are checked separately; no desktop DPI changes","performance_verified":false})
