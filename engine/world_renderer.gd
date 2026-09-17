extends RefCounted
## Read-only renderer called from the clipped world surface's _draw callback.
var canvas: Control

func draw(view: Control, surface: Control) -> void:
	canvas = surface
	var area: Dictionary = view.core.content.maps[view.core.state.map]
	var unit = view.tile_size()
	var bounds = Rect2(view.ORIGIN, Vector2(area.width, area.height) * unit)
	var frame = view.card_style()
	frame.bg_color = Color("293d32")
	frame.shadow_color = Color(0, 0, 0, 0.3)
	frame.shadow_size = 12
	canvas.draw_style_box(frame, bounds.grow(8))
	var floor_sheet: String = area.get("floor_sheet", "")
	for y in range(maxi(0, int(view.camera.y / unit)), mini(area.height, int(ceil((view.camera.y + view.WORLD_SIZE.y) / unit)))):
		for x in range(maxi(0, int(view.camera.x / unit)), mini(area.width, int(ceil((view.camera.x + view.WORLD_SIZE.x) / unit)))):
			var floor_index = int(area.get("floor_index", 0))
			for room in area.get("rooms", []):
				if Rect2(room.rect[0], room.rect[1], room.rect[2], room.rect[3]).has_point(Vector2(x, y)):
					floor_index = int(room.floor)
			for zone in area.get("zones", []):
				if Rect2(zone.rect[0], zone.rect[1], zone.rect[2], zone.rect[3]).has_point(Vector2(x, y)):
					floor_index = int(zone.get("floor", floor_index))
			var material: Dictionary = area.get("materials", {}).get(str(floor_index), {})
			var repeats: int = int(material.get("repeat", 3))
			var tint: Color = Color(material.get("tint", "ffffff"))
			view.art.material(canvas, floor_sheet, floor_index, Rect2(view.ORIGIN + Vector2(x, y) * unit, Vector2(unit, unit)), Vector2i(x, y), repeats, tint)
	for decor in area.get("decorations", []):
		if decor.layer == "floor": draw_prop(view, decor, unit)
	for prop in area.get("furniture", []):
		if prop.get("layer", "prop") == "floor": draw_prop(view, prop, unit)
	var wall_cells: Dictionary = {}
	for wall in area.walls: wall_cells[Vector2i(int(wall[0]), int(wall[1]))] = true
	for wall in area.walls:
		var at = view.ORIGIN + Vector2(wall[0], wall[1]) * unit
		var cell = Vector2i(int(wall[0]), int(wall[1]))
		var vertical = (wall_cells.has(cell + Vector2i.UP) or wall_cells.has(cell + Vector2i.DOWN)) and not (wall_cells.has(cell + Vector2i.LEFT) or wall_cells.has(cell + Vector2i.RIGHT))
		canvas.draw_rect(Rect2(at + Vector2(2, 5), Vector2(unit, unit)), Color(0, 0, 0, 0.18))
		var wall_spec: Dictionary = view.appearance.spec.get("world", {}).get("wall", {})
		if not wall_spec.is_empty():
			view.art.draw(canvas, wall_spec.sheet, int(wall_spec.vertical if vertical else wall_spec.horizontal), Rect2(at, Vector2(unit, unit)), Color("f2e4cd"), false)
		if vertical: canvas.draw_line(at + Vector2(2, 0), at + Vector2(2, unit), Color("7d6850"), 3)
		else: canvas.draw_line(at + Vector2(0, 2), at + Vector2(unit, 2), Color("7d6850"), 3)
	for decor in area.get("decorations", []):
		if decor.layer == "wall": draw_prop(view, decor, unit)
	# Sort freestanding props and actors by ground position for natural overlap.
	var layers: Array = []
	for furnishing in area.get("furniture", []):
		if furnishing.get("layer", "prop") == "floor": continue
		layers.append({"y": furnishing.position[1] + furnishing.size[1], "prop": furnishing})
	for decor in area.get("decorations", []):
		if decor.layer == "prop": layers.append({"y": decor.position[1] + decor.size[1], "prop": decor})
	for target in view.core.map_objects():
		if view.core.object_removed(target): continue
		layers.append({"y": target.position[1] + 1, "target": target})
	layers.append({"y": view.core.state.position[1] + 1, "player": true})
	layers.sort_custom(func(a, b): return a.y < b.y)
	for entry in layers:
		if entry.has("prop"):
			draw_prop(view, entry.prop, unit)
		elif entry.has("player"):
			draw_actor(view, view.core.protagonist_id(), view.core.state.position, unit, view.motion.remaining > 0)
		else:
			var target: Dictionary = entry.target
			var center = view.ORIGIN + (Vector2(target.position[0], target.position[1]) + Vector2(0.5, 0.5)) * unit
			match target.kind:
				"npc":
					draw_actor(view, target.character, target.position, unit)
					draw_chip(view, view.t(target.character) + "  ···", center + Vector2(0, -unit * 1.7))
				"pickup": draw_icon(view, "pickup", Rect2(center - Vector2(unit * 0.38, unit * 0.38), Vector2.ONE * unit * 0.76))
				"switch": draw_icon(view, "switch", Rect2(center - Vector2(unit * 0.4, unit * 1.5), Vector2(unit * 0.8, unit * 1.85)))
				"exit":
					draw_chip(view, "› " + view.t(target.label), center + Vector2(0, -18), Color("d7c391") if view.core.target_visible(target) else Color("9c8d7c"))
				"inspect": draw_chip(view, view.t(target.label) + "  ···", center + Vector2(0, -18))
				"shop": draw_chip(view, view.t("counter") + "  ···", center + Vector2(0, 20))
	for cell in view.walking:
		canvas.draw_circle(view.ORIGIN + (Vector2(cell) + Vector2(0.5, 0.5)) * unit, 3, Color(1, 0.94, 0.7, 0.55))
	if view.core.state.period == "late": canvas.draw_rect(bounds, Color(0.10, 0.15, 0.27, 0.18))
	elif view.core.state.period == "evening": canvas.draw_rect(bounds, Color(0.55, 0.28, 0.1, 0.06))

	draw_hover(view)

func draw_prop(view: Control, prop: Dictionary, unit: float) -> void:
	view.art.draw(canvas, prop.get("sheet", ""), int(prop.sprite), Rect2(view.ORIGIN + Vector2(prop.position[0], prop.position[1]) * unit, Vector2(prop.size[0], prop.size[1]) * unit))

func draw_actor(view: Control, who: String, position_value: Array, unit: float, moving: bool = false) -> void:
	var feet = view.ORIGIN + (Vector2(position_value[0], position_value[1]) + Vector2(0.5, 0.9)) * unit
	var avatar: Dictionary = view.core.content.avatars[who]
	var bob = sin(view.avatar_time * 20.0) * 2.0 if moving and not avatar.has("walk") else 0.0
	var shadow = tile_style(view, Color(0.05, 0.1, 0.06, 0.27))
	shadow.set_corner_radius_all(8)
	canvas.draw_style_box(shadow, Rect2(feet + Vector2(-unit * 0.27, -5), Vector2(unit * 0.54, 10)))
	view.art.draw_fitted(canvas, view.art.resolve(view.motion.image_spec(avatar, who, moving)), Rect2(feet + Vector2(-unit * 0.65, -unit * 1.85 + bob), Vector2(unit * 1.3, unit * 1.85)))

func draw_chip(view: Control, text: String, center: Vector2, tint: Color = Color("efe3c8")) -> void:
	var text_size = view.appearance.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17)
	var at = Vector2(center.x - text_size.x / 2.0, center.y)
	var style = tile_style(view, Color(0.12, 0.19, 0.15, 0.87))
	style.set_corner_radius_all(6)
	canvas.draw_style_box(style, Rect2(at + Vector2(-7, -20), text_size + Vector2(14, 6)))
	canvas.draw_string(view.appearance.font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, tint)

func tile_style(view: Control, color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 3
	style.corner_radius_bottom_right = 3
	return style

func draw_icon(view: Control, kind: String, rect: Rect2) -> void:
	var spec = view.appearance.spec.get("world", {}).get("icons", {}).get(kind)
	if spec != null: view.art.draw_fitted(canvas, view.art.resolve(spec), rect)

func draw_hover(view: Control) -> void:
	var target: Dictionary = view.hovered_target()
	if target.is_empty(): return
	var center = view.ORIGIN + (Vector2(target.position[0], target.position[1]) + Vector2(0.5, 0.5)) * view.tile_size()
	var available: bool = view.core.target_visible(target)
	canvas.draw_rect(Rect2(center - Vector2.ONE * view.tile_size() / 2, Vector2.ONE * view.tile_size()), Color("d2bb8b") if available else Color("dc8d8d"), false, 2)
	draw_chip(view, view.t(target.label) + ("" if available else " · " + view.t("unavailable")), center - Vector2(0, view.tile_size() * 1.8))
