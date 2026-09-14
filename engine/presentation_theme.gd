extends RefCounted
## Resource-backed presentation configuration; never reads or mutates game state.
var spec: Dictionary = {}
var avatars: Dictionary = {}
var art
var font: Font = ThemeDB.fallback_font
const DEFAULTS = {
 "background": "0e1716", "text": "dbe7df", "panel": "183a32", "border": "45604d",
 "button": "284b40", "hover": "3e6755", "accent": "d2bb8b", "muted": "93ab9d",
 "success": "b7cbae", "warning": "dcbd8d", "shade": "030908d6",
 "title_outer": "203e33", "title_inner": "29483a"
}

func configure(content: Dictionary, library) -> void:
	spec = content.get("presentation", {})
	avatars = content.get("avatars", {})
	art = library
	if spec.get("font", "") != "": font = load(spec.font) as Font

func palette(key: String) -> Color:
	return Color(spec.get("palette", {}).get(key, DEFAULTS.get(key, "ffffff")))

func title_text(key: String, fallback: String) -> String:
	return str(spec.get("title", {}).get(key, fallback))

func draw_title(canvas: CanvasItem) -> void:
	canvas.draw_circle(Vector2(1350, 550), 400, palette("title_outer"))
	canvas.draw_circle(Vector2(1350, 550), 340, palette("title_inner"))
	for layer in spec.get("title", {}).get("layers", []):
		var texture: Texture2D = art.resolve(layer.image)
		var rect: Array = layer.rect
		art.draw_fitted(canvas, texture, Rect2(rect[0], rect[1], rect[2], rect[3]))

func label(text: String, size: int = 18, color: Color = Color.TRANSPARENT) -> Label:
	var node := Label.new()
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.text = text
	node.add_theme_font_override("font", font)
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color if color != Color.TRANSPARENT else palette("text"))
	return node

func portrait(who: String, dimensions: Vector2) -> TextureRect:
	var node := TextureRect.new()
	node.texture = art.resolve(avatars[who].portrait)
	node.custom_minimum_size = dimensions
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node

func card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = palette("panel")
	style.border_color = palette("border")
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style

func button(text: String, action: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.add_theme_font_override("font", font)
	node.custom_minimum_size = Vector2(0, 56)
	node.add_theme_color_override("font_color", palette("text"))
	node.add_theme_color_override("font_hover_color", palette("text"))
	node.add_theme_color_override("font_disabled_color", palette("muted"))
	node.add_theme_font_size_override("font_size", 22)
	var style := StyleBoxFlat.new()
	style.bg_color = palette("button")
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 16
	style.content_margin_right = 16
	node.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = palette("hover")
	node.add_theme_stylebox_override("hover", hover)
	node.pressed.connect(action)
	return node
