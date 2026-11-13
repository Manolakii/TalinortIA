class_name Scaling
## Cuentas de dificultad y escalado por jugador (GDD, Dificultad). Funciones puras, testeables.


static func players_for_scaling() -> int:
	return maxi(PlayerManager.player_count(), 1)


static func enemy_health(config: DifficultyConfig, level: int, players: int,
		is_boss: bool = false) -> float:
	var extra: int = maxi(players - 1, 0)
	var per_player: float = config.extra_player_boss_health[level] if is_boss \
			else config.extra_player_health[level]
	return config.enemy_health[level] * (1.0 + extra * per_player)


static func enemy_damage(config: DifficultyConfig, level: int) -> float:
	return config.enemy_damage[level]


## Cantidad de enemigos de una oleada, redondeando para arriba desde la mitad.
static func enemy_count(config: DifficultyConfig, level: int, players: int, base: int) -> int:
	var extra: int = maxi(players - 1, 0)
	return roundi(base * config.enemy_count[level] * (1.0 + extra * config.extra_player_count[level]))


## Lo que usan los enemigos en la partida en curso.
static func current_health_multiplier(is_boss: bool = false) -> float:
	return enemy_health(Balance.difficulty, RunState.difficulty, players_for_scaling(), is_boss)


static func current_damage_multiplier() -> float:
	return enemy_damage(Balance.difficulty, RunState.difficulty)


## Agresividad de los enemigos según la dificultad.
static func current_windup() -> float:
	return Balance.difficulty.windup[RunState.difficulty]


static func current_attack_pace() -> float:
	return Balance.difficulty.attack_pace[RunState.difficulty]


static func current_enemy_speed() -> float:
	return Balance.difficulty.enemy_speed[RunState.difficulty]
