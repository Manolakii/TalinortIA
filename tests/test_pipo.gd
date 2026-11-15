extends "res://tests/helpers/kit_test.gd"
## Kit del General Pipo.

var _kit: PipoKit


func before_each() -> void:
	RunState.start_run(1)
	make_player(&"pipo")
	_kit = _player.kit as PipoKit
	_kit.kd = _kit.kd.duplicate()
	_kit.kd.cone_crit_chance = 0.0  # sin azar en los números
	_player.aim_direction = Vector3.FORWARD


func _pump(frames: int, extra: Array = []) -> void:
	step(frames, [_kit._bolts] + extra)


func _enemy_hit(amount: float, from: Vector3) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = amount
	info.attacker_team = DamageInfo.Team.ENEMIES
	info.origin = from
	return info


func test_blaster_damage_and_third_shot_marks() -> void:
	var enemy := enemy_at(Vector3(0, 0, -6), 1000.0)
	_slot.input._held[PlayerInput.Action.ATTACK] = true
	_pump(30)
	assert_almost_eq(1000.0 - enemy.health.current, 32.0, 0.01, "Un tiro de 32")
	assert_false(enemy.status.has(StatusEffects.TACTICAL_MARK))
	_pump(90)  # tiros a los 0,7 y 1,4 s
	assert_true(enemy.status.has(StatusEffects.TACTICAL_MARK), "El tercer tiro marca")


func test_mark_adds_twenty_percent() -> void:
	var enemy := enemy_at(Vector3(0, 0, -6), 1000.0)
	enemy.status.apply(StatusEffects.TACTICAL_MARK, 6.0)
	var info: DamageInfo = _kit.make_hit(100.0)
	info.hitstop = 0.0
	enemy.hurtbox.take_hit(info)
	assert_almost_eq(1000.0 - enemy.health.current, 120.0, 0.01, "Marca Táctica: +20%")


func test_blind_spot_on_the_left() -> void:
	var start: float = _player.health.current
	_player.receive_hit(_enemy_hit(10.0, Vector3(-3, 0, 0)))
	assert_almost_eq(start - _player.health.current, 11.5, 0.01, "Desde la izquierda: +15%")
	_player.health._invulnerable_left = 0.0
	var mid: float = _player.health.current
	_player.receive_hit(_enemy_hit(10.0, Vector3(3, 0, 0)))
	assert_almost_eq(mid - _player.health.current, 10.0, 0.01, "Desde la derecha: normal")


func test_turret_deploys_and_caps_at_two() -> void:
	for i: int in 3:
		_kit.turret_cooldown.refill()
		_player.end_action()
		press(PlayerInput.Action.ABILITY)
		_pump(1)
		release(PlayerInput.Action.ABILITY)
		_pump(25)
	assert_eq(_kit.turrets.size(), 2, "Máximo 2 torretas: la más vieja se desarma")


func test_turret_prefers_marked_enemy() -> void:
	var near := enemy_at(Vector3(0, 0, -3), 1000.0)
	var marked := enemy_at(Vector3(4, 0, -6), 1000.0)
	marked.status.apply(StatusEffects.TACTICAL_MARK, 6.0)
	press(PlayerInput.Action.ABILITY)
	_pump(1)
	var turret: PipoTurret = _kit.turrets[0]
	for i: int in 40:
		turret._physics_process(DT)
	assert_eq(near.health.current, 1000.0, "No le tira al más cercano")
	assert_lt(marked.health.current, 1000.0, "Le tira al marcado")


func test_retreat_leaves_mine_that_explodes() -> void:
	press(PlayerInput.Action.DODGE)
	_pump(1)
	var mine: PipoMine = null
	for child: Node in get_children():
		if child is PipoMine:
			mine = child
	assert_not_null(mine, "El repliegue deja una mina")
	assert_gt(_player.global_position.z, 0.0, "Salta hacia atrás (al revés de donde apunta)")
	var enemy := enemy_at(mine.global_position + Vector3(0.5, 0, 0), 1000.0)
	for i: int in 40:
		if is_instance_valid(mine):
			mine._physics_process(DT)
	assert_almost_eq(1000.0 - enemy.health.current, 50.0, 0.01, "Mina: 50")


func test_bombard_impact() -> void:
	var enemy := enemy_at(Vector3(0, 0, -8), 1000.0)
	_kit._impact(Vector3(0, 0, -8))
	assert_almost_eq(1000.0 - enemy.health.current, 90.0, 0.01, "Cada impacto: 90")


func test_cabin_easter_egg_gives_crown_to_pipo() -> void:
	var cabin := PipoCabin.new()
	add_child_autofree(cabin)
	cabin._physics_process(DT)
	assert_false(cabin._pipo.visible, "Con Pipo en el equipo, el Pipo de la cabaña no está")
	watch_signals(cabin)
	cabin.open_secret_door()
	assert_not_null(cabin._leader, "Adentro está el Líder Supremo")
	cabin.give_crown()
	assert_true(RunState.has_special(0, &"corona_lider"), "Le da la corona al jugador Pipo")
	assert_signal_emitted(cabin, "resolved")


func test_upgrades_change_numbers() -> void:
	assert_eq(_kit.max_turrets(), 2)
	RunState.add_upgrade(0, &"pipo_torreta_extra")
	RunState.add_upgrade(0, &"pipo_marca_rapida")
	assert_eq(_kit.max_turrets(), 3)
	assert_eq(_kit.mark_every(), 2)
