class_name DifficultyConfig
extends Resource
## Dificultad y escalado por jugador extra (GDD, Dificultad). Índice 0 Fácil, 1 Normal, 2 Difícil.

enum Level { EASY, NORMAL, HARD }

@export var names: Array[String] = ["Fácil", "Normal", "Difícil"]
@export var enemy_health: Array[float] = [0.8, 1.0, 1.5]
@export var enemy_damage: Array[float] = [0.7, 1.0, 1.7]
## Segundos extra para revivir.
@export var revive_bonus: Array[float] = [10.0, 0.0, 0.0]
## Por cada jugador extra: vida de enemigos comunes, cantidad de enemigos y vida de bosses.
@export var extra_player_health: Array[float] = [0.35, 0.45, 0.55]
@export var extra_player_count: Array[float] = [0.2, 0.25, 0.3]
@export var extra_player_boss_health: Array[float] = [0.6, 0.7, 0.8]
## Afijos de los élites.
@export var elite_affixes: Array[int] = [1, 1, 2]

@export_group("Agresividad (pedido del grupo: Difícil tiene que ser difícil de verdad)")
## Multiplica la cantidad de enemigos de cada oleada (además del escalado por jugador).
@export var enemy_count: Array[float] = [0.85, 1.0, 1.3]
## Multiplica la velocidad de movimiento de los enemigos.
@export var enemy_speed: Array[float] = [0.9, 1.0, 1.15]
## Multiplica el tiempo de aviso antes de pegar (menos = más rápido; siempre se ve).
@export var windup: Array[float] = [1.15, 1.0, 0.8]
## Multiplica el tiempo entre ataques y la recuperación después de pegar.
@export var attack_pace: Array[float] = [1.2, 1.0, 0.75]
## Élites extra en cada oleada.
@export var extra_elites_per_wave: Array[int] = [0, 0, 1]
## Cuántos enemigos cuerpo a cuerpo atacan a la vez al mismo jugador; el resto lo rodea
## esperando su turno (los élites no esperan).
@export var melee_attackers: Array[int] = [2, 2, 3]
## Cómo se desbloquea cada una (se muestra en la pantalla de unión).
@export var unlock_hint: Array[String] = ["", "Vencé al Gronk Gigante", "Ganá una partida en Normal"]
