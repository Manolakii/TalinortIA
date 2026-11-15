extends "res://tests/helpers/kit_test.gd"
## Gronk Gigante (1-4): fases, columnas, Llamado de Tali, onda de sombra y derrota.

var _holder: Node3D
var _arena: BossArena
var _boss: GronkGigante


func before_each() -> void:
	RunState.start_run(4)
	make_player(&"croco")
	_player.global_position = Vector3(0, 0, 8)
	_holder = Node3D.new()
	add_child(_holder)
	var template := Node3D.new()
	_holder.add_child(template)
	_arena = BossArena.new()
	_holder.add_child(_arena)
	_arena.setup(template)
	_boss = _arena.boss
	await wait_physics_frames(2)


func after_each() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		node.free()
	if is_instance_valid(_boss):
		_boss.free()
	if is_instance_valid(_holder):
		_holder.free()
	for child: Node in get_children():
		if child is GoldCoin:
			child.free()


func _hit(amount: float) -> DamageInfo:
	var info: DamageInfo = _player.kit.make_hit(amount)
	info.is_crit = false
	info.amount = amount
	return info


func test_has_6000_health_with_one_player() -> void:
	assert_eq(_boss.health.max_health, 6000.0)
	assert_eq(_boss.phase, 1)


func test_charging_into_a_column_stuns_and_makes_it_vulnerable() -> void:
	# Lo ponemos mirando a una columna y lo hacemos cargar.
	_boss.global_position = Vector3(-9, 0, -12)
	_boss.facing = Vector3(0, 0, 1)
	_boss._charges_left = 1
	_boss._start_charge(null)
	_boss._set_mode(GronkGigante.Mode.CHARGE)
	for i: int in 90:
		_boss._think(DT)
		if _boss.status.has(StatusEffects.STUN):
			break
	assert_true(_boss.status.has(StatusEffects.STUN), "Aturdido contra la columna")
	assert_true(_boss.is_vulnerable())
	var before: float = _boss.health.current
	_boss.receive_hit(_hit(100.0))
	assert_almost_eq(before - _boss.health.current, 150.0, 1.0, "+50% de daño")


func test_normal_hits_do_not_stun_or_push_it() -> void:
	var info: DamageInfo = _hit(10.0)
	info.stun = 2.0
	info.knockback = 10.0
	_boss.receive_hit(info)
	assert_false(_boss.status.has(StatusEffects.STUN))
	assert_eq(_boss.knockback_velocity, Vector3.ZERO)


func test_only_the_wild_call_gronk_makes_it_doubt() -> void:
	var birds: DamageInfo = _hit(10.0)
	birds.tags.append(&"wild_call")
	_boss.receive_hit(birds)
	assert_false(_boss.status.has(StatusEffects.STUN), "Los pájaros ya no lo aturden")
	var info: DamageInfo = _hit(10.0)
	info.tags.append(&"wild_call")
	info.tags.append(&"wild_call_gronk")
	_boss.receive_hit(info)
	assert_true(_boss.status.has(StatusEffects.STUN), "El Gronk del Llamado sí")
	_boss.status.clear(StatusEffects.STUN)
	var again: DamageInfo = _hit(10.0)
	again.tags.append(&"wild_call_gronk")
	_boss.receive_hit(again)
	assert_false(_boss.status.has(StatusEffects.STUN), "Con cooldown")


func test_direct_stuns_do_not_work() -> void:
	_boss.status.apply(StatusEffects.STUN, 2.0)  # tropezón de suerte de Tali
	assert_false(_boss.status.has(StatusEffects.STUN))


func test_phase_three_crystal_heals_until_broken() -> void:
	_boss.health.current = _boss.health.max_health * 0.3
	_boss._check_phase()
	_boss._check_phase()
	assert_eq(_boss.phase, 3)
	assert_true(is_instance_valid(_boss.crystal), "Aparece el cristal")
	assert_eq(_boss.crystal.max_health, 500.0)
	var before: float = _boss.health.current
	_boss._crystal_heal(1.0)
	assert_almost_eq(_boss.health.current - before, 40.0, 0.01, "Cura 40 por segundo")
	_boss.health.current = _boss.health.max_health * 0.5
	_boss._crystal_heal(1.0)
	assert_almost_eq(_boss.health.ratio(), 0.5, 0.001, "No pasa del tope")
	_boss._check_phase()
	assert_eq(_boss.phase, 3, "No vuelve de fase")
	var hit: DamageInfo = _hit(600.0)
	_boss.crystal.receive_hit(hit)
	assert_true(_boss.crystal.is_broken())
	_boss.health.current = _boss.health.max_health * 0.3
	before = _boss.health.current
	_boss._crystal_heal(1.0)
	assert_eq(_boss.health.current, before, "Roto, ya no cura")


func test_phases_change_with_health_and_phase_three_breaks_columns() -> void:
	_boss.health.current = _boss.health.max_health * 0.6
	_boss._check_phase()
	assert_eq(_boss.phase, 2, "Fase 2: la sombra toma el control")
	assert_gt(get_tree().get_nodes_in_group(&"boss_columns").size(), 0)
	_boss.health.current = _boss.health.max_health * 0.3
	_boss._check_phase()
	assert_eq(_boss.phase, 3)
	assert_eq(get_tree().get_nodes_in_group(&"boss_columns").size(), 0, "Rompió las columnas")


func test_shadow_wave_has_a_gap() -> void:
	var info := DamageInfo.new()
	info.amount = 30.0
	info.attacker_team = DamageInfo.Team.ENEMIES
	# El jugador al este; el hueco mirando al este: pasa.
	_player.global_position = Vector3(6, 0, 0)
	var wave := ShadowWave.new()
	_holder.add_child(wave)
	wave.setup(Vector3.ZERO, 0.0, deg_to_rad(60.0), 10.0, info)
	var before: float = _player.health.current
	for i: int in 90:
		wave._physics_process(DT)
	assert_eq(_player.health.current, before, "Por el hueco no pega")
	# Ahora al oeste: le pega.
	_player.global_position = Vector3(-6, 0, 0)
	var wave_two := ShadowWave.new()
	_holder.add_child(wave_two)
	wave_two.setup(Vector3.ZERO, 0.0, deg_to_rad(60.0), 10.0, info)
	for i: int in 90:
		wave_two._physics_process(DT)
	assert_lt(_player.health.current, before, "Fuera del hueco pega")


func test_defeat_frees_the_gronk_and_pays_gold() -> void:
	watch_signals(_arena)
	var kill: DamageInfo = _hit(999999.0)
	_boss.receive_hit(kill)
	await wait_seconds(2.3)
	assert_signal_emitted_with_parameters(_arena, "resolved", [true])
	var gold: int = 0
	for child: Node in _holder.get_children():
		if child is GoldCoin:
			gold += (child as GoldCoin).value
	assert_eq(gold, 60, "60 de oro (GDD, boss del Stage 1)")
