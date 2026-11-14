extends "res://tests/helpers/kit_test.gd"
## Objetos genéricos (GDD): suben estadísticas, se apilan sumando y algunos tienen tope.


func before_each() -> void:
	RunState.start_run(4)
	make_player(&"croco")


func _give(item_id: StringName, copies: int = 1) -> void:
	for i: int in copies:
		RunState.add_item(0, item_id)


func test_all_twelve_items_from_the_gdd() -> void:
	assert_eq(Balance.generic_items.items.size(), 12)
	var piedra: GenericItem = Balance.generic_items.get_item(&"piedra_de_afilar")
	assert_eq(piedra.display_name, "Piedra de afilar")
	assert_almost_eq(piedra.amount, 0.08, 0.0001)


func test_whetstone_adds_damage_and_stacks_by_adding() -> void:
	_give(&"piedra_de_afilar", 3)
	assert_almost_eq(_player.outgoing_damage_multiplier(), 1.24, 0.0001, "3 × 8% = +24% (se suman)")
	var enemy := enemy_at(Vector3(0, 0, -3), 1000.0)
	var info := DamageInfo.new()
	info.amount = 100.0
	info.attacker = _player
	info.attacker_team = DamageInfo.Team.PLAYERS
	enemy.receive_hit(info)
	assert_almost_eq(1000.0 - enemy.health.current, 124.0, 0.01)


func test_gronk_heart_adds_max_health() -> void:
	_give(&"corazon_de_gronk", 2)
	assert_eq(_player.health.max_health, 100.0 + 24.0)


func test_scale_reduces_damage_taken_with_cap() -> void:
	_give(&"escama", 2)
	var hit := DamageInfo.new()
	hit.amount = 100.0
	hit.attacker_team = DamageInfo.Team.ENEMIES
	_player.health.setup(1000.0)
	_player.receive_hit(hit)
	assert_almost_eq(1000.0 - _player.health.current, 92.0, 0.01, "-8%")
	_give(&"escama", 20)
	assert_almost_eq(_player.modifiers.damage_taken_multiplier(), 0.7, 0.0001, "Tope: -30%")


func test_watch_shortens_cooldowns_with_cap() -> void:
	_give(&"reloj_uwey", 1)
	assert_almost_eq(_player.kit.cd_delta(1.0), 1.0 / 0.94, 0.0001)
	_give(&"reloj_uwey", 20)
	assert_almost_eq(_player.kit.cd_delta(1.0), 1.0 / 0.6, 0.0001, "Tope: -40%")


func test_leech_heals_with_cap() -> void:
	_give(&"sanguijuela", 20)
	assert_almost_eq(_player.modifiers.lifesteal(), 0.1, 0.0001, "Tope: 10%")


func test_glass_eye_and_fang_change_crits() -> void:
	_give(&"ojo_de_vidrio")
	_give(&"colmillo_filoso")
	assert_almost_eq(_player.crit_chance(), 0.0 + 0.04, 0.0001)
	assert_almost_eq(_player.crit_multiplier(), 1.5 + 0.15, 0.0001)


func test_bandages_heal_after_each_wave() -> void:
	_give(&"vendas_bosque_tuerto")
	_player.health.current = 50.0
	Events.wave_cleared.emit(0)
	assert_eq(_player.health.current, 53.0)


func test_gloves_speed_up_basic_attacks() -> void:
	_give(&"guantes_de_gronk", 2)
	assert_almost_eq(_player.kit.attack_speed(), 1.16, 0.0001)


func test_battery_speeds_up_ult_charge() -> void:
	_give(&"bateria_robada")
	_player.kit.add_ult(10.0)
	assert_almost_eq(_player.kit.ult_charge, 11.0, 0.0001)
