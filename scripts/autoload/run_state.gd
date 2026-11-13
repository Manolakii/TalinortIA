extends Node
## Estado de la partida en curso: semilla, oro por jugador y (más adelante)
## objetos, mejoras y escenario actual.

var seed_value: int = 0
## Generador de números al azar de la partida. Todo lo que dependa de la semilla sale de acá.
var rng := RandomNumberGenerator.new()
## Oro por índice de jugador (0 a 3).
var gold: Dictionary[int, int] = {}
var in_run: bool = false
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
