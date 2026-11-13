extends "res://tests/helpers/kit_test.gd"
## Eventos: carreta, laberinto de los Gronks, barranco y el tiempo de los presos.

var _config: StageRoomsConfig
var _holder: Node3D
var _template: Node3D


func before_each() -> void:
	RunState.start_run(9)
	make_player(&"tali")
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
	assert_lt(event.cart.target_priority(), 1.0, "La prefieren")


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


# --- Barranco ---

func test_falling_into_the_chasm_hurts_and_sends_you_back() -> void:
	var event := ChasmEvent.new()
	_holder.add_child(event)
	event.setup(_config, _template, _rng())
	_player.global_position = Vector3(0, 0, ChasmEvent.BAND_MAX_Z + 1.0)
	event._physics_process(DT)
	# Al medio del barranco, donde no hay piedra.
	var spot := Vector3(22.5, 0, -1.0)
	_player.global_position = spot
	var before: float = _player.health.current
	for i: int in 15:
		event._physics_process(DT)
	assert_lt(_player.health.current, before, "Duele")
	assert_gt(_player.global_position.z, ChasmEvent.BAND_MAX_Z, "Vuelve al borde seguro")
	assert_eq(event.fall_count(), 1)


func test_tiles_crumble_after_stepping() -> void:
	var tile := ChasmTile.new()
	tile.crumble_delay = 0.5
	add_child_autofree(tile)
	tile.step_on()
	for i: int in int(0.6 / DT):
		tile._physics_process(DT)
	assert_false(tile.is_solid(), "Se cayó")


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
