extends "res://tests/helpers/kit_test.gd"
## Kit de Agucci: Hambre, Katana y Plomo, Paso de Sombra, Disolverse, Noche y Posesión.

var _kit: AgucciKit


func before_each() -> void:
	make_player(&"agucci")
	_kit = _player.kit as AgucciKit
	_kit.kd = _kit.kd.duplicate()
	_player.aim_direction = Vector3.FORWARD


func _pump(frames: int) -> void:
	step(frames, [_kit._projectiles])


func test_hunger_zones() -> void:
	assert_true(_kit.is_lucid())
	assert_eq(_kit.outgoing_multiplier(), 1.0)
	_kit.add_hunger(50.0)
	assert_false(_kit.is_lucid())
	assert_almost_eq(_kit.outgoing_multiplier(), 1.5, 0.001, "+1% por punto de Hambre")
	_kit.add_hunger(50.0)
	assert_true(_kit.possessed, "Al 100%: Posesión")


func test_full_combo_damage() -> void:
	var enemy := enemy_at(Vector3(0, 0, -1.5), 1000.0)
	_slot.input._held[PlayerInput.Action.ATTACK] = true
	_pump(int(1.6 / DT))
	assert_almost_eq(1000.0 - enemy.health.current, 20.0 + 20.0 + 24.0 + 14.0 + 5 * 6.0, 0.01,
			"Cortes 20/20/24, patada 14, UZI 5 × 6")


func test_lucid_backstab_is_guaranteed_crit() -> void:
	var enemy := enemy_at(Vector3(0, 0, -1.5), 1000.0)
	enemy.facing = Vector3.FORWARD  # mira para el otro lado: Agucci está a su espalda
	_slot.input._held[PlayerInput.Action.ATTACK] = true
	_pump(8)
	assert_almost_eq(1000.0 - enemy.health.current, 20.0 * _player.data.crit_multiplier, 0.01,
			"Primer corte por la espalda en Lucidez: crítico de 175%")


func test_basic_hits_lower_hunger() -> void:
	enemy_at(Vector3(0, 0, -1.5), 1000.0)
	_kit.hunger = 50.0
	_slot.input._held[PlayerInput.Action.ATTACK] = true
	_pump(8)
	assert_lt(_kit.hunger, 50.0)


func test_shadow_step_kunai_then_dash() -> void:
	var enemy := enemy_at(Vector3(0, 0, -6), 1000.0)
	press(PlayerInput.Action.ABILITY)
	_pump(1)
	release(PlayerInput.Action.ABILITY)
	_pump(20)
	assert_almost_eq(1000.0 - enemy.health.current, 40.0, 0.01, "Kunai: 40")
	assert_eq(_kit.hunger, 20.0, "+20 de Hambre")
	assert_true(_kit._kunai_active, "El kunai queda marcado para reactivar")
	press(PlayerInput.Action.ABILITY)
	_pump(1)
	release(PlayerInput.Action.ABILITY)
	_pump(20)
	assert_false(_kit._kunai_active)
	assert_almost_eq(1000.0 - enemy.health.current, 40.0 + 110.0, 0.5,
			"Corte de sombra: 110 (con 20 de Hambre sigue en Lucidez, sin bonus)")


func test_kunai_kill_does_not_add_hunger() -> void:
	enemy_at(Vector3(0, 0, -6), 30.0)
	press(PlayerInput.Action.ABILITY)
	_pump(20)
	assert_eq(_kit.hunger, 0.0, "Si mata con el kunai, no suma Hambre")


func test_dissolve_is_intangible() -> void:
	press(PlayerInput.Action.DODGE)
	_pump(1)
	release(PlayerInput.Action.DODGE)
	assert_true(_player.health.is_invulnerable())
	assert_false(_player.visual.visible, "Se hunde en su sombra")
	_pump(20)
	assert_true(_player.visual.visible)


func test_possession_walks_and_attacks_alone() -> void:
	var enemy := enemy_at(Vector3(4, 0, 0), 1000.0)
	_kit.add_hunger(100.0)
	_pump(2)
	assert_not_null(_player.move_override)
	assert_gt((_player.move_override as Vector2).x, 0.5, "Va solo hacia el enemigo")
	_player.global_position = Vector3(3, 0, 0)
	_pump(40)
	assert_lt(enemy.health.current, 1000.0, "Ataque automático")
	_pump(int(6.5 / DT))
	assert_false(_kit.possessed)
	assert_eq(_kit.hunger, 0.0, "Después de la Posesión, el Hambre vuelve a 0")
	assert_null(_player.move_override)


func test_possession_lasts_half_next_to_tali() -> void:
	var tali: PlayerCharacter = make_player(&"tali", 1)
	tali.global_position = Vector3(2, 0, 0)
	_kit.add_hunger(100.0)
	assert_almost_eq(_kit._possession_time, 3.0, 0.001)


func test_hunger_drops_near_tali() -> void:
	var tali: PlayerCharacter = make_player(&"tali", 1)
	tali.global_position = Vector3(2, 0, 0)
	_kit.hunger = 50.0
	_pump(60)
	assert_almost_eq(_kit.hunger, 47.0, 0.2, "Cerca de Tali baja 3 por segundo")


func test_night_echoes_every_hit() -> void:
	var enemy := enemy_at(Vector3(0, 0, -1.5), 1000.0)
	_kit.ult_charge = 100.0
	press(PlayerInput.Action.ULTIMATE)
	_pump(1)
	release(PlayerInput.Action.ULTIMATE)
	assert_eq(_kit.hunger, 50.0, "+50 de Hambre")
	_kit.hunger = 0.0
	_slot.input._held[PlayerInput.Action.ATTACK] = true
	_pump(12)
	_slot.input._held[PlayerInput.Action.ATTACK] = false
	_pump(10)
	assert_almost_eq(1000.0 - enemy.health.current, 40.0, 0.5, "El corte de 20 pega doble")


func test_shadow_bite_costs_life_and_resets_on_kill() -> void:
	enemy_at(Vector3(0, 0, -3), 30.0)
	_kit.add_hunger(100.0)
	_kit.kd.possession_auto_radius = 0.0
	press(PlayerInput.Action.ABILITY)
	_pump(1)
	release(PlayerInput.Action.ABILITY)
	assert_lt(_player.health.current, 90.0, "Cuesta 5% de la vida actual")
	_pump(15)
	assert_true(_kit.bite_cooldown.is_ready(), "Mató: se reinicia al instante")


func test_shadow_dash_does_not_slide_after_arriving() -> void:
	enemy_at(Vector3(0, 0, -8), 1000.0)
	press(PlayerInput.Action.ABILITY)
	_pump(1)
	release(PlayerInput.Action.ABILITY)
	_pump(20)
	press(PlayerInput.Action.ABILITY)
	_pump(1)
	release(PlayerInput.Action.ABILITY)
	_pump(20)
	assert_lte(_player._move_velocity.length(), _player.data.move_speed + 0.01,
			"Al llegar, frena: no sigue patinando con la velocidad del viaje")


func test_hunger_rises_mixing_basics_and_skills() -> void:
	enemy_at(Vector3(0, 0, -1.5), 5000.0)
	press(PlayerInput.Action.DODGE)
	_pump(1)
	release(PlayerInput.Action.DODGE)
	assert_eq(_kit.hunger, 6.0, "Disolverse suma 6")
	_pump(20)
	_kit.hunger = 40.0
	_slot.input._held[PlayerInput.Action.ATTACK] = true
	_pump(int(1.45 / DT))
	assert_gt(_kit.hunger, 36.0, "Un combo completo baja poco (~2,7)")
