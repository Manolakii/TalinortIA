extends "res://tests/helpers/kit_test.gd"
## Mejoras de personaje (elegir 1 de 3) y las Sendas del dúo.

var _rng := RandomNumberGenerator.new()


func before_each() -> void:
	RunState.start_run(6)
	_rng.seed = 6


func test_each_character_has_its_pool() -> void:
	for id: StringName in [&"tali", &"croco", &"agucci"]:
		assert_eq(Balance.upgrades.available_for(id, []).size(), 6, "%s: 6 mejoras" % id)
	assert_eq(Balance.upgrades.available_for(&"maestro", []).size(), 18, "Dúo: 18 Sendas")


func test_offer_gives_three_distinct_and_skips_owned() -> void:
	var owned: Array = [&"tali_furia_larga"]
	var offer: Array[CharacterUpgrade] = Balance.upgrades.offer(&"tali", owned, _rng)
	assert_eq(offer.size(), 3)
	var ids: Array = offer.map(func(u: CharacterUpgrade) -> StringName: return u.id)
	assert_false(ids.has(&"tali_furia_larga"), "No ofrece lo que ya tenés")
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
	RunState.add_upgrade(0, &"tali_piel_dura")
	assert_eq(_player.health.max_health, 170.0, "+20 de vida")
	RunState.add_upgrade(0, &"tali_furia_larga")
	kit._enter_fury()
	assert_almost_eq(kit._fury_time, 12.0, 0.001, "La Furia dura 2 s más")


func test_croco_upgrades() -> void:
	make_player(&"croco")
	var kit := _player.kit as CrocoKit
	RunState.add_upgrade(0, &"croco_ruta_extra")
	assert_eq(kit.dodge_cooldown.max_charges, 3, "+1 carga de Ruta de Escape")
	RunState.add_upgrade(0, &"croco_bonus_cambio")
	assert_almost_eq(kit._switch_bonus(), 0.45, 0.0001)


func test_agucci_upgrades() -> void:
	make_player(&"agucci")
	var kit := _player.kit as AgucciKit
	RunState.add_upgrade(0, &"agucci_uzi_cargador")
	assert_eq(kit._uzi_bullets(), 7)
	RunState.add_upgrade(0, &"agucci_lucidez_amplia")
	kit.hunger = 38.0
	assert_true(kit.is_lucid(), "Con Mente fría, a 38 de Hambre sigue en Lucidez")
	RunState.add_upgrade(0, &"agucci_disolverse_extra")
	assert_eq(kit.dodge_cooldown.max_charges, 3)
