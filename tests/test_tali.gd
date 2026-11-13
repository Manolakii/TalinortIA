extends GutTest
## Kit de Tali: Suerte, Furia, Resaca, Piedrazo, Tropezón, Zarpazos, Aplastón y definitiva.

const PLAYER_SCENE: PackedScene = preload("res://scenes/characters/player_character.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/talinorteano_cegado.tscn")
const DT := 1.0 / 60.0

var _player: PlayerCharacter
var _slot: PlayerSlot
var _kit: TaliKit


func before_each() -> void:
	Combat.rng.seed = 1234
	_slot = PlayerSlot.new(0, false, 99)
	_slot.color = Color.BLUE
	_slot.character = Balance.get_character(&"tali").duplicate()
	_player = PLAYER_SCENE.instantiate()
	_player.setup(_slot)
	add_child_autofree(_player)
	_kit = _player.kit as TaliKit
	# Copia de los datos: los tests los tocan sin afectar al resto.
	_kit.kd = _kit.kd.duplicate()
	_kit.kd.luck_miss_chance = 0.0


func _enemy_at(pos: Vector3) -> TalinorteanoCegado:
	var enemy: TalinorteanoCegado = ENEMY_SCENE.instantiate()
	enemy.position = pos
	add_child_autofree(enemy)
	return enemy


func _step(frames: int) -> void:
	for i: int in frames:
		_player._physics_process(DT)
		_kit._rocks._physics_process(DT)


func _enemy_hit(amount: float, from: Vector3) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = amount
	info.attacker_team = DamageInfo.Team.ENEMIES
	info.origin = from
	return info


func _press(action: PlayerInput.Action) -> void:
	_slot.input._prev[action] = false
	_slot.input._held[action] = true


func _release(action: PlayerInput.Action) -> void:
	_slot.input._prev[action] = true
	_slot.input._held[action] = false


func test_has_its_kit_and_data() -> void:
	assert_not_null(_kit)
	assert_eq(_player.health.max_health, 150.0)
	assert_eq(_kit.dodge_cooldown.max_charges, 2)
	assert_eq(_kit.dodge_cooldown.recharge_time, 4.0, "4 s por carga (definido por el grupo)")


# --- Furia ---

func test_fury_fills_faster_when_hit_than_when_hitting() -> void:
	_player.aim_direction = Vector3.FORWARD
	_player.receive_hit(_enemy_hit(10.0, Vector3(0, 0, -2)))  # de frente
	assert_almost_eq(_kit.fury, 10.0 * _kit.kd.fury_per_damage_taken, 0.01)
	var before: float = _kit.fury
	var dealt := DamageInfo.new()
	dealt.final_amount = 10.0
	_kit.on_damage_dealt(dealt, null)
	assert_almost_eq(_kit.fury - before, 10.0 * _kit.kd.fury_per_damage_dealt, 0.01)
	assert_gt(_kit.kd.fury_per_damage_taken, _kit.kd.fury_per_damage_dealt)


func test_back_hits_fill_double() -> void:
	_player.aim_direction = Vector3.FORWARD
	_player.receive_hit(_enemy_hit(10.0, Vector3(0, 0, 2)))  # por la espalda
	assert_almost_eq(_kit.fury, 10.0 * _kit.kd.fury_per_damage_taken * 2.0, 0.01)


func test_full_bar_triggers_fury_without_ult() -> void:
	_kit.add_fury(100.0)
	assert_true(_kit.in_fury, "Al 100% entra sola, sin definitiva")
	assert_eq(_player.health.damage_taken_multiplier, 0.7)
	_player.receive_hit(_enemy_hit(10.0, Vector3(0, 0, -2)))
	assert_almost_eq(_player.health.current, 150.0 - 7.0, 0.01, "En Furia recibe 30% menos")


func test_fury_lasts_10s_then_hangover() -> void:
	_kit.add_fury(100.0)
	_step(int(9.9 / DT))
	assert_true(_kit.in_fury)
	_step(10)
	assert_false(_kit.in_fury)
	assert_true(_kit.is_exhausted(), "Resaca")
	assert_eq(_kit.move_speed_multiplier(), _kit.kd.exhausted_speed_multiplier, "Lento")
	assert_false(_kit.can_dodge(), "Sin esquiva")
	_kit.add_fury(50.0)
	assert_eq(_kit.fury, 0.0, "La barra no carga durante el bloqueo")
	_step(int(6.1 / DT))
	assert_false(_kit.is_exhausted())
	_kit.add_fury(20.0)
	assert_eq(_kit.fury, 20.0, "Después de 6 s vuelve a cargar")


# --- Suerte ---

func test_luck_only_in_normal() -> void:
	_kit.kd.luck_miss_chance = 1.0
	assert_false(_player.receive_hit(_enemy_hit(10.0, Vector3(0, 0, -2))), "Se resbaló")
	assert_eq(_player.health.current, 150.0)
	_kit.add_fury(0.0)
	_kit._enter_fury()
	assert_true(_player.receive_hit(_enemy_hit(10.0, Vector3(0, 0, -2))), "En Furia no hay suerte")


# --- Tropezón ---

func test_lucky_stumble_gives_fury_and_unbalances_attacker() -> void:
	var enemy: TalinorteanoCegado = _enemy_at(Vector3(0, 0, -1.5))
	_press(PlayerInput.Action.DODGE)
	_step(1)
	_release(PlayerInput.Action.DODGE)
	var info := _enemy_hit(10.0, enemy.global_position)
	info.attacker = enemy
	assert_false(_player.receive_hit(info))
	assert_eq(_kit.fury, _kit.kd.lucky_dodge_fury, "+15 de Furia")
	assert_true(enemy.status.has(StatusEffects.STUN), "El atacante queda desequilibrado")


# --- Piedrazo ---

func test_rock_hits_enemy_in_front() -> void:
	var enemy: TalinorteanoCegado = _enemy_at(Vector3(0, 0, -5))
	_kit.kd.rock_spread_deg = 0.0
	_kit.kd.lucky_shot_chance = 0.0
	_player.aim_direction = Vector3.FORWARD
	_slot.character = _slot.character.duplicate()
	_player.data.crit_chance = 0.0
	_slot.input._held[PlayerInput.Action.ATTACK] = true
	_step(30)
	assert_eq(enemy.health.current, 160.0 - 18.0, "18 por piedra")
	assert_gt(_kit._attack_timer, 0.0, "Una piedra cada 0,8 s")


# --- Furia: Zarpazos y Aplastón ---

func test_claw_combo_damage() -> void:
	var enemy: TalinorteanoCegado = _enemy_at(Vector3(0, 0, -1.5))
	enemy.health.setup(1000.0)
	_player.data.crit_chance = 0.0
	_player.aim_direction = Vector3.FORWARD
	_kit._enter_fury()
	_slot.input._held[PlayerInput.Action.ATTACK] = true
	var expected: Array[float] = [34.0, 68.0, 120.0]
	var seen: Array[float] = []
	for i: int in 120:
		_step(1)
		var taken: float = 1000.0 - enemy.health.current
		if taken > 0.0 and not seen.has(taken):
			seen.append(taken)
	assert_eq(seen.slice(0, 3), expected, "34 / 34 / 52")


func test_slam_jumps_toward_aim_up_to_max_distance() -> void:
	_kit._enter_fury()
	_player.aim_point = Vector3(0, 0, -20)
	_kit._slam()
	var expected: float = _kit.kd.slam_max_distance / _kit.kd.slam_air_time
	assert_almost_eq((_player.action_velocity as Vector3).length(), expected, 0.01,
			"Salta hasta 7 m como máximo")
	assert_false(_kit.slam_cooldown.is_ready(), "CD de 6 s")


# Se prueba el aterrizaje directo: en los tests, move_and_slide usa otro delta.
func test_slam_landing_hits_area() -> void:
	var near: TalinorteanoCegado = _enemy_at(Vector3(1.5, 0, 0))
	var far: TalinorteanoCegado = _enemy_at(Vector3(8, 0, 0))
	_player.data.crit_chance = 0.0
	_kit._enter_fury()
	_kit._slam_land()
	assert_eq(near.health.current, 160.0 - 90.0, "90 en área")
	assert_true(near.status.has(StatusEffects.STUN))
	assert_eq(far.health.current, 160.0)


# --- Definitiva ---

func test_ult_in_normal_transforms_and_scares() -> void:
	var enemy: TalinorteanoCegado = _enemy_at(Vector3(0, 0, -3))
	_kit.ult_charge = 100.0
	_press(PlayerInput.Action.ULTIMATE)
	_step(1)
	assert_true(_kit.in_fury)
	assert_eq(_kit.ult_charge, 0.0)
	assert_true(enemy.status.has(StatusEffects.FEAR), "Rugido que asusta")


func test_ult_in_fury_tosses_biggest_enemy_and_extends_fury() -> void:
	var enemy: TalinorteanoCegado = _enemy_at(Vector3(0, 0, -2))
	_kit._enter_fury()
	var time_before: float = _kit._fury_time
	_kit.ult_charge = 100.0
	_press(PlayerInput.Action.ULTIMATE)
	_step(1)
	assert_true(enemy.is_controlled, "Lo agarra")
	assert_almost_eq(_kit._fury_time, time_before + 4.0 - DT, 0.05, "+4 s de Furia")
	await wait_seconds(0.8)
	assert_false(enemy.is_controlled)
	assert_lt(enemy.health.current, 160.0, "Le dolió el revoleo")


func test_ult_in_fury_without_targets_keeps_the_bar() -> void:
	_kit._enter_fury()
	_kit.ult_charge = 100.0
	_press(PlayerInput.Action.ULTIMATE)
	_step(1)
	assert_eq(_kit.ult_charge, 100.0, "Si no hay a quién revolear, no gasta la barra")


func test_ability_cuts_basic_attack_recovery() -> void:
	_enemy_at(Vector3(0, 0, -1.5))
	_kit._enter_fury()
	_player.aim_point = Vector3(0, 0, -4)
	_slot.input._held[PlayerInput.Action.ATTACK] = true
	_step(10)  # el zarpazo ya conectó (a los 0,1 s); queda la recuperación
	assert_true(_player.is_in_action())
	_press(PlayerInput.Action.ABILITY)
	_step(5)  # puede caer en el hitstop del zarpazo: el buffer de input lo cubre
	assert_false(_kit.slam_cooldown.is_ready(), "El Aplastón sale aunque mantenga el ataque")
