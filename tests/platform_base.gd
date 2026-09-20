extends "res://engine/mouse_test.gd"
var request: Dictionary

func check(condition: bool, explanation: String) -> void:
	if not condition:
		failures.append(explanation)
		print("ACCEPTANCE FAILURE: "+explanation)

func configure() -> void:
	request = JSON.parse_string(FileAccess.get_file_as_string(OS.get_cmdline_user_args()[0]))
	root.content_scale_size = Vector2i(1920,1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	app = load("res://engine/main.tscn").instantiate()
	root.add_child(app)
	await settle()

func settle() -> void:
	for frame in range(6): await process_frame

func finish(report: Dictionary) -> void:
	report.ok = failures.is_empty()
	report.failures = failures
	report.display = DisplayServer.get_name()
	report.hardware = {"os":OS.get_name(),"cpu":OS.get_processor_name(),"threads":OS.get_processor_count(),"gpu":RenderingServer.get_video_adapter_name(),"godot":Engine.get_version_info().string}
	var file := FileAccess.open(request.output,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print(JSON.stringify({"ok":report.ok,"failures":failures,"report":request.output}))
	quit(0 if failures.is_empty() else 1)

func screenshot(name_value: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(str(request.directory).path_join(name_value+".png"))
