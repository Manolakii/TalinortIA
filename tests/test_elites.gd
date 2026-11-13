extends "res://tests/helpers/kit_test.gd"
## Élites con afijos y la Recompensa del Croco.


func before_each() -> void:
	RunState.difficulty = DifficultyConfig.Level.NORMAL
	RunState.start_run(5)
	make_player(&"croco")


func _elite(id: StringName, pos: Vector3, affix: StringName) -> Enemy:
	var enemy: Enemy = load("res://scenes/enemies/%s.tscn" % id).instantiate()
	enemy.is_elite = true
	enemy.affixes = [affix] as Array[StringName]
	enemy.position = pos
	add_child_autofree(enemy)
	enemy.facing = Vector3(-pos.x, 0.0, -pos.z).normalized()
	return enemy


func _hit_from(enemy: Enemy, from: Vector3, amount: float, attacker: Node3D = null) -> void:
	var info := DamageInfo.new()
	info.amount = amount
	info.origin = from
	info.attacker = attacker
	info.attacker_team = DamageInfo.Team.PLAYERS
	enemy.receive_hit(info)


func test_elite_has_two_and_a_half_times_health() -> void:
	var elite := _elite(&"soldado_agucci", Vector3(0, 0, -10), &"fast")
	assert_almost_eq(elite.health.max_health, 260.0 * 2.5, 0.01)


func test_make_elite_picks_distinct_affixes() -> void:
	var enemy: Enemy = load("res://scenes/enemies/gronk.tscn").instantiate()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	enemy.make_elite(2, rng)
	assert_eq(enemy.affixes.size(), 2, "En Difícil, dos afijos")
	assert_ne(enemy.affixes[0], enemy.affixes[1])
	enemy.free()


func test_armored_takes_half_from_the_front() -> void:
	var elite := _elite(&"soldado_agucci", Vector3(0, 0, -5), &"armored")
	var start: float = elite.health.current
	_hit_from(elite, Vector3.ZERO, 100.0)  # de frente
	assert_almost_eq(start - elite.health.current, 50.0, 0.01, "De frente, la mitad")
	_hit_from(elite, Vector3(0, 0, -10), 100.0)  # por la espalda
	assert_almost_eq(start - elite.health.current, 150.0, 0.01, "Por la espalda, completo")


func test_fast_moves_faster() -> void:
	var elite := _elite(&"talinorteano_cegado", Vector3(0, 0, -10), &"fast")
	assert_almost_eq(elite.speed_multiplier(), 1.4, 0.001)


func test_explosive_warns_then_explodes_on_death() -> void:
	var elite := _elite(&"talinorteano_cegado", Vector3(0, 0, -1.5), &"explosive")
	_hit_from(elite, Vector3.ZERO, 99999.0)
	var blasts: Array[Node] = get_children().filter(func(n: Node) -> bool: return n is EliteExplosion)
	assert_eq(blasts.size(), 1, "Deja un aviso de explosión")
	for i: int in 60:
		if is_instance_valid(blasts[0]):
			blasts[0]._physics_process(DT)
	assert_eq(_player.health.current, 100.0 - 20.0, "Explota: 20")


func test_shadowy_leaves_slowing_puddles() -> void:
	var elite := _elite(&"talinorteano_cegado", Vector3(0, 0, -3), &"shadowy")
	elite._move_velocity = Vector3(1, 0, 0)
	elite._drop_puddles(0.016)
	var puddles: Array[Node] = get_children().filter(func(n: Node) -> bool: return n is ShadowZone)
	assert_eq(puddles.size(), 1)
	puddles[0].global_position = Vector3.ZERO
	puddles[0]._physics_process(DT)
	assert_true(_player.status.has(StatusEffects.SLOW), "El charco ralentiza")


func test_bounty_pays_only_the_croco() -> void:
	var elite := _elite(&"talinorteano_cegado", Vector3(0, 0, -10), &"fast")
	elite.set_bounty()
	var gold_before: int = RunState.get_gold(0)
	_hit_from(elite, Vector3.ZERO, 99999.0, _player)
	assert_eq(RunState.get_gold(0) - gold_before, Balance.economy.croco_bounty_gold,
			"El Croco cobra la Recompensa")
	var tali: PlayerCharacter = make_player(&"tali", 1)
	var other := _elite(&"talinorteano_cegado", Vector3(0, 0, -12), &"fast")
	other.set_bounty()
	var tali_gold: int = RunState.get_gold(1)
	_hit_from(other, Vector3.ZERO, 99999.0, tali)
	assert_eq(RunState.get_gold(1), tali_gold, "Si lo mata otro, no hay Recompensa")
