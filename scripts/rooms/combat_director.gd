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
## Élites extra por oleada (sala de Desafío).
var extra_elites: int = 0

var _timer: float = 0.0
var _pending: Array[Dictionary] = []
var _bounty_given: bool = false


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
	enemy.gold_chance = Balance.economy.common_drop_chance 			/ maxf(count_multiplier * Scaling.current_count_multiplier(), 1.0)
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
