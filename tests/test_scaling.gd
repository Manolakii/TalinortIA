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
	assert_almost_eq(Scaling.enemy_health(_config, DifficultyConfig.Level.HARD, 2), 1.25 * 1.55, 0.001)
	assert_almost_eq(Scaling.enemy_damage(_config, DifficultyConfig.Level.HARD), 1.4, 0.001)
	assert_eq(_config.elite_affixes[DifficultyConfig.Level.HARD], 2, "En Difícil, 2 afijos")


func test_enemy_damage_does_not_scale_with_players() -> void:
	# "El daño de los enemigos no escala con los jugadores"
	assert_eq(Scaling.enemy_damage(_config, DifficultyConfig.Level.NORMAL), 1.0)
