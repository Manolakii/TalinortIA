extends Control
## Pantalla de unión: hasta 4 jugadores, un teclado y mouse como máximo,
## cada uno con su color P1 a P4 y un personaje sin repetir.
##
## Controles (DECISIONES 2026-11-12):
##   Enter o A: unirse / confirmar personaje
##   Izquierda y derecha: elegir personaje
##   B o Esc: desconfirmar, o salir si no había confirmado
##   Start (o Enter con todos listos): arrancar
##   E o X (cualquiera): cambiar la dificultad

const GAME_SCENE := "res://scenes/rooms/test_room_talinorthland.tscn"

const BG_COLOR := Color(0.07, 0.07, 0.1)
const EMPTY_PANEL_COLOR := Color(0.13, 0.13, 0.17)
const JOINED_PANEL_COLOR := Color(0.16, 0.16, 0.21)
const MUTED_TEXT := Color(0.62, 0.62, 0.68)

## Una columna por lugar de jugador.
class SlotColumn:
	var panel: PanelContainer
	var style: StyleBoxFlat
	var header: Label
	var device: Label
	var character: Label
	var blurb: Label
	var status: Label

var _columns: Array[SlotColumn] = []
var _footer: Label
var _difficulty_label: Label
var _starting: bool = false


func _ready() -> void:
	PlayerManager.reset()
	if not is_difficulty_unlocked(RunState.difficulty):
		RunState.difficulty = DifficultyConfig.Level.EASY
	_build_ui()
	_refresh()


func _input(event: InputEvent) -> void:
	if _starting:
		return
	var joy := event as InputEventJoypadButton
	if joy != null and joy.pressed and joy.button_index == JOY_BUTTON_A:
		if PlayerManager.slot_for_joypad(joy.device) == null:
			_join(false, joy.device)
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo \
			and (key.physical_keycode == KEY_ENTER or key.physical_keycode == KEY_KP_ENTER):
		if not PlayerManager.has_keyboard_player():
			_join(true, -1)


func _physics_process(_delta: float) -> void:
	if _starting:
		return
	var changed: bool = false
	for slot: PlayerSlot in PlayerManager.active_slots():
		var input: PlayerInput = slot.input
		if input.just_pressed(PlayerInput.Action.INTERACT):
			_cycle_difficulty()
			changed = true
		if input.just_pressed(PlayerInput.Action.LEFT):
			PlayerManager.cycle_character(slot, -1)
			changed = true
		elif input.just_pressed(PlayerInput.Action.RIGHT):
			PlayerManager.cycle_character(slot, 1)
			changed = true

		if input.just_pressed(PlayerInput.Action.CONFIRM):
			if not slot.is_ready:
				PlayerManager.set_ready(slot, true)
				changed = true
			elif slot.is_keyboard and PlayerManager.all_ready():
				_start_game()
				return
		if not slot.is_keyboard and input.just_pressed(PlayerInput.Action.PAUSE) \
				and PlayerManager.all_ready():
			_start_game()
			return

		if input.just_pressed(PlayerInput.Action.BACK):
			if slot.is_ready:
				PlayerManager.set_ready(slot, false)
			else:
				PlayerManager.leave(slot.index)
			changed = true
	if changed:
		_refresh()


## Pasa a la siguiente dificultad desbloqueada (Fácil siempre; el resto con el flag de debug
## hasta que exista el progreso entre partidas).
func _cycle_difficulty() -> void:
	var count: int = Balance.difficulty.names.size()
	for step: int in range(1, count + 1):
		var candidate: int = (RunState.difficulty + step) % count
		if is_difficulty_unlocked(candidate):
			RunState.difficulty = candidate
			return


static func is_difficulty_unlocked(level: int) -> bool:
	return level == DifficultyConfig.Level.EASY or GameSettings.unlock_all_difficulties


func _join(keyboard: bool, device: int) -> void:
	var slot: PlayerSlot = PlayerManager.join(keyboard, device)
	if slot == null:
		return
	# El botón con el que se unió no tiene que confirmar el personaje en el mismo toque.
	slot.input.consume_all()
	_refresh()


func _start_game() -> void:
	_starting = true
	PlayerManager.joining_open = false
	for slot: PlayerSlot in PlayerManager.active_slots():
		slot.input.consume_all()
	RunState.start_run()
	get_tree().change_scene_to_file(GAME_SCENE)


# --- UI ---

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 28)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 64)
	add_child(margin)
	margin.add_child(root)

	var title := _label("TalinortIA", 72, Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)
	var subtitle := _label("Talinorthland, donde la supervivencia es un éxito.", 24, MUTED_TEXT)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(subtitle)

	_difficulty_label = _label("", 28, Color.WHITE)
	_difficulty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_difficulty_label)

	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 24)
	root.add_child(row)
	for i: int in Balance.player_slots.max_players:
		var column := _build_column()
		row.add_child(column.panel)
		_columns.append(column)

	_footer = _label("", 28, Color.WHITE)
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_footer)

	if GameSettings.unlock_all_difficulties:
		var debug := _label("Debug: todas las dificultades desbloqueadas", 16, MUTED_TEXT)
		debug.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		root.add_child(debug)


func _build_column() -> SlotColumn:
	var column := SlotColumn.new()
	column.panel = PanelContainer.new()
	column.panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.style = StyleBoxFlat.new()
	column.style.set_corner_radius_all(14)
	column.style.set_border_width_all(4)
	column.style.content_margin_left = 24
	column.style.content_margin_right = 24
	column.style.content_margin_top = 24
	column.style.content_margin_bottom = 24
	column.panel.add_theme_stylebox_override("panel", column.style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	column.panel.add_child(box)
	column.header = _label("", 56, Color.WHITE)
	column.device = _label("", 20, MUTED_TEXT)
	column.character = _label("", 36, Color.WHITE)
	column.blurb = _label("", 20, MUTED_TEXT)
	column.blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.blurb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.status = _label("", 24, Color.WHITE)
	column.status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for label: Label in [column.header, column.device, column.character, column.blurb, column.status]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(label)
	return column


func _refresh() -> void:
	for i: int in _columns.size():
		var column: SlotColumn = _columns[i]
		var slot: PlayerSlot = PlayerManager.slots[i]
		var slot_color: Color = Balance.player_slots.colors[i]
		column.header.text = Balance.player_slots.labels[i]
		if slot == null:
			column.style.bg_color = EMPTY_PANEL_COLOR
			column.style.border_color = slot_color.darkened(0.6)
			column.header.add_theme_color_override("font_color", slot_color.darkened(0.4))
			column.device.text = ""
			column.character.text = ""
			column.blurb.text = ""
			column.status.text = "Apretá Enter o A\npara unirte"
			column.status.add_theme_color_override("font_color", MUTED_TEXT)
			continue
		column.style.bg_color = JOINED_PANEL_COLOR
		column.style.border_color = slot_color
		column.header.add_theme_color_override("font_color", slot_color)
		column.device.text = slot.device_name()
		column.character.text = slot.character.display_name if slot.is_ready \
				else "<  %s  >" % slot.character.display_name
		column.blurb.text = slot.character.blurb
		if slot.is_ready:
			column.status.text = "¡Listo!"
			column.status.add_theme_color_override("font_color", slot_color)
		else:
			column.status.text = "Elegí con izquierda/derecha\ny confirmá con A o Enter"
			column.status.add_theme_color_override("font_color", Color.WHITE)

	var names: Array[String] = Balance.difficulty.names
	_difficulty_label.text = "Dificultad: %s   (E o X para cambiar)" % names[RunState.difficulty]

	if PlayerManager.all_ready():
		_footer.text = "¡Todos listos! Start (o Enter) para arrancar"
	elif PlayerManager.player_count() == 0:
		_footer.text = "De 1 a 4 jugadores. Uno solo puede usar teclado y mouse."
	else:
		_footer.text = "B o Esc para volver atrás. Se arranca cuando están todos listos."


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
