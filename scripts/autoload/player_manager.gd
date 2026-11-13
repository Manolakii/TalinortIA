extends Node
## Quién juega, con qué dispositivo, con qué color y con qué personaje.
## Los lugares son fijos: si P2 se va de la pantalla de unión, P3 sigue siendo P3.

var slots: Array[PlayerSlot] = []
## Mientras está abierto (pantalla de unión) se puede entrar y salir.
## En partida está cerrado: si se desconecta un joystick, se pausa en lugar de sacar al jugador.
var joining_open: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	slots.resize(Balance.player_slots.max_players)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _physics_process(_delta: float) -> void:
	# Los autoloads van primero en el árbol, así que el input queda leído
	# antes de que cualquier personaje o menú lo use en este frame.
	var viewport: Viewport = get_viewport()
	for slot: PlayerSlot in slots:
		if slot != null:
			slot.input.update(viewport)


# --- Consultas ---

func active_slots() -> Array[PlayerSlot]:
	var result: Array[PlayerSlot] = []
	for slot: PlayerSlot in slots:
		if slot != null:
			result.append(slot)
	return result


func player_count() -> int:
	return active_slots().size()


func has_keyboard_player() -> bool:
	return slot_for_keyboard() != null


func slot_for_keyboard() -> PlayerSlot:
	for slot: PlayerSlot in slots:
		if slot != null and slot.is_keyboard:
			return slot
	return null


func slot_for_joypad(device: int) -> PlayerSlot:
	for slot: PlayerSlot in slots:
		if slot != null and not slot.is_keyboard and slot.joy_device == device:
			return slot
	return null


func is_character_taken(character: CharacterData, except_index: int = -1) -> bool:
	for slot: PlayerSlot in slots:
		if slot != null and slot.index != except_index and slot.character == character:
			return true
	return false


## Hay al menos un jugador y todos confirmaron su personaje.
func all_ready() -> bool:
	var count: int = 0
	for slot: PlayerSlot in slots:
		if slot == null:
			continue
		count += 1
		if not slot.is_ready:
			return false
	return count > 0


# --- Unirse, salir, elegir ---

## Devuelve el lugar nuevo, o null si no se puede (lleno, ya unido, o segundo teclado).
func join(keyboard: bool, joy_device: int = -1) -> PlayerSlot:
	if not joining_open:
		return null
	if keyboard and has_keyboard_player():
		return null
	if not keyboard and slot_for_joypad(joy_device) != null:
		return null
	var free_index: int = slots.find(null)
	if free_index == -1:
		return null

	var slot := PlayerSlot.new(free_index, keyboard, joy_device)
	slot.color = Balance.player_slots.colors[free_index]
	slot.label = Balance.player_slots.labels[free_index]
	slot.character = _first_free_character(free_index)
	slots[free_index] = slot
	Events.player_joined.emit(slot)
	return slot


func leave(index: int) -> void:
	if index < 0 or index >= slots.size() or slots[index] == null:
		return
	slots[index] = null
	Events.player_left.emit(index)


## Cambia el personaje del jugador al siguiente libre en la dirección dada (+1 o -1).
func cycle_character(slot: PlayerSlot, direction: int) -> void:
	if slot.is_ready:
		return
	var list: Array[CharacterData] = Balance.roster.characters
	var current: int = list.find(slot.character)
	for step: int in range(1, list.size() + 1):
		var candidate: CharacterData = list[posmod(current + step * direction, list.size())]
		if not is_character_taken(candidate, slot.index):
			slot.character = candidate
			Events.player_character_changed.emit(slot)
			return


## Confirma o desconfirma. No deja confirmar un personaje que ya tomó otro.
func set_ready(slot: PlayerSlot, value: bool) -> bool:
	if value and is_character_taken(slot.character, slot.index):
		return false
	slot.is_ready = value
	Events.player_ready_changed.emit(slot)
	return true


func reset() -> void:
	for i: int in slots.size():
		slots[i] = null
	joining_open = true


func _first_free_character(slot_index: int) -> CharacterData:
	for character: CharacterData in Balance.roster.characters:
		if not is_character_taken(character, slot_index):
			return character
	return null


# --- Joysticks que se conectan y desconectan ---

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		_on_joy_connected(device)
		return
	var slot: PlayerSlot = slot_for_joypad(device)
	if slot == null:
		return
	if joining_open:
		leave(slot.index)
	else:
		slot.connected = false
		Events.device_disconnected.emit(slot)


func _on_joy_connected(device: int) -> void:
	var same: PlayerSlot = slot_for_joypad(device)
	if same != null:
		same.connected = true
		Events.device_reconnected.emit(same)
		return
	# Si volvió con otro id, se lo damos al primer jugador que había perdido el suyo.
	for slot: PlayerSlot in slots:
		if slot != null and not slot.is_keyboard and not slot.connected:
			slot.joy_device = device
			slot.input = PlayerInput.new(false, device)
			slot.connected = true
			Events.device_reconnected.emit(slot)
			return


func any_disconnected() -> bool:
	for slot: PlayerSlot in slots:
		if slot != null and not slot.connected:
			return true
	return false
