extends "res://tests/helpers/kit_test.gd"
## Mejoras de personaje (elegir 1 de 3) y las Sendas del dúo.

var _rng := RandomNumberGenerator.new()


func before_each() -> void:
	MetaProgress.reset_for_tests()  # sin las McoinIA guardadas en la compu
	RunState.start_run(6)
	_rng.seed = 6


func test_each_character_has_its_pool() -> void:
	assert_gte(Balance.upgrades.available_for(&"tali", []).size(), 15, "Tali: 15 o más mejoras")
	assert_gte(Balance.upgrades.available_for(&"croco", []).size(), 15, "Croco: 15 o más mejoras")
	for id: StringName in [&"agucci", &"pipo"]:
		assert_gte(Balance.upgrades.available_for(id, []).size(), 15, "%s: 15 o más mejoras" % id)
	var duo: Array[CharacterUpgrade] = Balance.upgrades.available_for(&"maestro", [])
	assert_eq(duo.filter(func(u: CharacterUpgrade) -> bool: return u.senda_slot != &"").size(), 18,
			"Dúo: 18 Sendas")
	assert_eq(duo.size(), 21, "Más Ojo para las vasijas, Té y Bastón")


func test_offer_gives_three_distinct_and_skips_owned() -> void:
	var owned: Array = [&"tali_rugido_profundo", &"tali_furia_larga", &"tali_furia_larga", &"tali_furia_larga"]
	var offer: Array[CharacterUpgrade] = Balance.upgrades.offer(&"tali", owned, _rng)
	assert_eq(offer.size(), 3)
	var ids: Array = offer.map(func(u: CharacterUpgrade) -> StringName: return u.id)
	assert_false(ids.has(&"tali_rugido_profundo"), "No ofrece una única que ya tenés")
	assert_false(ids.has(&"tali_furia_larga"), "Ni una que llegó a Lv 3")
	assert_eq(ids.size(), ids.duplicate().filter(func(x: Variant) -> bool: return ids.count(x) == 1).size(),
			"Las 3 son distintas")


func test_senda_slot_takes_only_one_path() -> void:
	var owned: Array = [&"senda_stewie_ability_caparazon"]
	var available: Array[CharacterUpgrade] = Balance.upgrades.available_for(&"maestro", owned)
	var ids: Array = available.map(func(u: CharacterUpgrade) -> StringName: return u.id)
	assert_true(ids.has(&"senda_stewie_ability_caparazon"), "Puede subir la misma Senda a nivel 2")
	assert_false(ids.has(&"senda_stewie_ability_embestida"), "El hueco ya tiene Senda: no otra")
	owned.append(&"senda_stewie_ability_caparazon")
	ids = Balance.upgrades.available_for(&"maestro", owned).map(func(u: CharacterUpgrade) -> StringName: return u.id)
	assert_false(ids.has(&"senda_stewie_ability_caparazon"), "Nivel 2 es el máximo")


func test_tali_upgrades() -> void:
	make_player(&"tali")
	var kit := _player.kit as TaliKit
	RunState.add_upgrade(0, &"tali_furia_larga")
	kit._enter_fury()
	assert_almost_eq(kit._fury_time, 11.5, 0.001, "Lv 1: la Furia dura 1,5 s más")
	kit._exit_fury()
	RunState.add_upgrade(0, &"tali_furia_larga")
	kit._lockout = 0.0
	kit._enter_fury()
	assert_almost_eq(kit._fury_time, 13.0, 0.001, "Lv 2: 3 s más (reemplaza, no suma)")
	var up: CharacterUpgrade = Balance.upgrades.get_upgrade(&"tali_furia_larga")
	assert_eq(up.title_at(2), "Bronca que dura Lv 2")
	assert_eq(Balance.upgrades.get_upgrade(&"tali_rugido_profundo").title_at(1), "Rugido profundo",
			"Las únicas no dicen Lv")


func test_no_generic_stat_upgrades_left() -> void:
	var all: Array[CharacterUpgrade] = []
	for id: StringName in [&"tali", &"croco", &"agucci", &"pipo"]:
		all.append_array(Balance.upgrades.available_for(id, []))
	for upgrade: CharacterUpgrade in all:
		assert_eq(upgrade.stat, &"", "%s juega con el kit, no es un +X%% genérico" % upgrade.id)


func test_tali_lucky_streak_and_chain() -> void:
	make_player(&"tali")
	var kit := _player.kit as TaliKit
	RunState.add_upgrade(0, &"tali_racha_suerte")
	kit.rock_streak = 4
	kit.kd = kit.kd.duplicate()
	kit.kd.lucky_shot_chance = 0.0
	_slot.input._held[PlayerInput.Action.ATTACK] = true
	_player._physics_process(DT)
	assert_eq(kit.rock_streak, 0, "Al llegar a 4 aciertos, el siguiente sale con suerte y la racha vuelve a 0")


func test_tali_revoleo_shield_decays() -> void:
	make_player(&"tali")
	_player.health.add_decaying_shield(30.0, 15.0)
	_player.health.tick(5.0)
	assert_almost_eq(_player.health.shield, 20.0, 0.01, "Se va gastando")


func test_croco_upgrades() -> void:
	make_player(&"croco")
	var kit := _player.kit as CrocoKit
	RunState.add_upgrade(0, &"croco_ruta_extra")
	assert_eq(kit.dodge_cooldown.max_charges, 3, "+1 carga de Ruta de Escape")
	RunState.add_upgrade(0, &"croco_bonus_cambio")
	assert_almost_eq(kit._switch_bonus(), 0.4, 0.0001, "Lv 1: +40%")
	RunState.add_upgrade(0, &"croco_bonus_cambio")
	assert_almost_eq(kit._switch_bonus(), 0.5, 0.0001, "Lv 2: +50%")


func test_agucci_upgrades() -> void:
	make_player(&"agucci")
	var kit := _player.kit as AgucciKit
	RunState.add_upgrade(0, &"agucci_uzi_cargador")
	assert_eq(kit._uzi_bullets(), 6, "Lv 1: +1 bala")
	RunState.add_upgrade(0, &"agucci_uzi_cargador")
	assert_eq(kit._uzi_bullets(), 7, "Lv 2: +2")
	RunState.add_upgrade(0, &"agucci_lucidez_amplia")
	kit.hunger = 34.0
	assert_true(kit.is_lucid(), "Con Mente fría Lv 1, a 34 de Hambre sigue en Lucidez")
	RunState.add_upgrade(0, &"agucci_disolverse_extra")
	assert_eq(kit.dodge_cooldown.max_charges, 3)
