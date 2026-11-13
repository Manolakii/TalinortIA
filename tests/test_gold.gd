extends "res://tests/helpers/kit_test.gd"
## Oro individual: monedas por jugador, vasijas, cofres y valores del GDD.


func before_each() -> void:
	RunState.start_run(11)
	make_player(&"tali")
	RunState.gold[0] = 0


func after_each() -> void:
	for group: StringName in [&"breakables", &"chests"]:
		for node: Node in get_tree().get_nodes_in_group(group):
			node.free()
	for child: Node in get_children():
		if child is GoldCoin:
			child.free()


func _coins() -> Array[GoldCoin]:
	var result: Array[GoldCoin] = []
	for child: Node in get_children():
		if child is GoldCoin and not child.is_queued_for_deletion():
			result.append(child)
	return result


func _coin_total() -> int:
	var total: int = 0
	for coin: GoldCoin in _coins():
		total += coin.value
	return total


func test_amounts_follow_the_stage_tables() -> void:
	var economy: EconomyConfig = Balance.economy
	for i: int in 30:
		var value: int = Loot.amount_for(economy.common_gold, 0)
		assert_between(value, 2, 4)
	assert_eq(Loot.amount_for(economy.elite_gold, 0), 20)
	assert_eq(Loot.amount_for(economy.elite_gold, 2), 55, "Stage 3")
	assert_between(Loot.amount_for(economy.chest_gold, 0), 50, 80)


func test_drop_splits_into_coins_of_the_owner() -> void:
	Loot.drop(self, Vector3.ZERO, _player, 23)
	var coins: Array[GoldCoin] = _coins()
	assert_eq(coins.size(), 5, "23 de oro en monedas de hasta 5")
	assert_eq(_coin_total(), 23)
	for coin: GoldCoin in coins:
		assert_eq(coin.owner_player, _player)


func test_gold_multiplier_applies() -> void:
	RunState.add_item(0, &"moneda_con_agujero")
	Loot.drop(self, Vector3.ZERO, _player, 20)
	assert_eq(_coin_total(), 22, "+10% de oro")


func test_coins_fly_to_owner_and_add_gold() -> void:
	Loot.drop(self, Vector3(1.0, 0, 0), _player, 10)
	for i: int in 120:
		for coin: GoldCoin in _coins():
			coin._physics_process(DT)
	assert_eq(RunState.get_gold(0), 10)
	assert_eq(_coins().size(), 0)


func test_far_coins_wait_until_room_cleared() -> void:
	Loot.drop(self, Vector3(12.0, 0, 0), _player, 10)
	for i: int in 60:
		for coin: GoldCoin in _coins():
			coin._physics_process(DT)
	assert_eq(RunState.get_gold(0), 0, "Lejos: no se junta sola")
	Events.room_cleared.emit()
	for i: int in 120:
		for coin: GoldCoin in _coins():
			coin._physics_process(DT)
	assert_eq(RunState.get_gold(0), 10, "Al terminar la sala vuelan al dueño")


func test_each_player_gets_their_own_gold() -> void:
	var p2: PlayerCharacter = make_player(&"croco", 1)
	RunState.gold[1] = 0
	Loot.drop_for_all(self, Vector3.ZERO, Balance.economy.elite_gold)
	var per_player: Dictionary = {}
	for coin: GoldCoin in _coins():
		per_player[coin.slot_index] = per_player.get(coin.slot_index, 0) + coin.value
	assert_eq(per_player.get(0, 0), 20)
	assert_eq(per_player.get(1, 0), 20, "Cada uno sus 20, no se reparten")
	assert_not_null(p2)


func test_vase_breaks_with_a_hit_and_drops_gold() -> void:
	var chance: float = Balance.economy.vase_drop_chance
	Balance.economy.vase_drop_chance = 1.0
	var vase := Vase.new()
	vase.position = Vector3(0, 0, -1.2)
	add_child(vase)
	await wait_physics_frames(1)
	var info: DamageInfo = _player.kit.make_hit(10.0)
	Combat.deliver(info, CombatQuery.in_sector(get_tree(), DamageInfo.Team.ENEMIES, Vector3.ZERO,
			Vector3.FORWARD, 2.0, 90.0))
	Balance.economy.vase_drop_chance = chance
	assert_true(vase._broken, "Se rompe de un golpe")
	assert_between(_coin_total(), 2, 6)


func test_vases_do_not_always_have_gold() -> void:
	var with_gold: int = 0
	for i: int in 40:
		var vase := Vase.new()
		add_child(vase)
		var before: int = _coins().size()
		vase.smash()
		if _coins().size() > before:
			with_gold += 1
	assert_between(with_gold, 8, 32, "Alrededor de la mitad tiene oro")


func test_vase_gold_is_only_for_who_broke_it() -> void:
	var p2: PlayerCharacter = make_player(&"croco", 1)
	var chance: float = Balance.economy.vase_drop_chance
	Balance.economy.vase_drop_chance = 1.0
	var vase := Vase.new()
	add_child(vase)
	var info: DamageInfo = p2.kit.make_hit(10.0)
	vase.receive_hit(info)
	Balance.economy.vase_drop_chance = chance
	assert_gt(_coins().size(), 0)
	for coin: GoldCoin in _coins():
		assert_eq(coin.slot_index, 1, "Solo para el que la rompió (P2)")


func test_aim_ignores_vases() -> void:
	var vase := Vase.new()
	vase.position = Vector3(1.0, 0, -2.0)
	add_child(vase)
	await wait_physics_frames(1)
	assert_null(CombatQuery.nearest(get_tree(), DamageInfo.Team.ENEMIES, Vector3.ZERO))
	assert_eq(CombatQuery.hurtboxes(get_tree(), DamageInfo.Team.ENEMIES).size(), 1, "Pero se le puede pegar")


func test_chest_opens_with_interact() -> void:
	var chest := Chest.new()
	chest.position = Vector3(0, 0, -1.4)
	add_child(chest)
	await wait_physics_frames(1)
	press(PlayerInput.Action.INTERACT)
	chest._physics_process(DT)
	assert_true(chest.is_open)
	assert_between(_coin_total(), 50, 80)


func test_elite_always_drops_gold() -> void:
	var enemy := enemy_at(Vector3(0, 0, -3), 10.0)
	enemy.is_elite = true
	enemy._drop_gold()
	assert_eq(_coin_total(), 20)
