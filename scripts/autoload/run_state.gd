extends Node
## Estado de la partida en curso: semilla, oro por jugador y (más adelante)
## objetos, mejoras y escenario actual.

var seed_value: int = 0
## Generador de números al azar de la partida. Todo lo que dependa de la semilla sale de acá.
var rng := RandomNumberGenerator.new()
## Oro por índice de jugador (0 a 3).
var gold: Dictionary[int, int] = {}
var in_run: bool = false
## Stage actual: 0 = Stage 1 (Talinorthland), 1 = Stage 2, 2 = Stage 3. Elige la fila de las tablas de oro.
var stage: int = 0
## Escenario dentro del stage (0 = X-1, 1 = X-2, 2 = X-3) y sala dentro del escenario.
var scenario: int = 0
var room_index: int = 0
## Tipo de la sala actual (RoomKind.Type).
var room_type: int = 0
## Premio de la sala actual (RoomKind.Reward): el que mostraba la puerta.
var room_reward: int = 1
## Salas jugadas en total (para que cada sala tenga su propia semilla).
var rooms_played: int = 0
## Cabaña del General Pipo: en qué sala aparece el acertijo (-1 = sin elegir) y si ya se visitó.
var riddle_room: int = -1
var pipo_visited: bool = false
## La torreta aliada de Pipo espera a la sala siguiente.
var turret_pending: bool = false
## Dificultad elegida en la pantalla de unión (DifficultyConfig.Level).
var difficulty: int = DifficultyConfig.Level.NORMAL
## Bonus que se acumulan durante la partida, por jugador (por ejemplo, el Tiro por Contrato).
var _bonuses: Dictionary[String, int] = {}
## Objetos genéricos y mejoras de personaje de cada jugador (ids), por índice de jugador.
var items: Dictionary[int, Array] = {}
var upgrades: Dictionary[int, Array] = {}


## Arranca una partida. Con seed 0 se elige una al azar (y se imprime, para poder reproducir errores).
func start_run(new_seed: int = 0) -> void:
	if new_seed == 0:
		new_seed = randi_range(1, 2_000_000_000)
	seed_value = new_seed
	rng.seed = seed_value
	gold.clear()
	stage = 0
	scenario = 0
	room_index = 0
	room_type = 0
	room_reward = 1
	rooms_played = 0
	riddle_room = -1
	pipo_visited = false
	turret_pending = false
	_bonuses.clear()
	items.clear()
	upgrades.clear()
	for slot: PlayerSlot in PlayerManager.active_slots():
		gold[slot.index] = Balance.economy.starting_gold
	in_run = true
	print("Partida nueva, semilla: %d" % seed_value)
	Events.run_started.emit(seed_value)


func get_gold(slot_index: int) -> int:
	return gold.get(slot_index, 0)


func add_gold(slot_index: int, amount: int) -> void:
	gold[slot_index] = maxi(get_gold(slot_index) + amount, 0)
	Events.gold_changed.emit(slot_index, gold[slot_index])


func get_bonus(slot_index: int, key: StringName) -> int:
	return _bonuses.get("%d:%s" % [slot_index, key], 0)


func add_bonus(slot_index: int, key: StringName, amount: int) -> void:
	var k: String = "%d:%s" % [slot_index, key]
	_bonuses[k] = _bonuses.get(k, 0) + amount


func get_items(slot_index: int) -> Array:
	return items.get(slot_index, [])


func add_item(slot_index: int, item_id: StringName) -> void:
	if not items.has(slot_index):
		items[slot_index] = []
	items[slot_index].append(item_id)
	Events.loadout_changed.emit(slot_index)


func get_upgrades(slot_index: int) -> Array:
	return upgrades.get(slot_index, [])


func has_upgrade(slot_index: int, upgrade_id: StringName) -> bool:
	return get_upgrades(slot_index).has(upgrade_id)


func upgrade_count(slot_index: int, upgrade_id: StringName) -> int:
	return get_upgrades(slot_index).count(upgrade_id)


func add_upgrade(slot_index: int, upgrade_id: StringName) -> void:
	if not upgrades.has(slot_index):
		upgrades[slot_index] = []
	upgrades[slot_index].append(upgrade_id)
	Events.loadout_changed.emit(slot_index)


func end_run() -> void:
	in_run = false


# --- Recorrido del stage ---

## Semilla propia de la sala actual: la misma partida (semilla) arma las mismas salas.
func room_seed(salt: StringName = &"") -> int:
	return hash([seed_value, stage, scenario, room_index, rooms_played, salt])


func room_rng(salt: StringName = &"") -> RandomNumberGenerator:
	var generator := RandomNumberGenerator.new()
	generator.seed = room_seed(salt)
	return generator


## Número de sala dentro del stage (0 a 8 con 3 escenarios de 3 salas).
func stage_room_number(rooms_per_scenario: int) -> int:
	return scenario * rooms_per_scenario + room_index


func is_last_room_of_scenario(rooms_per_scenario: int) -> bool:
	return not RoomKind.is_bonus(room_type) and room_index >= rooms_per_scenario - 1


## Pasa a la sala elegida. El Tesoro escondido y la Cabaña de Pipo son salas extra: no cuentan.
func advance_to(next_type: int, rooms_per_scenario: int, reward: int = RoomKind.Reward.NONE) -> void:
	rooms_played += 1
	room_reward = reward
	if next_type == RoomKind.Type.PIPO_CABIN:
		pipo_visited = true
	if not RoomKind.is_bonus(next_type):
		room_index += 1
		if room_index >= rooms_per_scenario:
			room_index = 0
			scenario += 1
	room_type = next_type
