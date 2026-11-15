class_name CombatDirector
extends Node3D
## Maneja una sala de combate: oleadas, élites, la Recompensa del Croco, y cuándo se gana
## (no quedan enemigos en la última oleada) o se pierde (cayeron todos los jugadores).

signal wave_started(index: int, total: int)
signal room_cleared
signal room_failed

enum Phase { WAITING, FIGHTING, CLEARED, FAILED }

const SPAWN_GAP := 0.12

var waves: RoomWaves
var state: Phase = Phase.WAITING
var wave_index: int = -1
var rng := RandomNumberGenerator.new()
## Multiplica los enemigos comunes (los escenarios más avanzados traen más).
var count_multiplier: float = 1.0
## Élites extra por oleada.
var extra_elites: int = 0
## Sala de aguante (pedido del grupo): si es > 0, no hay oleadas fijas; llegan tandas sin parar
## durante este tiempo y al terminar, los que quedan se van corriendo.
var survival_time: float = 0.0
var survival_interval: float = 2.2
var survival_max_alive: int = 12
## Multiplica la chance de oro de cada enemigo (en el aguante vienen muchos).
var gold_factor: float = 1.0
## Tiempo que falta en el aguante.
var time_left: float = 0.0

var _timer: float = 0.0
var _pending: Array[Dictionary] = []
var _bounty_given: bool = false
var _survival_started: bool = false
var _group_index: int = 0
var _gap: float = 0.0


func _ready() -> void:
	add_to_group(&"combat_director")
	rng.seed = RunState.room_seed(&"director")
	_timer = waves.wave_delay


func _physics_process(delta: float) -> void:
	if state == Phase.CLEARED or state == Phase.FAILED:
		return
	if _all_players_down():
		state = Phase.FAILED
		room_failed.emit()
		return
	if survival_time > 0.0:
		_survival_tick(delta)
		return
	if not _pending.is_empty():
		_timer -= delta
		if _timer <= 0.0:
			_timer = SPAWN_GAP
			_spawn(_pending.pop_front())
		return
	match state:
		Phase.WAITING:
			_timer -= delta
			if _timer <= 0.0:
				_start_wave(wave_index + 1)
		Phase.FIGHTING:
			if alive_enemies() == 0:
				Events.wave_cleared.emit(wave_index)
				if wave_index + 1 >= waves.waves.size():
					state = Phase.CLEARED
					room_cleared.emit()
					Events.room_cleared.emit()
				else:
					state = Phase.WAITING
					_timer = waves.wave_delay


func _survival_tick(delta: float) -> void:
	if not _survival_started:
		_survival_started = true
		time_left = survival_time
		state = Phase.FIGHTING
		_timer = 0.3
		Events.floating_text_requested.emit(_players_center() + Vector3.UP * 4.0,
				"¡Aguanten %d segundos!" % roundi(survival_time), Color.WHITE)
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		stop_and_scatter()
		room_cleared.emit()
		return
	if not _pending.is_empty():
		_gap -= delta
		if _gap <= 0.0:
			_gap = SPAWN_GAP
			_spawn(_pending.pop_front())
	_timer -= delta
	if _timer > 0.0 or alive_enemies() + _pending.size() >= max_alive():
		return
	# Hacia el final llegan más seguido.
	var progress: float = 1.0 - time_left / survival_time
	_timer = survival_interval * lerpf(1.0, 0.6, progress)
	var players: int = Scaling.players_for_scaling()
	for entry: RoomWaves.Entry in RoomWaves.parse_wave(waves.waves[_group_index % waves.waves.size()]):
		var count: int = Scaling.enemy_count(Balance.difficulty, RunState.difficulty, players,
				roundi(entry.count * count_multiplier))
		for i: int in count:
			_pending.append({"id": entry.enemy_id, "elite": false})
	_group_index += 1


## Máximo de enemigos vivos a la vez en el aguante.
func max_alive() -> int:
	return roundi(survival_max_alive * (1.0 + 0.25 * (Scaling.players_for_scaling() - 1)))


func alive_enemies() -> int:
	return get_tree().get_nodes_in_group(&"enemies").size()


func total_waves() -> int:
	return waves.waves.size()


func _start_wave(index: int) -> void:
	wave_index = index
	state = Phase.FIGHTING
	var players: int = Scaling.players_for_scaling()
	var config: DifficultyConfig = Balance.difficulty
	for entry: RoomWaves.Entry in RoomWaves.parse_wave(waves.waves[index]):
		var commons: int = roundi((entry.count - entry.elites) * count_multiplier)
		var scaled: int = Scaling.enemy_count(config, RunState.difficulty, players, commons)
		for i: int in scaled:
			_pending.append({"id": entry.enemy_id, "elite": false})
		for i: int in entry.elites:
			_pending.append({"id": entry.enemy_id, "elite": true})
	# Élites extra según la dificultad (de los tipos de esta oleada, menos el Chamán).
	var entries: Array[RoomWaves.Entry] = RoomWaves.parse_wave(waves.waves[index])
	var fighters: Array[StringName] = []
	for entry: RoomWaves.Entry in entries:
		if entry.enemy_id != &"chaman_sombra":
			fighters.append(entry.enemy_id)
	for i: int in config.extra_elites_per_wave[RunState.difficulty] + extra_elites:
		if not fighters.is_empty():
			_pending.append({"id": fighters[rng.randi_range(0, fighters.size() - 1)], "elite": true,
					"extra": true})
	_pending.shuffle()
	_timer = 0.0
	wave_started.emit(index, waves.waves.size())
	Events.floating_text_requested.emit(_players_center() + Vector3.UP * 4.0,
			"Oleada %d de %d" % [index + 1, waves.waves.size()], Color.WHITE)


func _spawn(spec: Dictionary) -> void:
	var enemy: Enemy = load("res://scenes/enemies/%s.tscn" % spec["id"]).instantiate()
	if spec["elite"]:
		enemy.make_elite(Balance.difficulty.elite_affixes[RunState.difficulty], rng)
		if not _bounty_given and _croco_in_team():
			_bounty_given = true
			enemy.has_bounty = true
	enemy.position = _pick_position()
	# Más enemigos que la base (más jugadores, más dificultad o escenario avanzado) = cada uno
	# suelta oro con menos chance: el oro por jugador queda como en el GDD.
	enemy.gold_chance = Balance.economy.common_drop_chance * gold_factor 			/ maxf(count_multiplier * Scaling.current_count_multiplier(), 1.0)
	# Los élites extra (dificultad o Desafío) pagan como un común: si no, se llenaba de oro.
	enemy.elite_gold = not spec.get("extra", false)
	get_parent().add_child(enemy)
	Fx.ring_burst(get_parent(), enemy.position, 1.2, Color(0.6, 0.55, 0.65), 0.3)


func _croco_in_team() -> bool:
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var player := node as PlayerCharacter
		if player != null and player.kit is CrocoKit:
			return true
	return false


func _all_players_down() -> bool:
	var players: Array[Node] = get_tree().get_nodes_in_group(&"players")
	if players.is_empty():
		return false
	for node: Node in players:
		var player := node as PlayerCharacter
		if player != null and not player.health.is_dead:
			return false
	return true


func _players_center() -> Vector3:
	var sum := Vector3.ZERO
	var players: Array[Node] = get_tree().get_nodes_in_group(&"players")
	for node: Node in players:
		sum += (node as Node3D).global_position
	return sum / maxf(players.size(), 1)


func _pick_position() -> Vector3:
	var best := Vector3.ZERO
	var best_distance: float = -1.0
	for attempt: int in 16:
		var candidate := global_position + Vector3(
				rng.randf_range(-0.5, 0.5) * waves.spawn_area.x, 0.0,
				rng.randf_range(-0.5, 0.5) * waves.spawn_area.y)
		if _is_blocked(candidate):
			continue
		var nearest: float = INF
		for node: Node in get_tree().get_nodes_in_group(&"players"):
			var p := node as Node3D
			nearest = minf(nearest, Vector2(candidate.x - p.global_position.x,
					candidate.z - p.global_position.z).length())
		if nearest >= waves.min_spawn_distance:
			return candidate
		if nearest > best_distance:
			best_distance = nearest
			best = candidate
	return best


## ¿Hay una roca o pared ahí? (para no hacer aparecer enemigos adentro).
func _is_blocked(point: Vector3) -> bool:
	if not is_inside_tree():
		return false
	var sphere := SphereShape3D.new()
	sphere.radius = 0.9
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * 0.9)
	query.collision_mask = 1 | 512
	return not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


## Corta la pelea: no vienen más oleadas y los enemigos que quedan se van corriendo.
## (Eventos que terminan antes, como la Colonia de presos cuando se acaba el tiempo.)
func stop_and_scatter() -> void:
	_pending.clear()
	state = Phase.CLEARED
	set_physics_process(false)
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy != null and enemy.is_targetable():
			enemy.wake_and_flee()
	Events.room_cleared.emit()
