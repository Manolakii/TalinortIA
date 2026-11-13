extends "res://tests/helpers/kit_test.gd"
## Kit del Mercenario Croco.

var _kit: CrocoKit


func before_each() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"enemy_targets"):
		if node is Decoy:
			node.free()
	for node: Node in get_children():
		if node is HasteTrail:
			node.free()
	RunState.start_run(1)
	make_player(&"croco")
	_kit = _player.kit as CrocoKit
	_kit.kd = _kit.kd.duplicate()
	_kit.kd.shotgun_spread_deg = 0.0
	_player.aim_direction = Vector3.FORWARD


func _pump(frames: int) -> void:
	step(frames, [_kit._bullets])


func test_mode_follows_distance() -> void:
	assert_eq(_kit.mode_for_distance(3.0), CrocoKit.Mode.SHOTGUN)
	assert_eq(_kit.mode_for_distance(7.0), CrocoKit.Mode.PISTOL)
	assert_eq(_kit.mode_for_distance(16.0), CrocoKit.Mode.RIFLE)


func test_switching_mode_gives_bonus_to_first_shot() -> void:
	var enemy := enemy_at(Vector3(0, 0, -3), 1000.0)
	_pump(1)
	assert_eq(_kit.mode, CrocoKit.Mode.SHOTGUN, "Cerca: escopeta")
	assert_true(_kit.switch_bonus_ready)
	_slot.input._held[PlayerInput.Action.ATTACK] = true
	_pump(20)
	assert_almost_eq(1000.0 - enemy.health.current, 7.0 * 10.0 * 1.3, 0.01,
			"7 perdigones de 10, +30% por el cambio")
	assert_false(_kit.switch_bonus_ready)


func test_pistol_damage_and_rate() -> void:
	var enemy := enemy_at(Vector3(0, 0, -7), 1000.0)
	_pump(1)
	_kit.switch_bonus_ready = false
	_slot.input._held[PlayerInput.Action.ATTACK] = true
	_pump(72)  # 4 tiros en ~0,94 s, más lo que tarda la última bala en llegar
	assert_almost_eq(1000.0 - enemy.health.current, 16.0 * 4.0, 0.01, "3,2 tiros/s: 4 en 1 s")


func test_rifle_burst() -> void:
	var enemy := enemy_at(Vector3(0, 0, -18), 1000.0)
	_pump(1)
	_kit.switch_bonus_ready = false
	_slot.input._held[PlayerInput.Action.ATTACK] = true
	_pump(40)
	assert_almost_eq(1000.0 - enemy.health.current, 22.0 * 3.0, 0.01, "Ráfaga de 3 × 22")


func test_contract_full_charge_pierces_and_refunds_on_kill() -> void:
	var first := enemy_at(Vector3(0, 0, -5), 1000.0)
	var second := enemy_at(Vector3(0, 0, -12), 100.0)
	_pump(1)
	press(PlayerInput.Action.ABILITY)
	_pump(1)
	hold(PlayerInput.Action.ABILITY)
	_pump(95)  # más de 1,5 s
	release(PlayerInput.Action.ABILITY)
	_pump(1)
	assert_almost_eq(1000.0 - first.health.current, 180.0, 0.01, "Carga completa: 180")
	assert_true(second.health.is_dead, "Atraviesa a todos en la línea")
	assert_almost_eq(_kit.contract_cooldown.time_until_ready(), 10.0 * 0.6, 0.05,
			"Mató: recupera 40% del cooldown")
	assert_eq(RunState.get_bonus(0, CrocoKit.STACK_KEY), 1, "+0,2% acumulado para la partida")


func test_quick_contract_does_minimum() -> void:
	var enemy := enemy_at(Vector3(0, 0, -5), 1000.0)
	_pump(1)
	press(PlayerInput.Action.ABILITY)
	_pump(1)
	release(PlayerInput.Action.ABILITY)
	_pump(1)
	assert_almost_eq(1000.0 - enemy.health.current, 60.0, 2.0, "Sin cargar: ~60")


func test_dodge_leaves_decoy_that_enemies_prefer() -> void:
	var enemy := enemy_at(Vector3(0, 0, -3))
	press(PlayerInput.Action.DODGE)
	_pump(1)
	var decoys: Array[Node] = get_tree().get_nodes_in_group(&"enemy_targets").filter(
			func(n: Node) -> bool: return n is Decoy)
	assert_eq(decoys.size(), 1, "Deja un señuelo")
	assert_eq(enemy.nearest_target(), decoys[0], "Los enemigos van por el señuelo")
	for d: Node in decoys:
		autofree(d)


func test_trail_hastes_allies() -> void:
	var ally: PlayerCharacter = make_player(&"tali", 1)
	ally.global_position = Vector3(0, 0, -2)
	_player.global_position = Vector3(0, 0, 0)
	_slot.input.move = Vector2.UP
	press(PlayerInput.Action.DODGE)
	_pump(1)
	var trails: Array[Node] = get_children().filter(func(n: Node) -> bool: return n is HasteTrail)
	if trails.is_empty():
		trails = _player.get_parent().get_children().filter(func(n: Node) -> bool: return n is HasteTrail)
	assert_eq(trails.size(), 1)
	trails[0]._physics_process(DT)
	assert_true(ally.status.has(StatusEffects.HASTE), "El aliado que pisa el rastro va más rápido")
	assert_false(_player.status.has(StatusEffects.HASTE), "El Croco no se acelera a sí mismo")
	for t: Node in trails:
		autofree(t)


func test_rail_damage_and_overheat() -> void:
	var enemy := enemy_at(Vector3(0, 0, -8), 5000.0)
	_kit.ult_charge = 100.0
	press(PlayerInput.Action.ULTIMATE)
	_pump(1)
	release(PlayerInput.Action.ULTIMATE)
	_pump(int(4.2 / DT))
	assert_almost_eq(5000.0 - enemy.health.current, 480.0, 25.0, "120 por segundo durante 4 s")
	assert_eq(_kit.mode, CrocoKit.Mode.PISTOL, "Recalentada: solo pistola")
	assert_gt(_kit._overheat, 2.0)


func test_mode_has_margin_at_the_edges() -> void:
	_kit.mode = CrocoKit.Mode.PISTOL
	assert_eq(_kit.mode_with_hysteresis(14.5), CrocoKit.Mode.PISTOL, "Apenas pasado el límite: sigue")
	assert_eq(_kit.mode_with_hysteresis(16.0), CrocoKit.Mode.RIFLE, "Bien pasado: rifle")
	_kit.mode = CrocoKit.Mode.RIFLE
	assert_eq(_kit.mode_with_hysteresis(13.5), CrocoKit.Mode.RIFLE, "Volviendo, tampoco cambia enseguida")
	assert_eq(_kit.mode_with_hysteresis(12.0), CrocoKit.Mode.PISTOL)
	_kit.mode = CrocoKit.Mode.PISTOL
	assert_eq(_kit.mode_with_hysteresis(4.0), CrocoKit.Mode.PISTOL)
	assert_eq(_kit.mode_with_hysteresis(2.5), CrocoKit.Mode.SHOTGUN)


func test_pistol_covers_a_wide_band() -> void:
	assert_eq(_kit.mode_for_distance(12.0), CrocoKit.Mode.PISTOL, "La pistola llega hasta 14 m")
