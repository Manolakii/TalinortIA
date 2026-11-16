class_name OptionsMenu
extends Control
## Opciones (pedido del grupo): se abre desde la pausa. Cualquier jugador lo maneja:
## arriba / abajo para elegir, izquierda / derecha para cambiar, B o Esc para volver.
## Todo se guarda en user://settings.cfg.

signal closed

const ROW_COLOR := Color(0.8, 0.8, 0.85)
const SELECTED_COLOR := Color(1.0, 0.82, 0.3)
const QUALITIES: Array[StringName] = [&"low", &"medium", &"high"]
const QUALITY_NAMES: Array[String] = ["Baja", "Media", "Alta"]
const ROWS: Array[String] = ["Volumen general", "Música", "Efectos", "Calidad gráfica",
		"Pantalla completa", "Sacudida de cámara", "Números de daño", "Vibración del joystick", "Volver"]

var selected: int = 0
var _labels: Array[Label] = []
var _wait: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	var title := _label(54)
	title.text = "Opciones"
	box.add_child(title)
	for i: int in ROWS.size():
		var row := _label(30)
		box.add_child(row)
		_labels.append(row)
	var hint := _label(20)
	hint.text = "Arriba / abajo para elegir · Izquierda / derecha para cambiar · B o Esc para volver"
	hint.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
	box.add_child(hint)
	_refresh()


func open() -> void:
	visible = true
	selected = 0
	_wait = 0.15
	for slot: PlayerSlot in PlayerManager.active_slots():
		slot.input.consume_all()
	_refresh()


func _physics_process(delta: float) -> void:
	if not visible:
		return
	_wait -= delta
	if _wait > 0.0:
		return
	for slot: PlayerSlot in PlayerManager.active_slots():
		var input: PlayerInput = slot.input
		if input.just_pressed(PlayerInput.Action.BACK) or input.just_pressed(PlayerInput.Action.PAUSE):
			close()
			return
		if input.just_pressed(PlayerInput.Action.UP):
			move(-1)
		elif input.just_pressed(PlayerInput.Action.DOWN):
			move(1)
		elif input.just_pressed(PlayerInput.Action.LEFT):
			change(-1)
		elif input.just_pressed(PlayerInput.Action.RIGHT):
			change(1)
		elif input.just_pressed(PlayerInput.Action.CONFIRM) or input.just_pressed(PlayerInput.Action.INTERACT):
			if selected == ROWS.size() - 1:
				close()
				return
			change(1)


func move(step: int) -> void:
	selected = wrapi(selected + step, 0, ROWS.size())
	Sound.play("ui_move", -6.0, 0.0)
	_refresh()


## Cambia la opción marcada (también lo usan los tests).
func change(step: int) -> void:
	match selected:
		0:
			GameSettings.master_volume = _step_volume(GameSettings.master_volume, step)
		1:
			GameSettings.music_volume = _step_volume(GameSettings.music_volume, step)
		2:
			GameSettings.sfx_volume = _step_volume(GameSettings.sfx_volume, step)
		3:
			var index: int = QUALITIES.find(GameSettings.current_preset_id)
			GameSettings.set_quality(QUALITIES[clampi(index + step, 0, QUALITIES.size() - 1)])
		4:
			GameSettings.set_fullscreen(not GameSettings.fullscreen)
		5:
			GameSettings.shake_scale = clampf(snappedf(GameSettings.shake_scale + 0.25 * step, 0.25), 0.0, 1.0)
		6:
			GameSettings.damage_numbers = not GameSettings.damage_numbers
		7:
			GameSettings.vibration = not GameSettings.vibration
		_:
			return
	GameSettings.apply_audio()
	GameSettings.save_options()
	Sound.play("ui_confirm", -6.0, 0.0)
	_refresh()


func close() -> void:
	visible = false
	for slot: PlayerSlot in PlayerManager.active_slots():
		slot.input.consume_all()
	closed.emit()


func _step_volume(value: float, step: int) -> float:
	return clampf(snappedf(value + 0.1 * step, 0.1), 0.0, 1.0)


func _value_text(index: int) -> String:
	match index:
		0:
			return "%d%%" % roundi(GameSettings.master_volume * 100.0)
		1:
			return "%d%%" % roundi(GameSettings.music_volume * 100.0)
		2:
			return "%d%%" % roundi(GameSettings.sfx_volume * 100.0)
		3:
			var index_q: int = QUALITIES.find(GameSettings.current_preset_id)
			return QUALITY_NAMES[maxi(index_q, 0)]
		4:
			return "Sí" if GameSettings.fullscreen else "No"
		5:
			return "%d%%" % roundi(GameSettings.shake_scale * 100.0)
		6:
			return "Sí" if GameSettings.damage_numbers else "No"
		7:
			return "Sí" if GameSettings.vibration else "No"
	return ""


func _refresh() -> void:
	for i: int in _labels.size():
		var value: String = _value_text(i)
		var text: String = ROWS[i] + ("   ‹ %s ›" % value if value != "" else "")
		_labels[i].text = ("▶ " if i == selected else "") + text
		_labels[i].add_theme_color_override("font_color", SELECTED_COLOR if i == selected else ROW_COLOR)


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 8)
	return label
