extends "res://tests/helpers/kit_test.gd"
## Objetos genéricos (GDD): suben estadísticas, se apilan sumando y algunos tienen tope.


func before_each() -> void:
	RunState.start_run(4)
	make_player(&"croco")


func _give(item_id: StringName, copies: int = 1) -> void:
	for i: int in copies:
		RunState.add_item(0, item_id)


func test_all_items_from_the_gdd() -> void:
	assert_eq(Balance.generic_items.items.size(), 24, "12 de estadísticas y 12 con efecto")
	for item: GenericItem in Balance.generic_items.items:
		assert_ne(item.icon_text, "", "%s tiene ícono" % item.id)
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



# --- Objetos con efecto (estilo Risk of Rain 2, 2026-11-16) ---

func _hit(enemy: Enemy, amount: float = 50.0) -> void:
	var info: DamageInfo = _player.kit.make_hit(amount)
	info.is_crit = false
	enemy.receive_hit(info)


func test_effect_items_count_stacks_not_stats() -> void:
	_give(&"cuchillo_oxidado", 2)
	assert_eq(_player.item_stacks(&"bleed"), 2)
	assert_eq(_player.outgoing_damage_multiplier(), 1.0, "No suma daño plano")


func test_pipo_sight_hits_healthy_enemies_harder() -> void:
	_give(&"mira_de_pipo")
	var enemy := enemy_at(Vector3(0, 0, -3), 1000.0)
	_hit(enemy, 100.0)
	assert_almost_eq(1000.0 - enemy.health.current, 135.0, 0.5, "+35% con la vida llena")
	var before: float = enemy.health.current
	enemy.health.current = 500.0
	_hit(enemy, 100.0)
	assert_almost_eq(500.0 - enemy.health.current, 100.0, 0.5, "Herido, normal")


func test_close_glasses_only_up_close() -> void:
	_give(&"anteojos_de_cerca")
	var near := enemy_at(Vector3(0, 0, -2), 1000.0)
	var far := enemy_at(Vector3(0, 0, -8), 1000.0)
	_hit(near, 100.0)
	_hit(far, 100.0)
	assert_almost_eq(1000.0 - near.health.current, 115.0, 0.5)
	assert_almost_eq(1000.0 - far.health.current, 100.0, 0.5)


func test_firecracker_blasts_on_kill() -> void:
	_give(&"petardo_birig")
	var victim := enemy_at(Vector3(0, 0, -3), 10.0)
	var neighbor := enemy_at(Vector3(1.5, 0, -3), 1000.0)
	_hit(victim, 50.0)
	assert_almost_eq(1000.0 - neighbor.health.current, 20.0, 0.5, "La explosión le pega al de al lado")


func test_gronk_egg_shields_on_kill() -> void:
	_give(&"huevo_de_gronk", 2)
	var victim := enemy_at(Vector3(0, 0, -3), 10.0)
	_hit(victim, 50.0)
	assert_almost_eq(_player.health.shield, 12.0, 0.01, "6 por copia")
	_player.health.tick(3.1)
	assert_eq(_player.health.shield, 0.0, "Dura 3 s")


func test_feather_adds_dodge_charges() -> void:
	var before: int = _player.kit.dodge_cooldown.max_charges
	_give(&"pluma_de_pajaro", 2)
	assert_eq(_player.kit.dodge_cooldown.max_charges, before + 2)


func test_teddy_blocks_sometimes() -> void:
	_give(&"osito_de_peluche", 3)
	var blocked: int = 0
	for i: int in 400:
		if _player._try_avoid(DamageInfo.new()) != "":
			blocked += 1
	# 1 - 1 / (1 + 0,3) = 23%
	assert_between(blocked, 60, 130)


func test_ukulele_and_sling_always_proc_when_chance_is_full() -> void:
	_give(&"ukelele_de_cantina")
	_give(&"honda_del_abuelo")
	var uke: GenericItem = Balance.generic_items.get_item(&"ukelele_de_cantina")
	var sling: GenericItem = Balance.generic_items.get_item(&"honda_del_abuelo")
	var old_uke: float = uke.chance
	var old_sling: float = sling.chance
	uke.chance = 1.0
	sling.chance = 1.0
	var first := enemy_at(Vector3(0, 0, -3), 1000.0)
	var second := enemy_at(Vector3(2, 0, -3), 1000.0)
	_hit(first, 50.0)
	uke.chance = old_uke
	sling.chance = old_sling
	assert_lt(second.health.current, 1000.0, "El rayo saltó al de al lado")
	assert_lt(first.health.current, 1000.0 - 50.0, "Más el hondazo")


func test_medkit_heals_after_damage() -> void:
	_give(&"botiquin_champaka")
	_player.health.current = 50.0
	var hit := DamageInfo.new()
	hit.amount = 10.0
	hit.attacker_team = DamageInfo.Team.ENEMIES
	_player.receive_hit(hit)
	var after_hit: float = _player.health.current
	await wait_seconds(1.4)
	assert_almost_eq(_player.health.current, after_hit + 8.0, 0.5)


# --- Estadísticas de la partida (2026-11-16) ---

func test_run_stats_track_damage_kills_and_gold() -> void:
	var enemy := enemy_at(Vector3(0, 0, -3), 40.0)
	var hit: DamageInfo = _player.kit.make_hit(25.0)
	hit.is_crit = false
	enemy.receive_hit(hit)
	enemy.receive_hit(hit.clone())
	assert_almost_eq(RunState.get_stat(0, &"damage"), 50.0, 1.0, "Cuenta el daño de cada golpe")
	assert_eq(RunState.get_stat(0, &"kills"), 1.0)
	RunState.add_gold(0, 30)
	RunState.add_gold(0, -10)
	assert_eq(RunState.get_stat(0, &"gold"), 30.0, "Solo lo que junta, no lo que gasta")


func test_stats_panel_shows_item_icons_with_tooltips() -> void:
	PlayerManager.reset()
	PlayerManager.join(true)
	var slot: PlayerSlot = PlayerManager.active_slots()[0]
	slot.character = Balance.get_character(&"tali")
	RunState.add_item(slot.index, &"piedra_de_afilar")
	RunState.add_item(slot.index, &"piedra_de_afilar")
	RunState.add_special(slot.index, &"statik")
	var panel := RunStatsPanel.new()
	add_child_autofree(panel)
	var icons: Array[Node] = panel.find_children("*", "ItemIcon", true, false)
	assert_eq(icons.size(), 2, "Las dos piedras van en un solo ícono, más el Statik")
	var stone: ItemIcon = icons[0]
	assert_eq(stone.count, 2)
	assert_string_contains(stone.tooltip_text, "+8% de daño")
	PlayerManager.reset()
	RunState.start_run(4)
