extends CanvasLayer
## Pausa compartida: cualquier jugador pausa con Start o Esc, y la pausa es para todos.
## Si se desconecta un joystick en plena partida, se pausa sola hasta que vuelva.
##
## En pausa: Start o Esc para seguir; X (joystick) o E (teclado) abre las Opciones;
## B (joystick) o Retroceso (teclado) para volver a la pantalla de unión, con confirmación:
## "¿Abandonar la partida?" A / Enter sí, B / Esc no (pedido del grupo, 2026-11-20: con dos
## botones sin querer se perdía una partida entera).

const JOIN_SCENE := "res://scenes/ui/join_screen.tscn"

var _panel: Control
var _title: Label
var _message: Label
var _hint: Label
var _options: OptionsMenu
## Preguntando si de verdad quieren abandonar la partida.
var _confirming: bool = false
var _inventory: InventoryPanel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 50
	_build_ui()
	_panel.visible = false
	Events.device_disconnected.connect(_on_device_disconnected)
	Events.device_reconnected.connect(_on_device_reconnected)


func _physics_process(_delta: float) -> void:
	if _options != null and _options.visible:
		return
	if _confirming:
		_confirm_tick()
		return
	if is_instance_valid(_inventory):
		return
	for slot: PlayerSlot in PlayerManager.active_slots():
		var input: PlayerInput = slot.input
		if not get_tree().paused and input.just_pressed(PlayerInput.Action.INVENTORY) 				and not _in_menu(slot) and _player_of(slot) != null:
			open_inventory(slot)
			return
		if input.just_pressed(PlayerInput.Action.PAUSE):
			# Si ese jugador está en un menú (tienda, McoinIA, elegir mejora...), Esc / Start
			# cierra el menú y no pausa (antes se trababa: reportado por el grupo).
			if not get_tree().paused and _in_menu(slot):
				continue
			if get_tree().paused:
				_try_resume()
			else:
				_pause()
			return
		if get_tree().paused and _panel.visible and not PlayerManager.any_disconnected() \
				and slot.input.just_pressed(PlayerInput.Action.INTERACT):
			open_options()
			return
		if get_tree().paused and _panel.visible and _wants_exit(slot):
			_ask_exit()
			return


## "¿Abandonar la partida?": A / Enter confirma; B / Esc / Start vuelve a la pausa.
func _ask_exit() -> void:
	_confirming = true
	_title.text = "¿Abandonar la partida?"
	_message.text = "Se pierde todo lo de esta partida."
	_hint.text = "A o Enter: sí, abandonar
B o Esc: no, volver"
	for slot: PlayerSlot in PlayerManager.active_slots():
		slot.input.consume_all()


func _confirm_tick() -> void:
	for slot: PlayerSlot in PlayerManager.active_slots():
		var input: PlayerInput = slot.input
		if input.just_pressed(PlayerInput.Action.CONFIRM):
			_confirming = false
			_exit_to_join_screen()
			return
		if input.just_pressed(PlayerInput.Action.BACK) or input.just_pressed(PlayerInput.Action.PAUSE):
			_confirming = false
			input.consume_all()
			_refresh_text()
			return


## Tabla de lo que juntó ese jugador (Tab / Back). Pausa a todos mientras está abierta.
func open_inventory(slot: PlayerSlot) -> void:
	_inventory = InventoryPanel.new()
	add_child(_inventory)
	_inventory.open(slot)
	get_tree().paused = true
	Events.pause_changed.emit(true)
	_inventory.closed.connect(func() -> void:
		get_tree().paused = false
		for other: PlayerSlot in PlayerManager.active_slots():
			other.input.consume_all()
		Events.pause_changed.emit(false))


func _player_of(slot: PlayerSlot) -> PlayerCharacter:
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var player := node as PlayerCharacter
		if player != null and player.slot == slot:
			return player
	return null


func open_options() -> void:
	_options.open()
	_panel.visible = false


func _in_menu(slot: PlayerSlot) -> bool:
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var player := node as PlayerCharacter
		if player != null and player.slot == slot and player.menu_locked:
			return true
	return false


func _wants_exit(slot: PlayerSlot) -> bool:
	if slot.is_keyboard:
		return Input.is_physical_key_pressed(KEY_BACKSPACE)
	return slot.input.just_pressed(PlayerInput.Action.BACK)


func _pause() -> void:
	get_tree().paused = true
	_panel.visible = true
	_refresh_text()
	Events.pause_changed.emit(true)


func _try_resume() -> void:
	_confirming = false
	if PlayerManager.any_disconnected():
		_refresh_text()
		return
	get_tree().paused = false
	_panel.visible = false
	# Que el botón con el que se despausó no dispare nada en el juego.
	for slot: PlayerSlot in PlayerManager.active_slots():
		slot.input.consume_all()
	Events.pause_changed.emit(false)


func _exit_to_join_screen() -> void:
	get_tree().paused = false
	RunState.end_run()
	PlayerManager.reset()
	get_tree().change_scene_to_file(JOIN_SCENE)


func _on_device_disconnected(_slot: PlayerSlot) -> void:
	_pause()


func _on_device_reconnected(_slot: PlayerSlot) -> void:
	_refresh_text()


func _refresh_text() -> void:
	var missing: Array[String] = []
	for slot: PlayerSlot in PlayerManager.active_slots():
		if not slot.connected:
			missing.append(slot.label)
	if missing.is_empty():
		_title.text = "Pausa"
		_message.text = ""
		_hint.text = "Start o Esc para seguir\nX o E: Opciones\nB o Retroceso para volver a la pantalla de unión"
	else:
		_title.text = "¡Se desconectó un joystick!"
		_message.text = "Falta el de %s. Reconectalo para seguir." % ", ".join(missing)
		_hint.text = "B o Retroceso para volver a la pantalla de unión"


func _build_ui() -> void:
	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(dim)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 24)
	_panel.add_child(box)

	_title = _make_label(64)
	_message = _make_label(30)
	_hint = _make_label(24)
	_hint.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	for label: Label in [_title, _message, _hint]:
		box.add_child(label)
	_options = OptionsMenu.new()
	_options.visible = false
	add_child(_options)
	_options.closed.connect(func() -> void:
		_panel.visible = get_tree().paused
		_refresh_text())


func _make_label(font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	return label
