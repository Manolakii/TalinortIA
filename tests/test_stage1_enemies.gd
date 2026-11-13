extends "res://tests/helpers/kit_test.gd"
## Enemigos del Stage 1: Hondero, Soldado y Tirador Agucci, Chamán de la Sombra y Gronk.


func before_each() -> void:
	# Zonas, piedras y explosiones que hayan quedado de otro test.
	for node: Node in get_children():
		if node is ShadowZone or node is LobbedStone or node is EliteExplosion:
			node.free()
	RunState.difficulty = DifficultyConfig.Level.NORMAL
	make_player(&"croco")
	_player.kit.dodge_cooldown.charges = 0  # que no esquive solo por el buffer


func _spawn(id: StringName, pos: Vector3) -> Enemy:
	var enemy: Enemy = load("res://scenes/enemies/%s.tscn" % id).instantiate()
	enemy.position = pos
	add_child_autofree(enemy)
	var to_player := Vector3(-pos.x, 0.0, -pos.z)
	if to_player.length_squared() > 0.001:
		enemy.facing = to_player.normalized()
	return enemy


func _run(enemies: Array, frames: int, extra: Array = []) -> void:
	for i: int in frames:
		for enemy: Variant in enemies:
			if is_instance_valid(enemy):
				enemy._physics_process(DT)
		for node: Variant in extra:
			if is_instance_valid(node):
				node._physics_process(DT)
		for node: Node in get_children():
			if node is LobbedStone or node is ShadowZone:
				node._physics_process(DT)


func test_data_from_gdd() -> void:
	var expected: Dictionary = {
		&"hondero_cegado": [120.0, 8.0], &"soldado_agucci": [260.0, 16.0],
		&"tirador_agucci": [200.0, 6.0], &"chaman_sombra": [220.0, 0.0], &"gronk": [700.0, 25.0],
	}
	for id: StringName in expected:
		var data: EnemyData = Balance.get_enemy(id)
		assert_eq(data.max_health, expected[id][0], "%s: vida" % id)
		assert_eq(data.damage, expected[id][1], "%s: daño" % id)


func test_difficulty_scales_health_and_damage() -> void:
	RunState.difficulty = DifficultyConfig.Level.EASY
	var enemy := _spawn(&"soldado_agucci", Vector3(0, 0, -20))
	assert_almost_eq(enemy.health.max_health, 260.0 * 0.8, 0.01, "Fácil: ×0,8 de vida")
	assert_almost_eq(enemy.make_attack().amount, 16.0 * 0.7, 0.01, "Fácil: ×0,7 de daño")


func test_hondero_lobs_a_stone_with_a_warning() -> void:
	var hondero := _spawn(&"hondero_cegado", Vector3(0, 0, -8))
	hondero._cooldown = 0.0
	_run([hondero], 30)
	var stones: Array[Node] = get_children().filter(func(n: Node) -> bool: return n is LobbedStone)
	assert_eq(stones.size(), 1, "Tiró una piedra")
	assert_true((stones[0] as LobbedStone)._telegraph.visible, "Con círculo de aviso donde cae")
	_run([], 70)
	assert_eq(_player.health.current, 100.0 - 8.0, "La piedra pega 8")


func test_soldier_warns_then_dashes() -> void:
	var soldier := _spawn(&"soldado_agucci", Vector3(0, 0, -4))
	_run([soldier], 3)
	assert_eq(soldier.mode, SoldadoAgucci.Mode.WINDUP)
	assert_true(soldier.telegraph.visible, "Corte marcado en el piso")
	_run([soldier], 60)
	assert_eq(_player.health.current, 100.0 - 16.0, "El corte con dash pega 16")


func test_shooter_fires_a_fan() -> void:
	var shooter := _spawn(&"tirador_agucci", Vector3(0, 0, -8))
	shooter._cooldown = 0.0
	_run([shooter], 2)
	assert_true(shooter.telegraph.visible, "Abanico de aviso")
	var pool: ProjectilePool = shooter.enemy_projectiles()
	_run([shooter], 70, [pool])
	assert_almost_eq(fmod(100.0 - _player.health.current, 6.0), 0.0, 0.01, "Balas de 6")
	assert_gt(100.0 - _player.health.current, 0.0, "Al menos una bala de la ráfaga pegó")


func test_shaman_hastes_blinded_and_hurts_in_its_zone() -> void:
	var shaman := _spawn(&"chaman_sombra", Vector3(0, 0, -2))
	var blinded := _spawn(&"talinorteano_cegado", Vector3(3, 0, -6))
	await wait_physics_frames(1)  # la zona aparece al frame siguiente
	_run([shaman], 70)
	assert_true(blinded.status.has(StatusEffects.SHADOW_HASTE), "Acelera a los cegados")
	assert_almost_eq(blinded.speed_multiplier(), 1.2, 0.001, "+20%")
	assert_lt(_player.health.current, 100.0, "Su zona lastima")


func test_killing_the_shaman_stuns_and_wakes_blinded() -> void:
	var shaman := _spawn(&"chaman_sombra", Vector3(0, 0, -12))
	shaman.data = shaman.data.duplicate()
	shaman.data.wake_chance = 1.0
	var blinded := _spawn(&"talinorteano_cegado", Vector3(3, 0, -12))
	var kill := DamageInfo.new()
	kill.amount = 9999.0
	shaman.receive_hit(kill)
	assert_true(blinded.status.has(StatusEffects.STUN), "Los cegados se aturden 3 s")
	assert_true(blinded.awake, "Despierta y huye")
	assert_false(blinded.is_in_group(&"enemies"), "Ya no cuenta como enemigo")


func test_gronk_charges_tramples_and_crashes_into_walls() -> void:
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 3, 1)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(0, 1.5, 3.0)  # detrás del jugador
	add_child_autofree(wall)
	var gronk := _spawn(&"gronk", Vector3(0, 0, -9))
	var bystander := _spawn(&"talinorteano_cegado", Vector3(0.4, 0, -4.5))
	gronk._time = 1.0
	_run([gronk], 3)
	assert_eq(gronk.mode, Gronk.Mode.WINDUP)
	assert_true(gronk.telegraph.visible, "Carga con aviso")
	_run([gronk], 100)
	assert_eq(_player.health.current, 100.0 - 25.0, "Atropella: 25")
	assert_lt(bystander.health.current, 160.0, "También a otros enemigos")
	assert_true(gronk.status.has(StatusEffects.STUN) or gronk.mode == Gronk.Mode.RECOVER,
			"Choca contra la pared")
