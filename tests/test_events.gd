extends "res://tests/helpers/kit_test.gd"
## Eventos: carreta, laberinto de los Gronks, barranco y el tiempo de los presos.

var _config: StageRoomsConfig
var _holder: Node3D
var _template: Node3D


func before_each() -> void:
	RunState.start_run(9)
	make_player(&"croco")  # Tali a veces esquiva de casualidad: haría los tests inestables
	_config = Balance.stage_rooms(0)
	_holder = Node3D.new()
	add_child(_holder)
	_template = Node3D.new()
	_holder.add_child(_template)


func after_each() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		node.free()
	for node: Node in get_tree().get_nodes_in_group(&"chests"):
		node.free()
	if is_instance_valid(_holder):
		_holder.free()


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	return rng


# --- Carreta ---

func test_cart_only_moves_when_someone_pushes() -> void:
	var event := EscortEvent.new()
	_holder.add_child(event)
	event.setup(_config, _template, _rng())
	event.set_physics_process(false)
	var cart: EscortCart = event.cart
	_player.global_position = Vector3(20, 0, 12)
	for i: int in 60:
		cart._physics_process(DT)
	assert_eq(cart.progress(), 0.0, "Sola no anda")
	_player.global_position = cart.global_position + Vector3(2, 0, 0)
	for i: int in 60:
		cart._physics_process(DT)
	assert_gt(cart.progress(), 0.0, "Con alguien cerca, avanza")


func test_enemies_like_the_cart() -> void:
	var event := EscortEvent.new()
	_holder.add_child(event)
	event.setup(_config, _template, _rng())
	assert_true(event.cart.is_in_group(&"enemy_targets"))
	assert_eq(event.cart.target_priority(), 1.0, "Ya no la prefieren todos: cada enemigo decide")


func test_cart_arrival_gives_a_chest_and_perfect_event() -> void:
	var event := EscortEvent.new()
	_holder.add_child(event)
	event.setup(_config, _template, _rng())
	watch_signals(event)
	event.cart.arrived.emit()
	var chest: Chest = null
	for child: Node in event.get_children():
		if child is Chest:
			chest = child
	assert_not_null(chest)
	chest.open(_player)
	assert_signal_emitted_with_parameters(event, "resolved", [true])


# --- Laberinto ---

func test_maze_gronks_sleep_and_wake_with_noise() -> void:
	var event := MazeEvent.new()
	_holder.add_child(event)
	event.setup(_config, _template, _rng())
	var gronk: Enemy = event._gronks[0]
	assert_true(gronk.asleep, "Duermen")
	_player.global_position = gronk.global_position + Vector3(4.0, 0, 0)
	event._physics_process(DT)
	assert_true(gronk.asleep, "Caminar a 4 m no los despierta")
	_player.start_action(0.5)
	event._physics_process(DT)
	assert_false(gronk.asleep, "Pegar cerca sí")
	assert_gte(event.woken_count(), 1, "Despierta a los que estén cerca del ruido")


func test_maze_is_perfect_without_waking_anyone() -> void:
	var event := MazeEvent.new()
	_holder.add_child(event)
	event.setup(_config, _template, _rng())
	watch_signals(event)
	event._on_chest_opened(_player)
	assert_signal_emitted_with_parameters(event, "resolved", [true])


# --- Laberinto: si se despiertan demasiados, se pierde ---

func test_maze_lost_when_too_many_gronks_wake() -> void:
	var event := MazeEvent.new()
	_holder.add_child(event)
	event.setup(_config, _template, _rng())
	watch_signals(event)
	for gronk: Enemy in event._gronks:
		_player.global_position = gronk.global_position + Vector3(1.0, 0, 0)
		event._physics_process(DT)
	await wait_seconds(2.3)
	assert_signal_emitted_with_parameters(event, "resolved", [false])


# --- Estampida ---

func test_stampede_warns_then_tramples() -> void:
	var event := StampedeEvent.new()
	_holder.add_child(event)
	event.setup(_config, _rng())
	event._launch_herd(false)
	var herd: Dictionary = event._herds[0]
	assert_true((herd["warning"] as Telegraph).visible, "Primero el aviso naranja")
	# Ponemos al jugador en el carril.
	_player.global_position = (herd["from"] + herd["to"]) * 0.5
	var before: float = _player.health.current
	for i: int in int(3.5 / DT):
		event._move_herds(DT)
	assert_lt(_player.health.current, before, "La manada lo pisa")


func test_stampede_is_won_by_surviving() -> void:
	var event := StampedeEvent.new()
	_holder.add_child(event)
	event.setup(_config, _rng())
	watch_signals(event)
	event._time = _config.stampede_duration
	event._physics_process(DT)
	assert_signal_emitted_with_parameters(event, "resolved", [true])


func test_stampede_is_lost_if_someone_goes_down() -> void:
	var event := StampedeEvent.new()
	_holder.add_child(event)
	event.setup(_config, _rng())
	watch_signals(event)
	Events.player_downed.emit(_player)
	assert_signal_emitted_with_parameters(event, "resolved", [false])


# --- Carreta: los enemigos van variando ---

func test_escort_enemies_split_between_cart_and_players() -> void:
	var event := EscortEvent.new()
	_holder.add_child(event)
	event.setup(_config, _template, _rng())
	var enemies: Array[TalinorteanoCegado] = []
	for i: int in 20:
		enemies.append(enemy_at(Vector3(10 + i, 0, 0)))
	event._update_focus(DT)
	var on_cart: int = 0
	for enemy: TalinorteanoCegado in enemies:
		if enemy.focus_target == event.cart:
			on_cart += 1
		else:
			assert_true(enemy.ignored_targets.has(event.cart), "Los otros van por los jugadores")
	assert_between(on_cart, 2, 18, "Algunos por la carreta, no todos")


# --- Gronk: no se tira contra una roca ---

func test_gronk_goes_around_a_rock_instead_of_charging_into_it() -> void:
	var rock := RockProp.new()
	rock.size = Vector3(2.5, 1.6, 2.5)
	rock.position = Vector3(0, 0, -4.0)
	_holder.add_child(rock)
	var gronk: Gronk = load("res://scenes/enemies/gronk.tscn").instantiate()
	gronk.position = Vector3(0, 0, -8.0)
	_holder.add_child(gronk)
	gronk.facing = Vector3.BACK
	await wait_physics_frames(2)
	gronk._time = 1.0
	gronk._physics_process(DT)
	assert_ne(gronk.mode, Gronk.Mode.WINDUP, "Con la roca en el medio no carga")
	assert_eq(gronk.tactic, &"strafe", "La rodea")


# --- Presos con tiempo ---

func test_prisoners_are_lost_when_time_runs_out() -> void:
	var event := PrisonerEvent.new()
	_holder.add_child(event)
	var spots: Array[Vector3] = [Vector3(-4, 0, -2), Vector3(4, 0, -2)]
	event.setup(spots, 2, 2.5, 4, Vector3(0, 0, -3), 1.0)
	event._cages[0].free_prisoner()
	for i: int in int(1.2 / DT):
		event._physics_process(DT)
	assert_true(event._cages[1].is_lost, "Se acabó el tiempo: se lo llevaron")
	assert_eq(event.saved_count(), 1)


func test_gronk_is_stunned_if_it_crashes_into_a_rock() -> void:
	var rock := RockProp.new()
	rock.size = Vector3(2.5, 1.6, 2.5)
	rock.position = Vector3(0, 0, -4.0)
	_holder.add_child(rock)
	var gronk: Gronk = load("res://scenes/enemies/gronk.tscn").instantiate()
	gronk.position = Vector3(0, 0, -8.0)
	_holder.add_child(gronk)
	await wait_physics_frames(2)
	# Lo forzamos a cargar derecho contra la roca.
	gronk.facing = Vector3.BACK
	gronk._start_windup()
	gronk._charge_length = 8.0
	gronk._set_mode(Gronk.Mode.CHARGE)
	for i: int in 40:
		gronk._physics_process(DT)
	assert_true(gronk.status.has(StatusEffects.STUN), "Si igual se choca la roca, queda aturdido")


func test_maze_has_traps_that_hurt() -> void:
	var event := MazeEvent.new()
	_holder.add_child(event)
	event.setup(_config, _template, _rng())
	var traps: Array[MazeTrap] = []
	for child: Node in event.get_children():
		if child is MazeTrap:
			traps.append(child)
	assert_eq(traps.size(), _config.maze_guillotines + _config.maze_spikes, "Guillotinas y pinchos")
	var trap: MazeTrap = traps[0]
	# Croco (Tali a veces esquiva de casualidad, por su suerte).
	var croco: PlayerCharacter = make_player(&"croco", 1)
	_player.global_position = Vector3(30, 0, 30)
	croco.global_position = trap.global_position
	var before: float = croco.health.current
	trap._timer = 0.0
	for i: int in int(2.5 / DT):
		trap._physics_process(DT)
	assert_lt(croco.health.current, before, "Si te agarra, duele")


func test_director_can_stop_and_send_enemies_away() -> void:
	var director := CombatDirector.new()
	director.waves = Balance.stage_rooms(0).prisoner_waves
	_holder.add_child(director)
	var enemy := enemy_at(Vector3(5, 0, 0))
	director.stop_and_scatter()
	assert_eq(director.state, CombatDirector.Phase.CLEARED, "No vienen más oleadas")
	assert_true(enemy.awake, "Los que quedan se van")


func test_freed_prisoner_keeps_fighting_until_the_event_ends() -> void:
	var cage := PrisonerCage.new()
	_holder.add_child(cage)
	var enemy := enemy_at(Vector3(4, 0, 0), 1000.0)
	cage.free_prisoner()
	for i: int in int(5.0 / DT):
		cage._physics_process(DT)
	var after_five: float = 1000.0 - enemy.health.current
	assert_gt(after_five, PrisonerCage.STONE_DAMAGE * 3.0, "Más de 3 piedrazos: se queda peleando")
	cage.dismiss()
	var before: float = enemy.health.current
	for i: int in int(3.0 / DT):
		cage._physics_process(DT)
	assert_eq(enemy.health.current, before, "Al terminar el evento, se va")


func test_maze_path_always_has_traps_and_gronks() -> void:
	for seed_value: int in [1, 2, 3, 4, 5]:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var holder := Node3D.new()
		_holder.add_child(holder)
		var template := Node3D.new()
		holder.add_child(template)
		var event := MazeEvent.new()
		holder.add_child(event)
		event.setup(_config, template, rng)
		var path: Array[Vector2i] = event.path_cells()
		assert_eq(path[0].y, MazeEvent.ROWS - 1, "Arranca en la entrada")
		assert_eq(path[-1].y, 0, "Llega a la salida")
		var guillotines_on_path: int = 0
		for child: Node in event.get_children():
			var trap := child as MazeTrap
			if trap != null and trap.kind == MazeTrap.Kind.GUILLOTINE:
				for i: int in path.size() - 1:
					var a: Vector3 = event._cell_center(path[i].x, path[i].y)
					var b: Vector3 = event._cell_center(path[i + 1].x, path[i + 1].y)
					if trap.global_position.distance_to((a + b) * 0.5) < 0.5:
						guillotines_on_path += 1
		assert_gte(guillotines_on_path, mini(3, path.size() - 1), "El camino tiene guillotinas")
		for gronk: Enemy in event._gronks:
			gronk.free()
		holder.free()


func test_maze_gronks_always_leave_a_way_past() -> void:
	for seed_value: int in [1, 2, 3, 4, 5, 6, 7, 8]:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var holder := Node3D.new()
		_holder.add_child(holder)
		var template := Node3D.new()
		holder.add_child(template)
		var event := MazeEvent.new()
		holder.add_child(event)
		event.setup(_config, template, rng)
		assert_gte(event.gronk_spots.size(), 3, "Hay Gronks (semilla %d)" % seed_value)
		for spot: Dictionary in event.gronk_spots:
			assert_true(event.is_passable(spot["cell"], spot["offset"]),
					"Se puede pasar al lado del Gronk sin despertarlo (semilla %d)" % seed_value)
		for child: Node in event.get_children():
			if child is MazeTrap:
				assert_eq(child.find_children("*", "Telegraph", true, false).size(), 0,
						"Las trampas del laberinto no avisan en naranja")
		for gronk: Enemy in event._gronks:
			gronk.free()
		holder.free()


func test_a_gronk_in_the_middle_of_a_corridor_blocks_it() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var holder := Node3D.new()
	_holder.add_child(holder)
	var template := Node3D.new()
	holder.add_child(template)
	var event := MazeEvent.new()
	holder.add_child(event)
	event.setup(_config, template, rng)
	# En una celda con dos o más entradas, el centro exacto nunca deja pasar (la celda mide 4,5 m).
	for cell: Vector2i in event.path_cells():
		if event._openings(cell).size() >= 2 and event._openings(cell).has(&"west") and event._openings(cell).has(&"east"):
			assert_false(event.is_passable(cell, Vector3.ZERO))
	for gronk: Enemy in event._gronks:
		gronk.free()
	holder.free()
