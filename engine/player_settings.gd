extends RefCounted
## Shared persistent preferences; never writes gameplay state.
const RESOLUTIONS = [Vector2i(1280,720), Vector2i(1600,900), Vector2i(1920,1080), Vector2i(2560,1440), Vector2i(3840,2160), Vector2i(1920,1200), Vector2i(2560,1080)]
const RANGES = {"volume": [0.0,1.0,0.8], "music_volume": [0.0,1.0,1.0], "sfx_volume": [0.0,1.0,1.0], "voice_volume": [0.0,1.0,1.0], "text_size": [22.0,36.0,28.0], "text_speed": [10.0,100.0,35.0], "auto_delay": [0.5,5.0,1.4]}

static func normalize(data: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in RANGES:
		var bounds: Array = RANGES[key]
		var value = data.get(key)
		result[key] = clampf(float(value),bounds[0],bounds[1]) if (value is float or value is int) and is_finite(float(value)) else bounds[2]
	result.fullscreen = data.get("fullscreen",false) if data.get("fullscreen",false) is bool else false
	result.resolution = "1920x1080"
	for dimensions in RESOLUTIONS:
		var id := "%dx%d" % [dimensions.x,dimensions.y]
		if data.get("resolution") == id: result.resolution = id
	return result

static func apply_audio(data: Dictionary) -> void:
	for bus_name in ["Music","SFX","Voice"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1,bus_name)
		AudioServer.set_bus_send(AudioServer.get_bus_index(bus_name),"Master")
	for pair in [["Master","volume"],["Music","music_volume"],["SFX","sfx_volume"],["Voice","voice_volume"]]:
		var index := AudioServer.get_bus_index(pair[0])
		var value := float(data[pair[1]])
		AudioServer.set_bus_mute(index,value == 0.0)
		AudioServer.set_bus_volume_db(index,linear_to_db(maxf(value,0.0001)))

static func apply_display(data: Dictionary) -> void:
	if DisplayServer.get_name() == "headless": return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if data.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	if not data.fullscreen:
		var parts: PackedStringArray = data.resolution.split("x")
		var requested := Vector2i(int(parts[0]),int(parts[1]))
		var usable := DisplayServer.screen_get_usable_rect()
		var factor := minf(1.0,minf(float(usable.size.x)/requested.x,float(maxi(1,usable.size.y-60))/requested.y))
		var dimensions := Vector2i(Vector2(requested)*factor)
		DisplayServer.window_set_size(dimensions)
		DisplayServer.window_set_position(usable.position+(usable.size-dimensions)/2)
