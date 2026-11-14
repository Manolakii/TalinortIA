extends "res://tests/helpers/kit_test.gd"
## McoinIA: cuánto se gana, comprar mejoras y que se apliquen.


func before_each() -> void:
	MetaProgress.reset_for_tests()
	RunState.start_run(3)


func after_each() -> void:
	MetaProgress.reset_for_tests()
	for child: Node in get_children():
		if child is McoiniaPanel:
			child.free()


func test_earnings_follow_the_gdd() -> void:
	RunState.difficulty = DifficultyConfig.Level.NORMAL
	RunState.scenarios_cleared = 3
	RunState.elites_killed = 4
	RunState.bosses_killed = 1
	# (3 + 8 + 8 + 15) × 1,5 = 51
	assert_eq(RunState.mcoinia_for(true), 51)
	RunState.difficulty = DifficultyConfig.Level.EASY
	assert_eq(RunState.mcoinia_for(false), 19, "Perdiendo, sin el bonus de ganar")


func test_awarded_once_per_run() -> void:
	RunState.scenarios_cleared = 2
	var first: int = RunState.award_mcoinia(false)
	assert_gt(first, 0)
	assert_eq(RunState.award_mcoinia(false), 0, "Una sola vez")
	assert_eq(MetaProgress.get_balance(), first)


func test_buying_levels_up_and_spends() -> void:
	MetaProgress.add(100)
	var upgrade: McoiniaUpgrade = Balance.mcoinia.get_upgrade(&"piel_dura")
	assert_true(MetaProgress.buy(upgrade))
	assert_eq(MetaProgress.level(&"piel_dura"), 1)
	assert_eq(MetaProgress.get_balance(), 80)
	assert_true(MetaProgress.buy(upgrade))
	assert_false(MetaProgress.buy(upgrade), "No alcanza para el tercero (80)")


func test_general_upgrades_apply_to_the_next_run() -> void:
	MetaProgress.add(1000)
	MetaProgress.buy(Balance.mcoinia.get_upgrade(&"piel_dura"))
	MetaProgress.buy(Balance.mcoinia.get_upgrade(&"bolsillo_profundo"))
	MetaProgress.buy(Balance.mcoinia.get_upgrade(&"pierna_extra"))
	var player: PlayerCharacter = PLAYER_SCENE.instantiate()
	var slot := PlayerSlot.new(0, false, 90)
	slot.color = Balance.player_slots.colors[0]
	slot.label = "P1"
	slot.character = Balance.get_character(&"croco").duplicate()
	player.setup(slot)
	add_child_autofree(player)
	assert_eq(player.health.max_health, 108.0, "+8 de vida")
	assert_eq(player.kit.dodge_cooldown.max_charges, 3, "+1 carga de esquiva")
	player.rebuild_modifiers()
	assert_eq(player.kit.dodge_cooldown.max_charges, 3, "No se acumula al rearmar")


func test_hero_upgrade_changes_the_kit() -> void:
	MetaProgress.add(1000)
	MetaProgress.buy(Balance.mcoinia.get_upgrade(&"tali_furia"))
	var player: PlayerCharacter = PLAYER_SCENE.instantiate()
	var slot := PlayerSlot.new(0, false, 90)
	slot.color = Balance.player_slots.colors[0]
	slot.label = "P1"
	slot.character = Balance.get_character(&"tali").duplicate()
	player.setup(slot)
	add_child_autofree(player)
	var kit := player.kit as TaliKit
	assert_eq(kit._fury_duration(), kit.kd.fury_duration + 1.0, "La Furia dura +1 s")


func test_panel_has_general_and_hero_columns() -> void:
	make_player(&"agucci")
	MetaProgress.add(30)
	var panel := McoiniaPanel.new()
	add_child(panel)
	panel.open(_player)
	assert_eq((panel._columns[0] as Array).size(), 6, "General")
	assert_eq((panel._columns[1] as Array).size(), 3, "Héroe del Agucci")
	assert_true(panel.buy(1, 0))
	assert_eq(MetaProgress.level(&"agucci_lucidez"), 1)
