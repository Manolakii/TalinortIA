class_name ItemIcon
extends Control
## Ícono chiquito de un objeto o mejora (pedido del grupo: que ocupen poco y el detalle se lea
## pasando el mouse). Placeholder hasta que haya arte: un cuadrado de color con dos letras y,
## si tenés varias copias, "x3" en la esquina.

const SIZE := 34.0

var color: Color = Color(0.5, 0.5, 0.55)
var text: String = ""
var count: int = 1
var border: Color = Color(0, 0, 0, 0.6)


static func make(icon_color: Color, letters: String, title: String, description: String,
		copies: int = 1, border_color: Color = Color(0, 0, 0, 0.6)) -> ItemIcon:
	var icon := ItemIcon.new()
	icon.color = icon_color
	icon.text = letters
	icon.count = copies
	icon.border = border_color
	icon.tooltip_text = "%s%s\n%s" % [title, " (x%d)" % copies if copies > 1 else "", description]
	return icon


## Dos letras de un nombre ("Piedra de afilar" → "Pa").
static func letters_of(name: String) -> String:
	var words: PackedStringArray = name.split(" ", false)
	if words.size() >= 2 and words[-1].length() > 2:
		return (words[0].left(1) + words[-1].left(1)).capitalize().replace(" ", "")
	return name.left(2)


func _init() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, color.darkened(0.15))
	draw_rect(Rect2(2, 2, size.x - 4, size.y * 0.45), color.lightened(0.12))
	draw_rect(rect, border, false, 2.0)
	var font: Font = get_theme_default_font()
	var ink: Color = Color.BLACK if color.get_luminance() > 0.6 else Color.WHITE
	draw_string(font, Vector2(0, size.y * 0.66), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, ink)
	if count > 1:
		var badge: String = "x%d" % count
		draw_string_outline(font, Vector2(0, size.y - 2), badge, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 2, 11, 3,
				Color.BLACK)
		draw_string(font, Vector2(0, size.y - 2), badge, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 2, 11, Color.WHITE)
