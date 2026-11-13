class_name DifficultyConfig
extends Resource
## Dificultad y escalado por jugador extra (GDD, Dificultad). Índice 0 Fácil, 1 Normal, 2 Difícil.

enum Level { EASY, NORMAL, HARD }

@export var names: Array[String] = ["Fácil", "Normal", "Difícil"]
@export var enemy_health: Array[float] = [0.8, 1.0, 1.25]
@export var enemy_damage: Array[float] = [0.7, 1.0, 1.4]
## Segundos extra para revivir.
@export var revive_bonus: Array[float] = [10.0, 0.0, 0.0]
## Por cada jugador extra: vida de enemigos comunes, cantidad de enemigos y vida de bosses.
@export var extra_player_health: Array[float] = [0.35, 0.45, 0.55]
@export var extra_player_count: Array[float] = [0.2, 0.25, 0.3]
@export var extra_player_boss_health: Array[float] = [0.6, 0.7, 0.8]
## Afijos de los élites.
@export var elite_affixes: Array[int] = [1, 1, 2]
## Cómo se desbloquea cada una (se muestra en la pantalla de unión).
@export var unlock_hint: Array[String] = ["", "Vencé al Gronk Gigante", "Ganá una partida en Normal"]
