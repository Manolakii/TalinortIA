extends "res://tests/helpers/kit_test.gd"
## Birig Bamba: la tienda de Yole Sajor y el estado del grupo entre escenas.


func before_each() -> void:
	RunState.start_run(8)
	make_player(&"croco")


func after_each() -> void:
	for child: Node in get_children():
		if child is ShopPanel:
			child.free()


func _shop() -> ShopPanel:
	var shop := ShopPanel.new()
	add_child(shop)
	shop.open(_player, 0, 1)
	return shop


func test_shop_has_four_specials_kit_upgrade_reroll_and_leave() -> void:
	var shop := _shop()
	var kinds: Array = shop.rows().map(func(r: Dictionary) -> StringName: return r["kind"])
	assert_eq(kinds.count(&"special"), 4)
	assert_eq(kinds.count(&"kit"), 2, "Croco: Contrato doble y el kit de Yole (Señuelo pistolero)")
	var yole: Dictionary = shop.rows()[kinds.find(&"kit")]
	assert_eq(yole["id"], &"croco_senuelo_pistolero")
	assert_eq(yole["price"], 220, "Los kits de Yole cuestan más")
	assert_true(kinds.has(&"reroll"))
	assert_true(kinds.has(&"leave"))
	assert_true(_player.menu_locked, "Mientras compra no se mueve")


func test_buying_spends_gold_and_marks_sold() -> void:
	RunState.gold[0] = 1000
	var shop := _shop()
	var row: Dictionary = shop.rows()[0]
	shop.choose(0)
	assert_eq(RunState.get_gold(0), 1000 - row["price"])
	assert_true(RunState.has_special(0, row["id"]))
	assert_true(shop.rows()[0]["sold"], "Queda vendido")
	shop.choose(0)
	assert_eq(RunState.get_gold(0), 1000 - row["price"], "No se compra dos veces")


func test_cannot_buy_without_gold() -> void:
	RunState.gold[0] = 10
	var shop := _shop()
	shop.choose(0)
	assert_eq(RunState.get_gold(0), 10)
	assert_eq(RunState.get_specials(0).size(), 0)


func test_reroll_costs_more_each_time() -> void:
	RunState.gold[0] = 1000
	var shop := _shop()
	assert_eq(shop.reroll_price(), 25)
	shop.choose(shop.rows().size() - 2)
	assert_eq(RunState.get_gold(0), 975)
	assert_eq(shop.reroll_price(), 50, "Sube 25")


func test_kit_upgrade_from_the_shop() -> void:
	RunState.gold[0] = 1000
	var shop := _shop()
	var index: int = -1
	for i: int in shop.rows().size():
		if shop.rows()[i]["kind"] == &"kit":
			index = i
	shop.choose(index)
	assert_true(RunState.has_upgrade(0, &"croco_contrato_doble"))


func test_stock_stays_the_same_during_the_visit() -> void:
	var first: Array = _shop().rows().map(func(r: Dictionary) -> StringName: return r["id"])
	var again: Array = _shop().rows().map(func(r: Dictionary) -> StringName: return r["id"])
	assert_eq(again, first, "Mismo stock si volvés a hablarle")
	RunState.return_to_hub()
	var next_visit: Array = _shop().rows().map(func(r: Dictionary) -> StringName: return r["id"])
	assert_eq(RunState.visit, 1)
	assert_ne(next_visit, first, "Visita nueva, stock nuevo")


func test_party_health_is_saved_between_scenes() -> void:
	_player.health.current = 50.0
	RunState.save_party([_player])
	assert_almost_eq(RunState.party[0]["ratio"], 0.5, 0.01)
	assert_false(RunState.party[0]["out"])


func test_every_character_has_talks_with_yole() -> void:
	for id: String in ["tali", "croco", "agucci", "maestro", "pipo", "champaka"]:
		var talk: Dictionary = DialogueBox.lines_for("yole", id, 0)
		assert_false((talk.get("lineas", []) as Array).is_empty(), "%s le habla a Yole" % id)
	var first: Array = DialogueBox.lines_for("yole", "pipo", 0)["lineas"]
	var second: Array = DialogueBox.lines_for("yole", "pipo", 0)["lineas"]
	assert_ne(first, second, "Las charlas rotan")
