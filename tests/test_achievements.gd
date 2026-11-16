extends "res://tests/helpers/kit_test.gd"
## Logros: se desbloquean una vez, avisan y no tocan el archivo de verdad en los tests.


func before_each() -> void:
	RunState.start_run(2)
	make_player(&"croco")


func test_unlock_once_and_announce() -> void:
	watch_signals(Events)
	assert_false(Achievements.is_unlocked("recaudacion"))
	assert_true(Achievements.unlock("recaudacion"))
	assert_false(Achievements.unlock("recaudacion"), "Una sola vez")
	assert_signal_emit_count(Events, "achievement_unlocked", 1)
	assert_false(Achievements.save_enabled, "En los tests no se guarda")


func test_all_achievements_have_texts() -> void:
	assert_gte(Achievements.all_ids().size(), 15)
	for id: Variant in Achievements.all_ids():
		assert_ne(Achievements.how(id), "", "%s dice cómo se consigue" % id)


func test_collector_after_ten_items() -> void:
	for i: int in 10:
		RunState.add_item(0, &"escama")
	assert_true(Achievements.is_unlocked("coleccionista"))


func test_thief_gives_achievement() -> void:
	var thief: CobradorAgucci = load("res://scenes/enemies/cobrador_agucci.tscn").instantiate()
	thief.position = Vector3(0, 0, -3)
	add_child_autofree(thief)
	thief.receive_hit(_player.kit.make_hit(99999.0))
	assert_true(Achievements.is_unlocked("recaudacion"))
	for child: Node in get_children():
		if child is GoldCoin:
			child.queue_free()
