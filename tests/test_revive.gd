extends "res://tests/helpers/kit_test.gd"
## Muerte y revivir (GDD): 25/19/13/8 s, mantener interactuar 5 s, afuera si se acaba el tiempo.

var _ally: PlayerCharacter


func before_each() -> void:
	GameSettings.auto_revive_players = false
	RunState.difficulty = DifficultyConfig.Level.NORMAL
	RunState.start_run(9)
	make_player(&"tali")
	_ally = make_player(&"croco", 1)
	_ally.global_position = Vector3(1.0, 0, 0)


func after_each() -> void:
	GameSettings.auto_revive_players = true


func _kill(target: PlayerCharacter) -> void:
	var info := DamageInfo.new()
	info.amount = 99999.0
	target.health.apply_damage(info)


func _both(frames: int) -> void:
	for i: int in frames:
		_player._physics_process(DT)
		_ally._physics_process(DT)


func test_falling_gives_time_to_be_revived() -> void:
	_kill(_ally)
	assert_true(_ally.revive.downed, "Cae y espera")
	assert_almost_eq(_ally.revive.time_left, 25.0, 0.01, "Primera caída: 25 s")


func test_holding_interact_for_5s_revives_with_40_percent() -> void:
	_kill(_ally)
	_slot.input._held[PlayerInput.Action.INTERACT] = true
	_both(int(4.9 / DT))
	assert_true(_ally.revive.downed, "Antes de 5 s sigue caído")
	_both(10)
	assert_false(_ally.revive.downed, "A los 5 s se levanta")
	assert_false(_ally.health.is_dead)
	assert_almost_eq(_ally.health.current, _ally.health.max_health * 0.4, 0.01, "Con 40% de vida")


func test_reviver_cannot_attack_while_reviving() -> void:
	_kill(_ally)
	_slot.input._held[PlayerInput.Action.INTERACT] = true
	_slot.input._held[PlayerInput.Action.ATTACK] = true
	var kit := _player.kit as TaliKit
	_both(30)
	var rocks_flying: int = 0
	for shot: Variant in kit._rocks._shots:
		if shot.active:
			rocks_flying += 1
	assert_eq(rocks_flying, 0, "No tiró piedras mientras levantaba")
	assert_eq(_player.revive.reviving, _ally, "Está levantando al compañero")


func test_down_times_shrink_with_each_fall() -> void:
	var expected: Array[float] = [25.0, 19.0, 13.0, 8.0, 8.0]
	for i: int in expected.size():
		_kill(_ally)
		assert_almost_eq(_ally.revive.time_left, expected[i], 0.01, "Caída %d" % (i + 1))
		_ally.revive.complete_revive()


func test_easy_gives_ten_more_seconds() -> void:
	RunState.difficulty = DifficultyConfig.Level.EASY
	_kill(_ally)
	assert_almost_eq(_ally.revive.time_left, 35.0, 0.01)
	RunState.difficulty = DifficultyConfig.Level.NORMAL


func test_out_when_time_runs_out() -> void:
	_kill(_ally)
	_ally.revive.time_left = 0.1
	_both(10)
	assert_true(_ally.revive.out, "Queda afuera hasta Birig Bamba")
	_slot.input._held[PlayerInput.Action.INTERACT] = true
	_both(int(6.0 / DT))
	assert_true(_ally.health.is_dead, "Ya no se lo puede levantar")


func test_solo_player_does_not_go_down() -> void:
	_ally.queue_free()
	await wait_physics_frames(1)
	_kill(_player)
	assert_false(_player.revive.downed, "Jugando solo, si caés se termina")
