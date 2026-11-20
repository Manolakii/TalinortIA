extends "res://tests/helpers/kit_test.gd"
## Objetos de sala (pedido del grupo, 2026-11-20): rareza, niveles que reemplazan al anterior y topes.


func before_each() -> void:
	RunState.start_run(4)
	make_player(&"croco")


func _give(item_id: StringName, copies: int = 1) -> void:
	for i: int in copies:
		RunState.add_item(0, item_id)


func test_items_have_rarity_and_levels() -> void:
	assert_eq(Balance.generic_items.items.size(), 37)
	for item: GenericItem in Balance.generic_items.items:
		assert_ne(item.icon_text, "", "%s tiene ícono" % item.id)
		var expected: int = 2 if item.rarity >= GenericItem.Rarity.EPIC else 3
		assert_eq(item.max_level(), expected, "%s: comunes y raros Lv 3, legendarios Lv 2" % item.id)
		if item.stat == &"lifesteal" and item.rarity == GenericItem.Rarity.COMMON:
			assert_lte(item.value_at(3), 0.02, "Robo de vida común: Lv 3 no pasa del 2%")


func test_levels_replace_instead_of_adding() -> void:
	var horn: GenericItem = Balance.generic_items.get_item(&"cuerno_de_gronk")
	_give(&"cuerno_de_gronk")
	assert_almost_eq(_player.outgoing_damage_multiplier(), 1.0 + horn.value_at(1), 0.0001)
	_give(&"cuerno_de_gronk", 2)
	assert_almost_eq(_player.outgoing_damage_multiplier(), 1.0 + horn.value_at(3), 0.0001,
			"Lv 3: el valor del Lv 3, no la suma de los tres")
	assert_almost_eq(horn.value_at(3), 0.12, 0.0001, "Cuerno de Gronk Lv 3: +12% (PDF del grupo)")


func test_maxed_items_are_not_offered_again() -> void:
	var owned: Array = [&"cuerno_de_gronk", &"cuerno_de_gronk", &"cuerno_de_gronk", &"sable_sombrio", &"sable_sombrio"]
	var rng := RandomNumberGenerator.new()
	for i: int in 50:
		rng.seed = i
		for item: GenericItem in Balance.generic_items.offer(owned, rng, 3):
			assert_ne(item.id, &"cuerno_de_gronk", "Al Lv 3 ya no aparece")
			assert_ne(item.id, &"sable_sombrio", "El legendario al Lv 2 ya no aparece")


func test_rarity_odds_are_roughly_60_25_11_4() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var counts: Array[int] = [0, 0, 0, 0]
	for i: int in 4000:
		counts[Balance.generic_items.roll_rarity(rng)] += 1
	assert_between(counts[0], 2240, 2560, "Común ~60%")
	assert_between(counts[1], 880, 1120, "Raro ~25%")
	assert_between(counts[2], 340, 540, "Épico ~11%")
	assert_between(counts[3], 100, 230, "Legendario ~4%")


func test_every_rarity_has_items() -> void:
	for rarity: int in GenericItem.Rarity.size():
		var found: bool = Balance.generic_items.items.any(func(i: GenericItem) -> bool: return i.rarity == rarity)
		assert_true(found, "Hay objetos %s" % GenericItem.RARITY_NAMES[rarity])


func test_offer_shows_next_level_and_rarity() -> void:
	_give(&"cuerno_de_gronk")
	var horn: GenericItem = Balance.generic_items.get_item(&"cuerno_de_gronk")
	assert_eq(horn.title_at(2), "Cuerno de Gronk Lv 2")
	assert_eq(horn.describe(2), "+7,5% de daño")


func test_damage_reduction_and_cooldown_caps_still_apply() -> void:
	for id: StringName in [&"escama", &"caparazon_de_stewie"]:
		_give(id, 3)
	assert_almost_eq(_player.modifiers.damage_taken_multiplier(), 1.0 - 0.23, 0.0001)
	for id: StringName in [&"reloj_uwey", &"engranaje_fadied", &"reloj_de_arena"]:
		_give(id, 3)
	assert_almost_eq(_player.modifiers.cooldown_reduction(), 0.4, 0.0001, "Tope de cooldown: -40%")


func test_heart_and_bandages() -> void:
	var base: float = _player.health.max_health
	_give(&"corazon_de_gronk", 2)
	assert_eq(_player.health.max_health, base + 22.0)
	_give(&"vendas_bosque_tuerto")
	_player.health.current = 50.0
	Events.wave_cleared.emit(0)
	assert_eq(_player.health.current, 53.0)


func test_evasion_has_a_cap() -> void:
	_give(&"osito_de_peluche", 3)
	assert_almost_eq(_player.modifiers.evasion(), 0.12, 0.0001)
	var avoided: int = 0
	for i: int in 500:
		if _player._try_avoid(DamageInfo.new()) != "":
			avoided += 1
	assert_between(avoided, 35, 95, "Más o menos 12%")


func test_battery_speeds_up_ult_charge() -> void:
	_give(&"bateria_robada")
	_player.kit.add_ult(10.0)
	assert_almost_eq(_player.kit.ult_charge, 11.0, 0.0001)


# --- Objetos con efecto ---

func _hit(enemy: Enemy, amount: float = 50.0) -> void:
	var info: DamageInfo = _player.kit.make_hit(amount)
	info.is_crit = false
	enemy.receive_hit(info)


func test_effect_items_use_their_level() -> void:
	_give(&"cuchillo_oxidado", 2)
	assert_eq(_player.item_stacks(&"bleed"), 2)
	assert_eq(_player.outgoing_damage_multiplier(), 1.0, "No suma daño plano")


func test_pipo_sight_hits_healthy_enemies_harder() -> void:
	_give(&"mira_de_pipo")
	var enemy := enemy_at(Vector3(0, 0, -3), 1000.0)
	_hit(enemy, 100.0)
	assert_almost_eq(1000.0 - enemy.health.current, 120.0, 0.5, "+20% con la vida llena (Lv 1)")
	enemy.health.current = 500.0
	_hit(enemy, 100.0)
	assert_almost_eq(500.0 - enemy.health.current, 100.0, 0.5, "Herido, normal")


func test_close_glasses_only_up_close() -> void:
	_give(&"anteojos_de_cerca")
	var near := enemy_at(Vector3(0, 0, -2), 1000.0)
	var far := enemy_at(Vector3(0, 0, -8), 1000.0)
	_hit(near, 100.0)
	_hit(far, 100.0)
	assert_almost_eq(1000.0 - near.health.current, 110.0, 0.5)
	assert_almost_eq(1000.0 - far.health.current, 100.0, 0.5)


func test_firecracker_blasts_on_kill() -> void:
	_give(&"petardo_birig")
	var victim := enemy_at(Vector3(0, 0, -3), 10.0)
	var neighbor := enemy_at(Vector3(1.5, 0, -3), 1000.0)
	_hit(victim, 50.0)
	assert_almost_eq(1000.0 - neighbor.health.current, 30.0, 0.5, "La explosión le pega al de al lado (épico Lv 1: 30)")


func test_gronk_egg_shields_on_kill() -> void:
	_give(&"huevo_de_gronk", 2)
	var victim := enemy_at(Vector3(0, 0, -3), 10.0)
	_hit(victim, 50.0)
	assert_almost_eq(_player.health.shield, 10.0, 0.01, "Lv 2: 10 de escudo")
	_player.health.tick(3.1)
	assert_eq(_player.health.shield, 0.0, "Dura 3 s")


func test_feather_adds_dodge_charges() -> void:
	var before: int = _player.kit.dodge_cooldown.max_charges
	_give(&"pluma_de_pajaro", 2)
	assert_eq(_player.kit.dodge_cooldown.max_charges, before + 2, "Lv 2: +2 cargas")


func test_ukulele_and_sling_always_proc_when_chance_is_full() -> void:
	_give(&"ukelele_de_cantina")
	_give(&"honda_del_abuelo")
	var uke: GenericItem = Balance.generic_items.get_item(&"ukelele_de_cantina")
	var sling: GenericItem = Balance.generic_items.get_item(&"honda_del_abuelo")
	var old_uke: PackedFloat32Array = uke.level_chances
	var old_sling: PackedFloat32Array = sling.level_chances
	uke.level_chances = PackedFloat32Array([1.0, 1.0, 1.0])
	sling.level_chances = PackedFloat32Array([1.0, 1.0, 1.0])
	var first := enemy_at(Vector3(0, 0, -3), 1000.0)
	var second := enemy_at(Vector3(2, 0, -3), 1000.0)
	_hit(first, 50.0)
	uke.level_chances = old_uke
	sling.level_chances = old_sling
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
	assert_almost_eq(_player.health.current, after_hit + 6.0, 0.5, "Lv 1: cura 6")


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
	assert_eq(icons.size(), 2, "La piedra Lv 2 va en un solo ícono, más el Statik")
	var stone: ItemIcon = icons[0]
	assert_eq(stone.badge, "Lv2")
	assert_string_contains(stone.tooltip_text, "Lv 2")
	assert_string_contains(stone.tooltip_text, "+10% de daño de habilidades")
	PlayerManager.reset()
	RunState.start_run(4)
