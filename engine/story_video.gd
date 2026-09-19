extends Control
signal completed(reason: String)
signal failed
var spec: Dictionary
var player: VideoStreamPlayer
var frame: AspectRatioContainer
var done := false
var error := ""
var loops_completed := 0
var startup_seconds := 0.0

func setup(value: Dictionary) -> void:
	spec = value

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var matte := ColorRect.new()
	matte.color = Color.BLACK
	matte.mouse_filter = Control.MOUSE_FILTER_IGNORE
	matte.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(matte)
	frame = AspectRatioContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.stretch_mode = AspectRatioContainer.STRETCH_FIT
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	player = VideoStreamPlayer.new()
	player.expand = true
	player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player.volume = spec.volume
	player.bus = "Master"
	frame.add_child(player)
	player.finished.connect(playback_finished)
	if not ResourceLoader.exists(spec.path):
		fail("Missing video: " + spec.path)
		return
	var stream = load(spec.path)
	if not stream is VideoStreamTheora:
		fail("Expected Theora video: " + spec.path)
		return
	player.stream = stream
	player.play()

func _process(delta: float) -> void:
	if done or error != "" or not is_instance_valid(player): return
	var texture := player.get_video_texture()
	if texture != null and texture.get_height() > 0:
		frame.ratio = float(texture.get_width()) / texture.get_height()
	elif not player.paused:
		startup_seconds += delta
		if startup_seconds > 3.0: fail("Video did not produce a frame: " + spec.path)

func playback_finished() -> void:
	if done or error != "": return
	if spec.loop:
		loops_completed += 1
		player.play()
	else: complete("finished")

func complete(reason: String = "skipped") -> void:
	if done: return
	done = true
	if is_instance_valid(player): player.stop()
	completed.emit(reason)

func fail(message: String) -> void:
	error = message
	if is_instance_valid(player): player.stop()
	push_warning(message)
	failed.emit()

func _exit_tree() -> void:
	done = true
	if is_instance_valid(player): player.stop()
