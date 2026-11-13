extends "res://tests/helpers/kit_test.gd"
## Dúo Maestro Uwey y Stewie: dos cuerpos, Vínculo, Cambio, Caída y Relevo Total.

var _kit: MaestroKit


func before_each() -> void:
	make_player(&"maestro")
	_kit = _player.kit as MaestroKit
	_kit.kd = _kit.kd.duplicate()
	_player.aim_direction = Vector3.FORWARD
	await wait_physics_frames(1)  # el compañero aparece al frame siguiente
	_kit.companion.global_position = Vector3(1.5, 0, 1.0)


func after_each() -> void:
	if is_instance_valid(_kit) and is_instance_valid(_kit.companion):
		_kit.companion.free()


func _pump(frames: int) -> void:
	step(frames, [_kit.companion])


func test_two_bodies_with_their_stats() -> void:
	assert_eq(_kit.controlled, MaestroKit.Body.MAESTRO)
	assert_eq(_player.health.max_health, 110.0, "Maestro 110")
	assert_not_null(_kit.companion)
	assert_eq(_kit.companion.identity, MaestroKit.Body.STEWIE)
	assert_eq(_kit.companion.health.max_health, 80.0, "Stewie (Cría) 80")


func test_bond_bonus_inside_8m() -> void:
	_pump(1)
	assert_true(_kit.is_bonded())
	assert_almost_eq(_kit.outgoing_multiplier(), 1.1, 0.001, "+10% de daño")
	assert_almost_eq(_player.health.damage_taken_multiplier, 0.9, 0.001, "+10% de resistencia")
	_kit.companion.global_position = Vector3(9.5, 0, 0)
	_pump(1)
	assert_false(_kit.is_bonded())
	assert_eq(_player.health.damage_taken_multiplier, 1.0)


func test_staff_combo() -> void:
	var enemy := enemy_at(Vector3(0, 0, -1.5), 1000.0)
	_kit.companion.set_downed(true, 999.0)  # Stewie fuera de juego: sin Vínculo ni ayuda
	_slot.input._held[PlayerInput.Action.ATTACK] = true
	_pump(int(1.45 / DT))
	assert_almost_eq(1000.0 - enemy.health.current, 18.0 + 18.0 + 34.0, 0.01, "Bastón 18/18/34")


func test_switch_swaps_control_and_places() -> void:
	_pump(1)
	var stewie_spot: Vector3 = _kit.companion.global_position
	press(PlayerInput.Action.ULTIMATE)
	_pump(1)
	release(PlayerInput.Action.ULTIMATE)
	assert_eq(_kit.controlled, MaestroKit.Body.STEWIE, "Ahora manejás a Stewie")
	assert_eq(_player.health.max_health, 80.0)
	assert_eq(_kit.companion.identity, MaestroKit.Body.MAESTRO)
	assert_almost_eq(_player.global_position.distance_to(stewie_spot), 0.0, 0.3,
			"Tomás el control donde estaba Stewie")
	assert_false(_kit.switch_cooldown.is_ready(), "Cambio: CD 6 s")
	assert_eq(_kit.ult_charge, 0.0)


func test_health_is_kept_per_body() -> void:
	_pump(1)
	_player.health.current = 50.0
	_kit.switch_cooldown.refill()
	press(PlayerInput.Action.ULTIMATE)
	_pump(1)
	release(PlayerInput.Action.ULTIMATE)
	assert_eq(_kit.companion.health.current, 50.0, "El Maestro sigue con 50 en el otro cuerpo")


func test_fall_passes_control_and_revives_in_15s() -> void:
	_pump(1)
	var hit := DamageInfo.new()
	hit.amount = 500.0
	hit.attacker_team = DamageInfo.Team.ENEMIES
	_player.receive_hit(hit)
	assert_eq(_kit.controlled, MaestroKit.Body.STEWIE, "Cayó el Maestro: pasás a Stewie")
	assert_false(_player.health.is_dead, "El jugador sigue en pie")
	assert_true(_kit.companion.downed)
	_pump(int(15.2 / DT))
	assert_false(_kit.companion.downed, "Se levanta a los 15 s")


func test_relay_total_needs_full_bar() -> void:
	_pump(1)
	press(PlayerInput.Action.RELAY)
	_pump(1)
	release(PlayerInput.Action.RELAY)
	assert_eq(_kit.controlled, MaestroKit.Body.MAESTRO, "Sin barra no hay Relevo Total")
	_kit.ult_charge = 100.0
	press(PlayerInput.Action.RELAY)
	_pump(1)
	release(PlayerInput.Action.RELAY)
	assert_eq(_kit.controlled, MaestroKit.Body.STEWIE)
	assert_eq(_kit._relay_effect, &"ancestral", "Entra Stewie: Forma Ancestral")
	assert_almost_eq(_player.health.max_health, 120.0, 0.01, "+50% de vida")
	_pump(int(8.2 / DT))
	assert_eq(_kit._relay_effect, &"")
	assert_eq(_player.health.max_health, 80.0, "Vuelve a la normalidad")


func test_companion_attacks_what_player_hits() -> void:
	var enemy := enemy_at(Vector3(0, 0, -1.5), 1000.0)
	_slot.input._held[PlayerInput.Action.ATTACK] = true
	_pump(10)
	_slot.input._held[PlayerInput.Action.ATTACK] = false
	var after_player: float = enemy.health.current
	_kit.companion.global_position = Vector3(0.5, 0, -0.5)
	_pump(60)
	assert_lt(enemy.health.current, after_player - 10.0, "Stewie le pega al mismo enemigo")


func test_paths_ready_for_upgrades() -> void:
	assert_eq(_kit.paths[MaestroKit.Body.STEWIE][MaestroKit.Slot.ABILITY][0],
			MaestroKit.StewiePath.BASE)
	_kit.stewie_upgrades = 3
	assert_eq(_kit.stewie_max_health(), 110.0, "Con 3 mejoras: Joven")
	_kit.stewie_upgrades = 6
	assert_eq(_kit.stewie_max_health(), 140.0, "Con 6: Sabia")


func test_ai_companion_takes_less_damage() -> void:
	_kit.companion.global_position = Vector3(20, 0, 0)  # sin Vínculo
	_pump(1)
	var hit := DamageInfo.new()
	hit.amount = 10.0
	hit.attacker_team = DamageInfo.Team.ENEMIES
	_kit.companion.receive_hit(hit)
	assert_almost_eq(80.0 - _kit.companion.health.current, 6.0, 0.01, "40% menos mientras es IA")


func test_enemies_prefer_the_player_over_the_companion() -> void:
	_pump(1)
	var enemy := enemy_at(Vector3(0.75, 0, -3), 1000.0)
	_kit.companion.global_position = Vector3(1.5, 0, 0)
	_player.global_position = Vector3(0, 0, 0)
	assert_eq(enemy.nearest_target(), _player, "A igual distancia, van por el jugador")


func test_companion_retreats_when_low_and_recovers() -> void:
	_pump(1)
	_kit.companion.health.current = 20.0  # 25%
	_pump(2)
	assert_true(_kit.companion.retreating, "Con poca vida se repliega")
	_pump(int(10.0 / DT))
	assert_gt(_kit.companion.health.current, 20.0, "Sin enemigos cerca, se recupera")


func test_stewie_ai_shells_up_inside_a_warning() -> void:
	_pump(1)
	var enemy := enemy_at(_kit.companion.global_position + Vector3(0, 0, -1.2), 1000.0)
	enemy.facing = Vector3.BACK
	enemy._start_windup()
	assert_true(enemy.threatens(_kit.companion.global_position))
	_pump(1)
	assert_true(_kit.companion.invulnerable_shell, "Stewie se mete en el caparazón")
