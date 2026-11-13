extends "res://tests/helpers/kit_test.gd"
## Recorrido del stage: avance de salas, premios 1 de 3, puertas y eventos.


func before_each() -> void:
	RunState.start_run(5)
	make_player(&"tali")


func after_each() -> void:
	for group: StringName in [&"breakables", &"chests", &"enemies"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			node.free()
	for child: Node in get_children():
		if child is GoldCoin or child is RewardPicker or child is MimicEvent or child is PrisonerEvent \
				or child is PipoRiddle:
			child.free()


func test_three_rooms_per_scenario_and_cabin_does_not_count() -> void:
	assert_eq(RunState.scenario, 0)
	RunState.advance_to(RoomKind.Type.COMBAT, 3)
	RunState.advance_to(RoomKind.Type.ELITE, 3)
	assert_eq(RunState.room_index, 2)
	assert_true(RunState.is_last_room_of_scenario(3))
	RunState.advance_to(RoomKind.Type.PIPO_CABIN, 3)
	assert_eq(RunState.room_index, 2, "La Cabaña es una sala extra")
	assert_false(RunState.is_last_room_of_scenario(3))
	assert_true(RunState.pipo_visited)
	RunState.advance_to(RoomKind.Type.COMBAT, 3)
	assert_eq(RunState.scenario, 1, "Pasa al 1-2")
	assert_eq(RunState.room_index, 0)


func test_each_room_has_its_own_seed() -> void:
	var first: int = RunState.room_seed(&"layout")
	RunState.advance_to(RoomKind.Type.COMBAT, 3)
	assert_ne(RunState.room_seed(&"layout"), first)
	RunState.start_run(5)
	assert_eq(RunState.room_seed(&"layout"), first, "Misma semilla, misma sala")


func test_upgrade_picker_gives_the_chosen_one() -> void:
	var picker := RewardPicker.new()
	add_child(picker)
	picker.start(RewardPicker.Kind.UPGRADE, [_player] as Array[PlayerCharacter])
	assert_true(_player.menu_locked, "Mientras elige no se mueve")
	var options: Array = picker._choices[0].options
	assert_eq(options.size(), 3)
	picker.pick(0, 1)
	assert_true(RunState.has_upgrade(0, options[1]["id"]))
	assert_false(_player.menu_locked)
	assert_true(picker.is_done())


func test_item_picker_adds_an_item() -> void:
	var picker := RewardPicker.new()
	add_child(picker)
	picker.start(RewardPicker.Kind.ITEM, [_player] as Array[PlayerCharacter])
	var options: Array = picker._choices[0].options
	assert_eq(options.size(), 3)
	picker.pick(0, 0)
	assert_eq(RunState.get_items(0), [options[0]["id"]])


func test_menu_navigation_with_up_and_down() -> void:
	var picker := RewardPicker.new()
	add_child(picker)
	picker.start(RewardPicker.Kind.ITEM, [_player] as Array[PlayerCharacter])
	picker._wait = 0.0
	press(PlayerInput.Action.DOWN)
	picker._physics_process(DT)
	release(PlayerInput.Action.DOWN)
	press(PlayerInput.Action.DOWN)
	picker._physics_process(DT)
	assert_eq(picker._choices[0].selected, 2)
	release(PlayerInput.Action.DOWN)
	press(PlayerInput.Action.CONFIRM)
	picker._physics_process(DT)
	assert_true(picker.is_done())


func test_riddle_right_answer_is_the_stone() -> void:
	var riddle := PipoRiddle.new()
	add_child(riddle)
	riddle.setup(RunState.room_rng(&"test"))
	watch_signals(riddle)
	riddle.choose(riddle.correct_index())
	assert_signal_emitted(riddle, "solved")


func test_riddle_wrong_answer_closes_it() -> void:
	var riddle := PipoRiddle.new()
	add_child(riddle)
	riddle.setup(RunState.room_rng(&"test"))
	watch_signals(riddle)
	riddle.choose((riddle.correct_index() + 1) % 3)
	riddle.choose(riddle.correct_index())
	assert_signal_emitted(riddle, "failed")
	assert_signal_not_emitted(riddle, "solved", "Una sola oportunidad")


func test_mimic_event_one_chest_only_and_the_mimic_bites() -> void:
	var event := MimicEvent.new()
	add_child(event)
	event.setup([Vector3(-3, 0, -4), Vector3(0, 0, -4), Vector3(3, 0, -4)] as Array[Vector3], RunState.room_rng(&"t"))
	var mimic_chest: Chest = null
	for chest: Chest in event._chests:
		if chest.is_mimic:
			mimic_chest = chest
	assert_not_null(mimic_chest, "Uno de los tres es mimic")
	watch_signals(event)
	mimic_chest.open(_player)
	assert_true(event.mimic_alive(), "Sale el mimic")
	assert_signal_not_emitted(event, "resolved")
	for chest: Chest in event._chests:
		if chest != mimic_chest:
			assert_true(chest.locked, "Los otros se cierran")
	var hit: DamageInfo = _player.kit.make_hit(99999.0)
	event._mimic.receive_hit(hit)
	assert_signal_emitted(event, "resolved", "Matándolo, el premio")


func test_prisoners_give_gold_and_chest_at_the_end() -> void:
	var event := PrisonerEvent.new()
	add_child(event)
	var spots: Array[Vector3] = [Vector3(-4, 0, -2), Vector3(4, 0, -2), Vector3(0, 0, -6), Vector3(0, 0, 2)]
	event.setup(spots, 4, 1.5, 6, Vector3(0, 0, -3))
	event._cages[0].free_prisoner()
	assert_eq(event.saved_count(), 1)
	var coins: int = 0
	for child: Node in event.get_children():
		if child is GoldCoin:
			coins += (child as GoldCoin).value
	assert_eq(coins, 6, "6 de oro por preso")
	watch_signals(event)
	event.finish_combat()
	var chest: Chest = null
	for child: Node in event.get_children():
		if child is Chest:
			chest = child
	assert_not_null(chest, "Cofre de evento al final")
	chest.open(_player)
	assert_signal_emitted_with_parameters(event, "resolved", [false])


func test_cage_opens_holding_interact() -> void:
	var cage := PrisonerCage.new()
	cage.position = Vector3(0, 0, -1.2)
	add_child_autofree(cage)
	hold(PlayerInput.Action.INTERACT)
	for i: int in int(1.6 / DT):
		cage._physics_process(DT)
	assert_true(cage.is_free)
