extends "res://tests/helpers/kit_test.gd"
## Objetos especiales de Yole Sajor, el stock de la tienda y las mejoras de tienda de los kits.


func before_each() -> void:
	RunState.start_run(12)
	make_player(&"croco")


func after_each() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		node.free()
	for child: Node in get_children():
		if child is HealMushroom or child is GoldCoin:
			child.free()


func _give(item: StringName) -> void:
	RunState.add_special(0, item)


# --- Tienda ---

func test_stock_has_four_items_not_owned() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var stock: Array[SpecialItem] = Balance.shop.roll_stock([&"statik"], 0, rng)
	assert_eq(stock.size(), 4)
	for item: SpecialItem in stock:
		assert_ne(item.id, &"statik", "No ofrece lo que ya tenés")
		assert_ne(item.rarity, SpecialItem.Rarity.LEGENDARY, "Antes del Stage 1 no hay legendarios")


func test_prices_follow_rarity() -> void:
	assert_eq(Balance.shop.price_of(Balance.shop.get_item(&"piedra_suerte")), 70)
	assert_eq(Balance.shop.price_of(Balance.shop.get_item(&"corona_lider")), 470)


func test_kit_shop_upgrade_variants_are_exclusive() -> void:
	var rng := RandomNumberGenerator.new()
	var offered: CharacterUpgrade = Balance.upgrades.shop_upgrade_for(&"tali", [], rng)
	assert_true(String(offered.id).begins_with("tali_entiende_"))
	assert_null(Balance.upgrades.shop_upgrade_for(&"tali", [&"tali_entiende_gronk"], rng),
			"Con una variante comprada, ya no hay más")
	var normal: Array[CharacterUpgrade] = Balance.upgrades.available_for(&"tali", [])
	for upgrade: CharacterUpgrade in normal:
		assert_false(upgrade.shop_only, "Las de tienda no salen en el 1 de 3")


func test_croco_double_contract() -> void:
	RunState.add_upgrade(0, &"croco_contrato_doble")
	assert_eq((_player.kit as CrocoKit).contract_cooldown.max_charges, 2)


# --- Efectos ---

func test_gronk_scale_reflects_melee_hits() -> void:
	_give(&"escama_gronk")
	var enemy := enemy_at(Vector3(0, 0, -1.5), 1000.0)
	var hit: DamageInfo = enemy.make_attack()
	hit.is_melee = true
	_player.receive_hit(hit)
	assert_almost_eq(1000.0 - enemy.health.current, 20.0, 1.0, "Le devuelve 20")


func test_statik_charges_walking_and_chains() -> void:
	_give(&"statik")
	_player.specials._last_position = _player.global_position
	_player.global_position += Vector3(30, 0, 0)
	_player.specials._physics_process(DT)
	assert_eq(_player.specials.statik, 100.0, "Caminando se llena")
	var first := enemy_at(Vector3(30, 0, -1.5), 1000.0)
	var second := enemy_at(Vector3(32, 0, -1.5), 1000.0)
	_player.specials._last_attack_input = Time.get_ticks_msec() / 1000.0
	_player.specials._on_hit_landed(_player.kit.make_hit(10.0), first)
	assert_lt(second.health.current, 1000.0, "El rayo salta a otro")
	assert_eq(_player.specials.statik, 0.0)


func test_twilight_fragment_echoes_crits() -> void:
	_give(&"fragmento_crepusculo")
	var enemy := enemy_at(Vector3(0, 0, -1.5), 1000.0)
	var crit: DamageInfo = _player.kit.make_hit(40.0)
	crit.is_crit = true
	enemy.receive_hit(crit)
	var after_hit: float = enemy.health.current
	await wait_seconds(0.4)
	assert_lt(enemy.health.current, after_hit, "El eco repite el golpe")


func test_spare_kunai_explodes_after_dodging() -> void:
	_give(&"kunai_repuesto")
	var enemy := enemy_at(Vector3(0.5, 0, 0), 1000.0)
	_player.start_dodge(Vector3.RIGHT * -1.0, 2.0, 0.2)
	_player.specials._physics_process(DT)
	await wait_seconds(0.7)
	assert_lt(enemy.health.current, 1000.0, "El kunai explota")


func test_uwey_core_refunds_every_third_ability() -> void:
	_give(&"nucleo_uwey")
	var contract: AbilityCooldown = (_player.kit as CrocoKit).contract_cooldown
	for i: int in 3:
		contract.refill()
		_player.specials._physics_process(DT)
		contract.use()
		_player.specials._physics_process(DT)
	assert_true(contract.is_ready(), "La tercera no gasta cooldown")


func test_crown_gets_you_up_once() -> void:
	_give(&"corona_lider")
	var kill := DamageInfo.new()
	kill.amount = 9999.0
	kill.attacker_team = DamageInfo.Team.ENEMIES
	_player.receive_hit(kill)
	await wait_seconds(1.4)
	assert_false(_player.health.is_dead, "Se levanta solo")
	assert_almost_eq(_player.health.ratio(), 0.4, 0.01, "Con el 40%")
	assert_eq(RunState.get_bonus(0, &"corona_used"), 1, "Una sola vez")


func test_bottomless_vase_doubles_gold() -> void:
	_give(&"vasija_sin_fondo")
	var chance: float = Balance.economy.vase_drop_chance
	Balance.economy.vase_drop_chance = 1.0
	var vase := Vase.new()
	add_child(vase)
	vase.smash(_player)
	Balance.economy.vase_drop_chance = chance
	var total: int = 0
	for child: Node in get_children():
		if child is GoldCoin:
			total += (child as GoldCoin).value
	assert_between(total, 4, 12, "El doble de 2 a 6")


func test_bombito_hastes_allies_on_ultimate() -> void:
	_give(&"bombito")
	var ally: PlayerCharacter = make_player(&"tali", 1)
	ally.global_position = Vector3(2, 0, 0)
	Events.ultimate_used.emit(_player)
	assert_true(ally.status.has(StatusEffects.BOMBITO))
	assert_true(_player.status.has(StatusEffects.BOMBITO))
