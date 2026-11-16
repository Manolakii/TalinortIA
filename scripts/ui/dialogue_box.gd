class_name DialogueBox
extends CanvasLayer
## Cuadro de diálogo de un NPC de Birig Bamba (GDD: NPCs con cuadro de texto y retrato).
## Le habla al jugador que interactuó; avanza con E / X o Enter / A. Mientras tanto, ese
## jugador no se mueve.

signal finished

const BG := Color(0.07, 0.06, 0.1, 0.94)

## Cuántas veces le habló cada personaje a cada NPC (para rotar las charlas).
static var _times_talked: Dictionary = {}

var player: PlayerCharacter
var _lines: Array = []
var _index: int = 0
var _text: Label
var _wait: float = 0.25


## Busca la charla del NPC en data/texts/npcs.json según el personaje y la visita.
static func lines_for(npc_id: String, character_id: String, visit: int) -> Dictionary:
	var file := FileAccess.open("res://data/texts/npcs.json", FileAccess.READ)
	if file == null:
		return {}
	var all: Variant = JSON.parse_string(file.get_as_text())
	if not all is Dictionary or not (all as Dictionary).has(npc_id):
		return {}
	var npc: Dictionary = all[npc_id]
	var talks: Dictionary = npc.get("charlas", {})
	var options: Array = talks.get(character_id, talks.get("default", []))
	if options.is_empty():
		return {}
	# La primera charla va primero; después rotan cada vez que le hablás (pedido del grupo:
	# que haya varias y no se repita siempre la misma).
	var key: String = "%s:%s" % [npc_id, character_id]
	var times: int = _times_talked.get(key, 0)
	_times_talked[key] = times + 1
	return {"nombre": npc.get("nombre", "?"), "iniciales": npc.get("iniciales", "?"),
			"color": Color.html(npc.get("color", "#888888")),
			"lineas": options[(visit + times) % options.size()]}


func start(talker: PlayerCharacter, talk: Dictionary) -> void:
	player = talker
	layer = 36
	_lines = talk.get("lineas", [])
	player.menu_locked = true
	player.slot.input.consume_all()
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_bottom = -150.0
	panel.custom_minimum_size = Vector2(820, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = BG
	style.border_color = talk.get("color", Color.GRAY)
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	# Retrato placeholder: círculo del color del NPC con sus iniciales.
	var portrait := PanelContainer.new()
	portrait.custom_minimum_size = Vector2(96, 96)
	var circle := StyleBoxFlat.new()
	circle.bg_color = talk.get("color", Color.GRAY)
	circle.set_corner_radius_all(48)
	portrait.add_theme_stylebox_override("panel", circle)
	var initials := Label.new()
	initials.text = talk.get("iniciales", "?")
	initials.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initials.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initials.add_theme_font_size_override("font_size", 34)
	portrait.add_child(initials)
	row.add_child(portrait)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	var name_label := Label.new()
	name_label.text = "%s  ·  le habla a %s" % [talk.get("nombre", "?"), player.data.display_name]
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", (talk.get("color", Color.WHITE) as Color).lightened(0.35))
	column.add_child(name_label)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(660, 70)
	_text.add_theme_font_size_override("font_size", 22)
	column.add_child(_text)
	var hint := Label.new()
	hint.text = "E / X para seguir"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(hint)
	_show_line()


func _physics_process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0 or not is_instance_valid(player):
		return
	var input: PlayerInput = player.slot.input
	if input.just_pressed(PlayerInput.Action.INTERACT) or input.just_pressed(PlayerInput.Action.CONFIRM):
		_index += 1
		_wait = 0.15
		if _index >= _lines.size():
			close()
		else:
			_show_line()
	elif (input.just_pressed(PlayerInput.Action.BACK) or input.just_pressed(PlayerInput.Action.PAUSE)):
		close()


func close() -> void:
	if is_instance_valid(player):
		player.menu_locked = false
		player.slot.input.consume_all()
	finished.emit()
	queue_free()


func _show_line() -> void:
	_text.text = String(_lines[_index]) if _index < _lines.size() else ""
	_babble(_text.text.length())


## Voz inventada tipo balbuceo (GDD, Audio): unas sílabas al empezar cada línea.
func _babble(letters: int) -> void:
	var syllables: int = clampi(letters / 10, 2, 7)
	for i: int in syllables:
		var timer: SceneTreeTimer = get_tree().create_timer(i * 0.09)
		timer.timeout.connect(func() -> void: Sound.play("babble_%d" % randi_range(0, 4), -6.0, 0.05))
