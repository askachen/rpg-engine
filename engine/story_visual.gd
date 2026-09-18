extends Control
## Presentation-only scene. The dialogue player owns the clock and lifetime.
var actors: Dictionary = {}
var clocks: Dictionary = {}

func setup(art, spec: Dictionary) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if spec.has("background"):
		var matte := ColorRect.new()
		matte.color = Color.BLACK
		matte.mouse_filter = Control.MOUSE_FILTER_IGNORE
		matte.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(matte)
		var background := picture(art.resolve(spec.background), Rect2(0,0,1920,1080))
		background.name = "Background"
		add_child(background)
	for layer in spec.get("layers", []):
		var rect: Array = layer.rect
		var frames: Array = []
		if layer.has("animation"):
			for image in layer.animation.frames: frames.append(art.resolve(image))
		else: frames.append(art.resolve(layer.image))
		var actor := picture(frames[0], Rect2(rect[0],rect[1],rect[2],rect[3]))
		actor.name = layer.id
		add_child(actor)
		actors[layer.id] = actor
		if layer.has("animation"):
			clocks[layer.id] = {"elapsed":0.0,"index":0,"done":false,"frames":frames,"spec":layer.animation}

func picture(texture: Texture2D, rect: Rect2) -> TextureRect:
	var node := TextureRect.new()
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.texture = texture
	node.position = rect.position
	node.size = rect.size
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func tick(delta: float, paused: bool) -> void:
	if paused: return
	for id in clocks:
		var clock: Dictionary = clocks[id]
		if clock.done: continue
		clock.elapsed += maxf(delta, 0.0)
		var frame := int(floor(clock.elapsed * clock.spec.fps))
		var count: int = clock.frames.size()
		if clock.spec.loop:
			clock.index = frame % count
		else:
			clock.index = mini(frame, count - 1)
			clock.done = frame >= count
			if clock.done and clock.spec.end == "hide": actors[id].visible = false
		actors[id].texture = clock.frames[clock.index]
