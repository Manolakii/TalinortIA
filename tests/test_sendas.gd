extends "res://tests/helpers/kit_test.gd"
## Sendas del dúo (mejoras de Maestro y Stewie) y formas de Stewie.

var _kit: MaestroKit


func before_each() -> void:
	RunState.start_run(3)
	make_player(&"maestro")
	_kit = _player.kit as MaestroKit
	_kit.kd = _kit.kd.duplicate()
	_player.aim_direction = Vector3.FORWARD
	await wait_physics_frames(1)
	_kit.companion.global_position = Vector3(1.5, 0, 1.0)
	_kit.companion.set_downed(true, 999.0)  # sin ayuda del compañero, para medir limpio


func after_each() -> void:
	if is_instance_valid(_kit) and is_instance_valid(_kit.companion):
		_kit.companion.free()
	for node: Node in get_tree().get_nodes_in_group(&"duo_zone_test"):
		node.free()


func _take(id: String, times: int = 1) -> void:
	for i: int in times:
		RunState.add_upgrade(0, StringName(id))


func test_senda_lookup_and_level() -> void:
	assert_eq(_kit.senda(&"maestro", &"basic"), &"")
	_take("senda_maestro_basic_guia")
	assert_eq(_kit.senda(&"maestro", &"basic"), &"guia")
	assert_eq(_kit.senda_power(&"maestro", &"basic"), 1.0)
	_take("senda_maestro_basic_guia")
	assert_eq(_kit.senda_level(&"maestro", &"basic"), 2)
	assert_eq(_kit.senda_power(&"maestro", &"basic"), 1.5, "Nivel 2: 50% más fuerte")


func test_guide_strike_marks_and_others_hit_harder() -> void:
	_take("senda_maestro_basic_guia")
	var enemy := enemy_at(Vector3(0, 0, -1.5), 1000.0)
	_kit._maestro_staff(_player, Vector3.FORWARD, 0)
	assert_true(enemy.status.has(StatusEffects.MARKED), "Golpe Guía marca")
	var hit := DamageInfo.new()
	hit.amount = 100.0
	hit.attacker_team = DamageInfo.Team.PLAYERS
	var before: float = enemy.health.current
	enemy.receive_hit(hit)
	assert_almost_eq(before - enemy.health.current, 115.0, 0.5, "+15% a los marcados")


func test_cloudy_staff_slows() -> void:
	_take("senda_maestro_basic_niebla")
	var enemy := enemy_at(Vector3(0, 0, -1.5), 1000.0)
	_kit._maestro_staff(_player, Vector3.FORWARD, 0)
	assert_true(enemy.status.has(StatusEffects.SLOW))


func test_dancing_staff_has_five_hits() -> void:
	assert_eq(_kit.staff_combo_length(), 3)
	_take("senda_maestro_basic_combate")
	assert_eq(_kit.staff_combo_length(), 5)


func test_stewie_bites_are_faster_and_shell_is_slower() -> void:
	var base: float = _kit.headbutt_interval()
	_take("senda_stewie_basic_embestida")
	assert_almost_eq(_kit.headbutt_interval(), base * 0.5, 0.001)


func test_shields_absorb_damage_first() -> void:
	_player.health.add_shield(30.0)
	var hit := DamageInfo.new()
	hit.amount = 50.0
	hit.attacker_team = DamageInfo.Team.ENEMIES
	_player.health.make_invulnerable(0.0)
	var before: float = _player.health.current
	_player.receive_hit(hit)
	assert_eq(_player.health.shield, 0.0)
	assert_almost_eq(before - _player.health.current, 50.0 * _player.health.damage_taken_multiplier - 30.0, 0.5,
			"El escudo se come los primeros 30")


func test_blessing_gives_shield_and_damage() -> void:
	_take("senda_maestro_ability_guia")
	_kit.companion.set_downed(false, 0.0)
	_kit._maestro_senda_ability(_player, Vector3.FORWARD)
	assert_eq(_kit.companion.health.shield, 30.0)
	assert_almost_eq(_kit._source_bonus(_player), 1.2, 0.001, "+20% de daño")


func test_whirlwind_hits_around_for_two_seconds() -> void:
	_take("senda_maestro_ability_combate")
	var enemy := enemy_at(Vector3(1.5, 0, 0), 1000.0)
	_kit._maestro_senda_ability(_player, Vector3.FORWARD)
	_pump_seconds(2.2)
	assert_gt(1000.0 - enemy.health.current, 12.0 * 6, "Varios giros de 12")


func test_valley_fog_slows_and_makes_enemies_miss() -> void:
	_take("senda_maestro_ability_niebla")
	var enemy := enemy_at(Vector3(0, 0, -4.0), 1000.0)
	_kit._maestro_senda_ability(_player, Vector3.FORWARD)
	await wait_physics_frames(2)
	assert_true(enemy.status.has(StatusEffects.FOGGED))
	assert_true(enemy.status.has(StatusEffects.SLOW))


func test_spring_heals_allies() -> void:
	_take("senda_stewie_ability_espiritu")
	_player.health.current = 50.0
	_kit._stewie_senda_ability(_player)
	await wait_seconds(1.0)
	assert_gt(_player.health.current, 52.0, "Manantial cura")


func test_fortress_reflects_and_taunts() -> void:
	_take("senda_stewie_ability_caparazon")
	var enemy := enemy_at(Vector3(0, 0, -1.5), 1000.0)
	_kit._stewie_senda_ability(_player)
	assert_lt(_player.target_priority(), 1.0, "Atrae a los enemigos")
	var hit := DamageInfo.new()
	hit.amount = 100.0
	hit.attacker = enemy
	hit.attacker_team = DamageInfo.Team.ENEMIES
	_player.receive_hit(hit)
	assert_almost_eq(1000.0 - enemy.health.current, 30.0 * _kit.outgoing_multiplier(), 1.0,
			"Devuelve 30%")


func test_pole_crash_hits_on_landing() -> void:
	_take("senda_maestro_dodge_combate")
	var enemy := enemy_at(Vector3(1.0, 0, 0), 1000.0)
	_kit._pole_landing(_player)
	assert_gt(1000.0 - enemy.health.current, 25.0)


func test_fog_cloud_hides_players() -> void:
	_take("senda_maestro_dodge_niebla")
	_kit._pole_landing(_player)
	await wait_physics_frames(2)
	assert_false(_player.can_be_targeted_by_enemies(), "Oculto en la nube")


func test_stewie_grows_with_upgrades() -> void:
	assert_eq(_kit.stewie_form(), 0)
	_kit.companion.set_downed(false, 0.0)
	_take("senda_stewie_basic_caparazon", 2)
	_take("senda_stewie_ability_caparazon")
	assert_eq(_kit.stewie_form(), 1, "Joven con 3 mejoras")
	assert_eq(_kit.companion.health.max_health, _kit.kd.stewie_health_by_form[1])
	_take("senda_maestro_basic_guia", 2)
	_take("senda_maestro_ability_guia")
	assert_eq(_kit.stewie_form(), 2, "Sabia con 6")


func _pump_seconds(seconds: float) -> void:
	for i: int in int(seconds / DT):
		_player._physics_process(DT)
