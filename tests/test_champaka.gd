extends "res://tests/helpers/kit_test.gd"
## Kit del Capitán Champaka.

var _kit: ChampakaKit


func before_each() -> void:
	GameSettings.auto_revive_players = false
	RunState.start_run(1)
	make_player(&"champaka")
	_kit = _player.kit as ChampakaKit
	_player.aim_direction = Vector3.FORWARD


func after_each() -> void:
	GameSettings.auto_revive_players = true


func _enemy_hit(amount: float) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = amount
	info.attacker_team = DamageInfo.Team.ENEMIES
	info.origin = Vector3(0, 0, -2)
	return info


func _count_mushrooms() -> int:
	var count: int = 0
	for child: Node in get_children():
		if child is HealMushroom:
			count += 1
	return count


func test_takes_fifteen_percent_less() -> void:
	var start: float = _player.health.current
	_player.receive_hit(_enemy_hit(100.0))
	assert_almost_eq(start - _player.health.current, 85.0, 0.01)


func test_spores_grow_a_mushroom_every_100_damage() -> void:
	assert_eq(_count_mushrooms(), 0)
	_player.receive_hit(_enemy_hit(130.0))  # 110,5 recibidos
	assert_eq(_count_mushrooms(), 1, "Cada 100 de daño recibido, un hongo")
	assert_almost_eq(_kit.spores, 10.5, 0.01)


func test_clap_is_one_slow_strong_hit() -> void:
	var enemy := enemy_at(Vector3(0, 0, -1.5), 1000.0)
	_slot.input._held[PlayerInput.Action.ATTACK] = true
	step(40)
	_slot.input._held[PlayerInput.Action.ATTACK] = false
	assert_almost_eq(1000.0 - enemy.health.current, 45.0, 0.01, "Un solo aplauso de 45 en 0,66 s")


func test_mushrooms_heal_five() -> void:
	assert_eq(_kit.mushroom_heal(), 5.0)
	RunState.add_upgrade(0, &"champaka_hongos_gorditos")
	assert_eq(_kit.mushroom_heal(), 10.0)


func test_belly_mushroom_only_in_combat() -> void:
	RunState.add_upgrade(0, &"champaka_panzazo_hongo")
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		node.remove_from_group(&"enemies")
	var before: int = _count_mushrooms()
	_kit._land()
	assert_eq(_count_mushrooms(), before, "Sin enemigos no suelta hongos")
	enemy_at(Vector3(8, 0, 8), 1000.0)
	_kit._land()
	assert_eq(_count_mushrooms(), before + 1, "Con pelea, sí")


func test_belly_slide_is_not_invulnerable_but_reduces_damage() -> void:
	press(PlayerInput.Action.DODGE)
	step(1)
	assert_true(_kit.sliding)
	var start: float = _player.health.current
	_player.receive_hit(_enemy_hit(100.0))
	assert_almost_eq(start - _player.health.current, 100.0 * 0.85 * 0.6, 0.01, "Sin invulnerabilidad: 40% menos")
	release(PlayerInput.Action.DODGE)
	step(40)
	assert_false(_kit.sliding, "Termina el panzazo")
	assert_lt(_player.global_position.z, -0.5, "Avanza hacia donde apunta")


func test_bear_hug_crushes() -> void:
	var enemy := enemy_at(Vector3(0, 0, -1.5), 1000.0)
	press(PlayerInput.Action.ABILITY)
	step(1)
	assert_true(enemy.is_controlled, "Lo agarra")
	await wait_seconds(1.5)
	assert_false(enemy.is_controlled, "Lo suelta")
	assert_almost_eq(1000.0 - enemy.health.current, 80.0, 0.01, "Lo aplasta: 80")


func test_bear_hug_calms_furious_tali() -> void:
	var tali: PlayerCharacter = make_player(&"tali", 1)
	tali.global_position = Vector3(1, 0, 0)
	var tali_kit := tali.kit as TaliKit
	tali_kit._enter_fury()
	tali.health.current = 50.0
	press(PlayerInput.Action.ABILITY)
	step(1)
	assert_false(tali_kit.in_fury, "Le corta la Furia")
	assert_eq(tali_kit._lockout, 0.0, "Sin resaca")
	assert_almost_eq(tali.health.current, 50.0 + 150.0 * 0.2, 0.01, "Le cura 20%")


func test_dad_protects_nearby_ally() -> void:
	var ally: PlayerCharacter = make_player(&"croco", 1)
	ally.global_position = Vector3(1.5, 0, 0)
	var start: float = ally.health.current
	ally.receive_hit(_enemy_hit(100.0))
	assert_almost_eq(start - ally.health.current, 90.0, 0.01, "Papá del grupo: 10% menos")


func test_bloom_revives_and_confuses() -> void:
	var ally: PlayerCharacter = make_player(&"croco", 1)
	ally.global_position = Vector3(2, 0, 0)
	var kill := DamageInfo.new()
	kill.amount = 99999.0
	ally.health.apply_damage(kill)
	assert_true(ally.is_downed())
	var enemy := enemy_at(Vector3(0, 0, -3), 1000.0)
	_kit.ult_charge = 100.0
	press(PlayerInput.Action.ULTIMATE)
	step(1)
	var zone: FloracionZone = null
	for child: Node in get_children():
		if child is FloracionZone:
			zone = child
	assert_not_null(zone, "Brota el hongo")
	zone._physics_process(DT)
	assert_false(ally.is_downed(), "Revive al caído")
	assert_true(enemy.status.has(StatusEffects.CONFUSED), "Confunde")
	assert_true(enemy.status.has(StatusEffects.SLOW), "Enreda")


func test_upgrades_change_numbers() -> void:
	RunState.add_upgrade(0, &"champaka_esporulacion")
	RunState.add_upgrade(0, &"champaka_papa_presente")
	assert_eq(_kit.spores_per_mushroom(), 70.0)
	assert_eq(_kit.dad_radius(), 5.0)
	assert_eq(_kit.dad_reduction(), 0.15)


func test_yole_seismic_clap_hits_all_around() -> void:
	RunState.add_upgrade(0, &"champaka_aplauso_sismico")
	var behind := enemy_at(Vector3(0, 0, 2.0), 1000.0)
	var front := enemy_at(Vector3(0, 0, -2.0), 1000.0)
	_kit._swipe()
	assert_lt(behind.health.current, 1000.0, "Le pega también al de atrás")
	assert_almost_eq(1000.0 - front.health.current, 45.0 * 0.8, 1.0, "Un poco menos fuerte (80%)")
