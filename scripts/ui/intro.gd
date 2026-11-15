extends Control
## Intro de viñetas placeholder (GDD, Narrativa): del chiste en el Salón Beláustegui y el
## rescate de Tali hasta la llegada a Birig Bamba. El Croco junta al equipo, con una viñeta por
## personaje y su motivo. ~40 s. Enter / A pasa de viñeta; Esc / Start la saltea entera.
## Se ve la primera vez; después se saltea sola (se guarda en user://).

const HUB_SCENE := "res://scenes/hub/birig_bamba.tscn"
const SEEN_PATH := "user://intro.cfg"
const PANEL_TIME := 5.0
const BG := Color(0.06, 0.05, 0.08)
const PAPER := Color(0.96, 0.92, 0.82)

## Cada viñeta: título, texto, iniciales y color del "dibujo" placeholder.
const PANELS: Array[Dictionary] = [
	{"title": "Salón Beláustegui, Birig Bamba", "text": "El Líder Supremo de Talinorthland se hace el gracioso con la hermana de los Hermanos Agucci.\nPésima idea.", "face": "LS", "color": Color(0.75, 0.55, 0.3)},
	{"title": "La Guerra de Beláustegui", "text": "Los Aguccis compran tecnología Uwey a crédito (Fadied cobra caro) e invaden Talinorthland.\nSu sombra ciega a los Talinorteanos.", "face": "AG", "color": Color(0.45, 0.25, 0.65)},
	{"title": "El Especial Superviviente", "text": "El Mercenario Croco, cazarrecompensas, rescata a Tali y lo deja en la Tierra con el Capitán Champaka.", "face": "Cr", "color": Color(0.35, 0.6, 0.35)},
	{"title": "Tali", "text": "Vuelve para liberar su planeta. Y para revolearle una piedra a alguien.", "face": "T", "color": Color(0.8, 0.55, 0.3)},
	{"title": "Agucci", "text": "Quiere dejar de servir al Alto Mando. Su sombra no está tan de acuerdo.", "face": "A", "color": Color(0.45, 0.3, 0.6)},
	{"title": "Capitán Champaka", "text": "El tutor de Tali en la Tierra. Va porque es el papá del grupo: abraza fuerte y cura con hongos.", "face": "CC", "color": Color(0.35, 0.8, 0.7)},
	{"title": "General Pipo", "text": "Quiere ayudar a Talinorthland en secreto. Muy en secreto. No pregunten qué tiene en la cabaña.", "face": "GP", "color": Color(0.5, 0.58, 0.4)},
	{"title": "Maestro Uwey y Stewie", "text": "No quieren ver ganar a Fadied. Stewie, además, quiere comer.", "face": "MS", "color": Color(0.8, 0.72, 0.5)},
	{"title": "El Croco", "text": "Junta al equipo. Dice que es por Talinorthland. Igual lo cobra doble.", "face": "Cr", "color": Color(0.35, 0.6, 0.35)},
	{"title": "Primera parada: Birig Bamba", "text": "Territorio neutral: ahí no se pelea, se compra.\nTalinorthland, donde la supervivencia es un éxito.", "face": "BB", "color": Color(0.9, 0.3, 0.65)},
]

var _index: int = -1
var _timer: float = 0.0
var _panel: Control
var _wait: float = 0.5


static func was_seen() -> bool:
	var config := ConfigFile.new()
	return config.load(SEEN_PATH) == OK and config.get_value("intro", "seen", false)


static func mark_seen() -> void:
	var config := ConfigFile.new()
	config.set_value("intro", "seen", true)
	config.save(SEEN_PATH)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var hint := Label.new()
	hint.text = "Enter / A: siguiente  ·  Esc / Start: saltear"
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.offset_right = -24.0
	hint.offset_bottom = -16.0
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	add_child(hint)
	Sound.music("birig_bamba")
	_next()


func _process(delta: float) -> void:
	_timer -= delta
	_wait -= delta
	if _timer <= 0.0:
		_next()
		return
	if _wait > 0.0:
		return
	for slot: PlayerSlot in PlayerManager.active_slots():
		var input: PlayerInput = slot.input
		if input.just_pressed(PlayerInput.Action.PAUSE) or input.just_pressed(PlayerInput.Action.BACK):
			_finish()
			return
		if input.just_pressed(PlayerInput.Action.CONFIRM) or input.just_pressed(PlayerInput.Action.INTERACT):
			_wait = 0.25
			_next()
			return


func _physics_process(_delta: float) -> void:
	# PlayerManager actualiza el input en física; nada más acá.
	pass


func _next() -> void:
	_index += 1
	if _index >= PANELS.size():
		_finish()
		return
	_timer = PANEL_TIME
	if _panel != null:
		var old: Control = _panel
		var out: Tween = old.create_tween()
		out.tween_property(old, "modulate:a", 0.0, 0.25)
		out.tween_callback(old.queue_free)
	_panel = _build_panel(PANELS[_index])
	add_child(_panel)
	_panel.modulate.a = 0.0
	_panel.scale = Vector2.ONE * 0.92
	var tween: Tween = _panel.create_tween()
	tween.set_parallel(true)
	tween.tween_property(_panel, "modulate:a", 1.0, 0.3)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sound.play("babble_%d" % randi_range(0, 4), -8.0)


func _finish() -> void:
	set_process(false)
	mark_seen()
	for slot: PlayerSlot in PlayerManager.active_slots():
		slot.input.consume_all()
	get_tree().change_scene_to_file(HUB_SCENE)


## Una viñeta de cómic: marco de papel inclinado, "dibujo" placeholder y el texto.
func _build_panel(info: Dictionary) -> Control:
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(1100, 560)
	frame.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	frame.position -= frame.custom_minimum_size * 0.5
	frame.pivot_offset = frame.custom_minimum_size * 0.5
	frame.rotation = deg_to_rad(randf_range(-1.6, 1.6))
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = Color(0.1, 0.08, 0.08)
	style.set_border_width_all(8)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(28)
	frame.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 36)
	frame.add_child(row)
	# "Dibujo": un círculo grande del color del personaje con sus iniciales.
	var art := PanelContainer.new()
	art.custom_minimum_size = Vector2(380, 380)
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var circle := StyleBoxFlat.new()
	circle.bg_color = info["color"]
	circle.set_corner_radius_all(190)
	circle.border_color = Color(0.1, 0.08, 0.08)
	circle.set_border_width_all(6)
	art.add_theme_stylebox_override("panel", circle)
	var face := Label.new()
	face.text = info["face"]
	face.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	face.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	face.add_theme_font_size_override("font_size", 120)
	face.add_theme_color_override("font_color", Color.WHITE)
	face.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.08))
	face.add_theme_constant_override("outline_size", 14)
	art.add_child(face)
	row.add_child(art)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 22)
	row.add_child(column)
	var title := Label.new()
	title.text = info["title"]
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color(0.12, 0.1, 0.1))
	column.add_child(title)
	var text := Label.new()
	text.text = info["text"]
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(560, 0)
	text.add_theme_font_size_override("font_size", 30)
	text.add_theme_color_override("font_color", Color(0.18, 0.15, 0.14))
	column.add_child(text)
	var counter := Label.new()
	counter.text = "%d / %d" % [_index + 1, PANELS.size()]
	counter.add_theme_font_size_override("font_size", 18)
	counter.add_theme_color_override("font_color", Color(0.4, 0.36, 0.34))
	column.add_child(counter)
	return frame
