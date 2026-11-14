class_name Dialogue
extends RefCounted
## Frases del mundo (presos, carreta, enemigos...) desde data/texts/dialogos.json, para que el
## grupo las edite sin tocar código.

const PATH := "res://data/texts/dialogos.json"

static var _lines: Dictionary = {}


## Una frase al azar de `key`, o "" si no hay.
static func line(key: String) -> String:
	if _lines.is_empty():
		_load()
	var options: Array = _lines.get(key, [])
	return options.pick_random() if not options.is_empty() else ""


## Hace aparecer una frase en el mundo (con el texto flotante).
static func say(key: String, at: Vector3, color: Color = Color(0.95, 0.93, 0.88)) -> void:
	var text: String = line(key)
	if text != "":
		Events.floating_text_requested.emit(at, text, color)


static func _load() -> void:
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_warning("No se pudo abrir %s" % PATH)
		_lines = {"_": []}
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	_lines = parsed if parsed is Dictionary else {"_": []}
