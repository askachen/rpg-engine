extends RefCounted
## Retains original RGBA files. Regions are measured once and reused for drawing/UI.
var textures: Dictionary = {}
var regions: Dictionary = {}
var atlases: Dictionary = {}
var resources: Dictionary = {}

func resolve(spec) -> Texture2D:
	if spec is float or spec is int: return texture("characters", int(spec))
	if spec.has("path"):
		if not resources.has(spec.path): resources[spec.path] = load(spec.path)
		return resources[spec.path] as Texture2D
	return texture(spec.sheet, int(spec.index))

func draw_fitted(canvas: CanvasItem, value: Texture2D, rect: Rect2) -> void:
	if value == null: return
	var dimensions := value.get_size()
	var fitted := dimensions * minf(rect.size.x / dimensions.x, rect.size.y / dimensions.y)
	canvas.draw_texture_rect(value, Rect2(rect.position + (rect.size - fitted) * Vector2(0.5, 1.0), fitted), false)

func configure(sheets: Dictionary) -> void:
	for key in sheets:
		var spec: Dictionary = sheets[key]
		var texture := load(str(spec.path)) as Texture2D
		if texture == null: continue
		textures[key] = texture
		var image := texture.get_image()
		var cell := Vector2(texture.get_size()) / Vector2(spec.columns, spec.rows)
		for index in range(int(spec.columns * spec.rows)):
			var origin := Vector2(index % int(spec.columns), int(index / spec.columns)) * cell
			var region := Rect2(origin + Vector2(2, 2), cell - Vector2(4, 4))
			if index not in spec.get("opaque", []):
				var low := Vector2i(int(origin.x + cell.x), int(origin.y + cell.y))
				var high := Vector2i(int(origin.x), int(origin.y))
				# Ignore thin cell-edge artifacts; sample alpha to remove transparent margins.
				for y in range(int(origin.y + 6), int(origin.y + cell.y - 6), 3):
					for x in range(int(origin.x + 6), int(origin.x + cell.x - 6), 3):
						if image.get_pixel(x, y).a > 0.7:
							low.x = mini(low.x, x)
							low.y = mini(low.y, y)
							high.x = maxi(high.x, x)
							high.y = maxi(high.y, y)
				if high.x > low.x and high.y > low.y:
					region = Rect2(Vector2(low), Vector2(high - low + Vector2i(3, 3)))
			# Explicit source bounds handle artwork crossing a nominal atlas cell edge.
			if spec.get("regions", {}).has(str(index)):
				var bounds: Array = spec.regions[str(index)]
				region = Rect2(origin + Vector2(bounds[0], bounds[1]) * cell, Vector2(bounds[2], bounds[3]) * cell)
			var id := "%s:%d" % [key, index]
			regions[id] = region
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = region
			atlas.filter_clip = true
			atlases[id] = atlas

func texture(sheet: String, index: int) -> Texture2D:
	return atlases.get("%s:%d" % [sheet, index])

func draw(canvas: CanvasItem, sheet: String, index: int, destination: Rect2, tint: Color = Color.WHITE, fit: bool = true) -> void:
	var id := "%s:%d" % [sheet, index]
	if not regions.has(id): return
	var source: Rect2 = regions[id]
	if fit:
		var scale := minf(destination.size.x / source.size.x, destination.size.y / source.size.y)
		var size := source.size * scale
		destination = Rect2(destination.position + (destination.size - size) * Vector2(0.5, 1.0), size)
	canvas.draw_texture_rect_region(textures[sheet], destination, source, tint)

func material(canvas: CanvasItem, sheet: String, index: int, destination: Rect2, cell: Vector2i, repeat_cells: int = 3, tint: Color = Color.WHITE) -> void:
	var id := "%s:%d" % [sheet, index]
	if not regions.has(id): return
	var whole: Rect2 = regions[id]
	var size := whole.size / float(repeat_cells)
	var source := Rect2(whole.position + Vector2(posmod(cell.x, repeat_cells), posmod(cell.y, repeat_cells)) * size, size)
	canvas.draw_texture_rect_region(textures[sheet], destination, source, tint)
