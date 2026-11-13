extends Node
## Estado de la partida en curso: semilla, oro por jugador y (más adelante)
## objetos, mejoras y escenario actual.

var seed_value: int = 0
## Generador de números al azar de la partida. Todo lo que dependa de la semilla sale de acá.
var rng := RandomNumberGenerator.new()
## Oro por índice de jugador (0 a 3).
var gold: Dictionary[int, int] = {}
var in_run: bool = false
## Bonus que se acumulan durante la partida, por jugador (por ejemplo, el Tiro por Contrato).
var _bonuses: Dictionary[String, int] = {}


## Arranca una partida. Con seed 0 se elige una al azar (y se imprime, para poder reproducir errores).
func start_run(new_seed: int = 0) -> void:
	if new_seed == 0:
		new_seed = randi_range(1, 2_000_000_000)
	seed_value = new_seed
	rng.seed = seed_value
	gold.clear()
	_bonuses.clear()
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


func end_run() -> void:
	in_run = false
