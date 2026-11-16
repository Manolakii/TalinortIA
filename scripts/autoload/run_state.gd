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
## Sala del stage donde aparece el Agucci tenebroso (una vez por stage, después del primer escenario).
var shade_room: int = -1
var shade_seen: bool = false
var pipo_visited: bool = false
## Desafíos (grietas de ida y vuelta): cuántos se entraron (cambia la semilla de la sala del
## desafío) y cuál fue el último (no se repite seguido).
var rift: int = 0
var last_challenge: int = -1
## Desafíos que ya salieron desde la última vuelta (como un mazo: salen todos antes de repetir).
var challenges_seen: Array[int] = []
## Adentro de un desafío no cae oro (pedido del grupo: la recompensa es la mejora).
var no_gold: bool = false
## Dificultad que sube por escenario (pedido del grupo). La pone StageRun al armar cada sala.
var enemy_health_bonus: float = 0.0
var enemy_damage_bonus: float = 0.0
var enemy_shield_chance: float = 0.0
var enemy_shield_ratio: float = 0.0
## La torreta aliada de Pipo espera a la sala siguiente.
var turret_pending: bool = false
## Dificultad elegida en la pantalla de unión (DifficultyConfig.Level).
var difficulty: int = DifficultyConfig.Level.NORMAL
## Bonus que se acumulan durante la partida, por jugador (por ejemplo, el Tiro por Contrato).
var _bonuses: Dictionary[String, int] = {}
## Objetos genéricos y mejoras de personaje de cada jugador (ids), por índice de jugador.
var items: Dictionary[int, Array] = {}
var upgrades: Dictionary[int, Array] = {}
## Objetos especiales comprados a Yole Sajor, por jugador.
var specials: Dictionary[int, Array] = {}
## Visitas a Birig Bamba en esta partida (0 = antes del Stage 1): elige la rareza del stock.
var visit: int = 0
## Vida de cada jugador al cambiar de escena (proporción) y si quedó afuera (GDD: vuelve en
## Birig Bamba con 40% y sin fuente). Por índice de jugador.
var party: Dictionary[int, Dictionary] = {}
## Tienda de Yole Sajor: stock de cada jugador en esta visita.
var shop_state: Dictionary[int, Dictionary] = {}
## Fuente: quién ya se curó en esta visita.
var fountain_used: Array[int] = []
## Para la McoinIA al terminar (GDD): escenarios superados, élites y bosses derrotados.
var scenarios_cleared: int = 0
var elites_killed: int = 0
var bosses_killed: int = 0
var mcoinia_awarded: bool = false
## Estadísticas de la partida por jugador (pantalla del final, pedido del grupo):
## {daño, recibido, enemigos, elites, caidas, oro}.
var stats: Dictionary[int, Dictionary] = {}
const STAT_KEYS: Array[StringName] = [&"damage", &"taken", &"kills", &"elites", &"downs", &"gold"]
## Segunda opinión (McoinIA): recompensas que cada jugador todavía puede volver a tirar.
var rerolls_left: Dictionary[int, int] = {}


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
	shade_room = -1
	shade_seen = false
	pipo_visited = false
	rift = 0
	last_challenge = -1
	challenges_seen.clear()
	no_gold = false
	turret_pending = false
	set_scenario_scaling(0.0, 0.0, 0.0, 0.0)
	_bonuses.clear()
	items.clear()
	upgrades.clear()
	specials.clear()
	visit = 0
	party.clear()
	shop_state.clear()
	fountain_used.clear()
	scenarios_cleared = 0
	elites_killed = 0
	bosses_killed = 0
	mcoinia_awarded = false
	stats.clear()
	rerolls_left.clear()
	for slot: PlayerSlot in PlayerManager.active_slots():
		gold[slot.index] = Balance.economy.starting_gold + int(MetaProgress.bonus(&"bolsillo_profundo"))
		rerolls_left[slot.index] = int(MetaProgress.bonus(&"segunda_opinion"))
	in_run = true
	print("Partida nueva, semilla: %d" % seed_value)
	Events.run_started.emit(seed_value)


func get_gold(slot_index: int) -> int:
	return gold.get(slot_index, 0)


func add_gold(slot_index: int, amount: int) -> void:
	gold[slot_index] = maxi(get_gold(slot_index) + amount, 0)
	if amount > 0:
		add_stat(slot_index, &"gold", amount)
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
	return hash([seed_value, stage, scenario, room_index, rooms_played, rift, salt])


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


# --- Objetos especiales ---

func get_specials(slot_index: int) -> Array:
	return specials.get(slot_index, [])


func has_special(slot_index: int, item_id: StringName) -> bool:
	return get_specials(slot_index).has(item_id)


func add_special(slot_index: int, item_id: StringName) -> void:
	if not specials.has(slot_index):
		specials[slot_index] = []
	specials[slot_index].append(item_id)
	Events.loadout_changed.emit(slot_index)


# --- Entre escenas ---

## Guarda la vida de cada jugador antes de cambiar de escena.
func save_party(players: Array) -> void:
	for node: Variant in players:
		var player := node as PlayerCharacter
		if player == null or not is_instance_valid(player):
			continue
		party[player.slot.index] = {
			"ratio": player.health.ratio() if not player.health.is_dead else 0.0,
			"out": player.is_out() or player.health.is_dead,
		}


## Vuelve de un stage a Birig Bamba: nueva visita (stock nuevo, fuente disponible) y el
## recorrido vuelve al principio para el stage que sigue.
func set_scenario_scaling(health_bonus: float, damage_bonus: float, shield_chance: float,
		shield_ratio: float) -> void:
	enemy_health_bonus = health_bonus
	enemy_damage_bonus = damage_bonus
	enemy_shield_chance = shield_chance
	enemy_shield_ratio = shield_ratio


func return_to_hub() -> void:
	set_scenario_scaling(0.0, 0.0, 0.0, 0.0)
	visit += 1
	shop_state.clear()
	fountain_used.clear()
	scenario = 0
	room_index = 0
	room_type = 0
	room_reward = 1


# --- McoinIA ---

func _ready() -> void:
	Events.enemy_died.connect(_on_enemy_died)
	Events.hit_landed.connect(_on_hit_landed_stats)
	Events.player_downed.connect(_on_player_downed_stats)


# --- Estadísticas de la partida ---

func get_stat(slot_index: int, key: StringName) -> float:
	return stats.get(slot_index, {}).get(key, 0.0)


func add_stat(slot_index: int, key: StringName, amount: float) -> void:
	if not in_run:
		return
	if not stats.has(slot_index):
		stats[slot_index] = {}
	stats[slot_index][key] = stats[slot_index].get(key, 0.0) + amount


## El jugador de un golpe (o de su compañero, como Stewie), o -1.
static func _slot_of(node: Variant) -> int:
	if not is_instance_valid(node):
		return -1
	if node is PlayerCharacter and (node as PlayerCharacter).slot != null:
		return (node as PlayerCharacter).slot.index
	if node is DuoCompanion:
		var kit: CharacterKit = (node as DuoCompanion).kit as CharacterKit
		if kit != null and is_instance_valid(kit.player) and kit.player.slot != null:
			return kit.player.slot.index
	return -1


func _on_hit_landed_stats(info: DamageInfo, target: Node3D) -> void:
	if not in_run or not is_instance_valid(target):
		return
	var hitter: int = _slot_of(info.attacker)
	if hitter >= 0 and target is Enemy:
		add_stat(hitter, &"damage", info.final_amount)
		if (target as Enemy).health.is_dead:
			add_stat(hitter, &"kills", 1)
			if (target as Enemy).is_elite:
				add_stat(hitter, &"elites", 1)
	var victim: int = _slot_of(target)
	if victim >= 0 and info.attacker_team == DamageInfo.Team.ENEMIES:
		add_stat(victim, &"taken", info.final_amount)


func _on_player_downed_stats(player: Node3D) -> void:
	var index: int = _slot_of(player)
	if index >= 0:
		add_stat(index, &"downs", 1)


func _on_enemy_died(enemy: Node3D) -> void:
	if not in_run:
		return
	if enemy is GronkGigante:
		bosses_killed += 1
	elif enemy is Enemy and (enemy as Enemy).is_elite:
		elites_killed += 1


## McoinIA de esta partida (GDD): 1 por escenario, 2 por élite, 8 por boss, 15 por ganar,
## por la dificultad.
func mcoinia_for(won: bool) -> int:
	var config: McoiniaConfig = Balance.mcoinia
	var total: float = scenarios_cleared * config.per_scenario + elites_killed * config.per_elite \
			+ bosses_killed * config.per_boss + (config.win_bonus if won else 0)
	return roundi(total * config.difficulty_multipliers[difficulty])


## Al terminar la partida (ganada o perdida): cobra la McoinIA una sola vez. Devuelve cuánto.
func award_mcoinia(won: bool) -> int:
	if mcoinia_awarded:
		return 0
	mcoinia_awarded = true
	var earned: int = mcoinia_for(won)
	MetaProgress.add(earned)
	return earned
