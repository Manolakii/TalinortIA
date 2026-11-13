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

var _timer: float = 0.0
var _pending: Array[Dictionary] = []
var _bounty_given: bool = false


func _ready() -> void:
	add_to_group(&"combat_director")
	rng.seed = RunState.seed_value
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
				if wave_index + 1 >= waves.waves.size():
					state = Phase.CLEARED
					room_cleared.emit()
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
		var commons: int = entry.count - entry.elites
		var scaled: int = Scaling.enemy_count(config, RunState.difficulty, players, commons)
		for i: int in scaled:
			_pending.append({"id": entry.enemy_id, "elite": false})
		for i: int in entry.elites:
			_pending.append({"id": entry.enemy_id, "elite": true})
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
