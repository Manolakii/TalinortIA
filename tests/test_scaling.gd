extends GutTest
## Dificultad y escalado por jugador (GDD, Dificultad).

var _config: DifficultyConfig


func before_all() -> void:
	_config = Balance.difficulty


func test_gdd_example_four_players_normal() -> void:
	# "con 4 jugadores en Normal, un Talinorteano cegado tiene 160 × 2,35 = 376 de vida"
	var multiplier: float = Scaling.enemy_health(_config, DifficultyConfig.Level.NORMAL, 4)
	assert_almost_eq(160.0 * multiplier, 376.0, 0.01)
	# "y el Gronk Gigante tiene 6.000 × 3,1 = 18.600"
	var boss: float = Scaling.enemy_health(_config, DifficultyConfig.Level.NORMAL, 4, true)
	assert_almost_eq(6000.0 * boss, 18600.0, 0.5)
	# "hay 75% más de enemigos por sala"
	assert_eq(Scaling.enemy_count(_config, DifficultyConfig.Level.NORMAL, 4, 8), 14)


func test_one_player_normal_is_reference() -> void:
	assert_eq(Scaling.enemy_health(_config, DifficultyConfig.Level.NORMAL, 1), 1.0)
	assert_eq(Scaling.enemy_damage(_config, DifficultyConfig.Level.NORMAL), 1.0)
	assert_eq(Scaling.enemy_count(_config, DifficultyConfig.Level.NORMAL, 1, 5), 5)


func test_easy_and_hard() -> void:
	assert_almost_eq(Scaling.enemy_health(_config, DifficultyConfig.Level.EASY, 1), 0.8, 0.001)
	assert_almost_eq(Scaling.enemy_damage(_config, DifficultyConfig.Level.EASY), 0.7, 0.001)
	assert_almost_eq(Scaling.enemy_health(_config, DifficultyConfig.Level.HARD, 2), 1.5 * 1.55, 0.001)
	assert_almost_eq(Scaling.enemy_damage(_config, DifficultyConfig.Level.HARD), 1.7, 0.001)
	assert_eq(Scaling.enemy_count(_config, DifficultyConfig.Level.HARD, 1, 10), 13, "Difícil: +30% de enemigos")
	assert_eq(_config.elite_affixes[DifficultyConfig.Level.HARD], 2, "En Difícil, 2 afijos")


func test_enemy_damage_does_not_scale_with_players() -> void:
	# "El daño de los enemigos no escala con los jugadores"
	assert_eq(Scaling.enemy_damage(_config, DifficultyConfig.Level.NORMAL), 1.0)


func test_scenario_scaling_raises_health_damage_but_not_boss() -> void:
	var base_health: float = Scaling.current_health_multiplier()
	var base_damage: float = Scaling.current_damage_multiplier()
	var base_boss: float = Scaling.current_health_multiplier(true)
	RunState.set_scenario_scaling(0.3, 0.15, 0.0, 0.0)
	assert_almost_eq(Scaling.current_health_multiplier(), base_health * 1.3, 0.001, "1-2: +30% de vida")
	assert_almost_eq(Scaling.current_damage_multiplier(), base_damage * 1.15, 0.001, "+15% de daño")
	assert_almost_eq(Scaling.current_health_multiplier(true), base_boss, 0.001, "Al boss no")
	RunState.set_scenario_scaling(0.0, 0.0, 0.0, 0.0)


func test_scenario_shield_chance_gives_shields() -> void:
	RunState.set_scenario_scaling(0.0, 0.0, 1.0, 0.35)
	var enemy: Enemy = load("res://scenes/enemies/talinorteano_cegado.tscn").instantiate()
	add_child_autofree(enemy)
	assert_almost_eq(enemy.health.shield, enemy.health.max_health * 0.35, 0.01, "Aparece con escudo")
	RunState.set_scenario_scaling(0.0, 0.0, 0.0, 0.0)


func test_solo_players_get_extra_enemy_damage_from_scenario_two() -> void:
	var config: StageRoomsConfig = load("res://data/rooms/stage1.tres")
	assert_almost_eq(config.scenario_solo_damage_bonus[1], 0.1, 0.001)
	assert_almost_eq(config.scenario_solo_damage_bonus[2], 0.2, 0.001)
	assert_eq(config.scenario_solo_damage_bonus[0], 0.0, "En el 1-1 no cambia nada")
