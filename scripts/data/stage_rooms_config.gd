class_name StageRoomsConfig
extends Resource
## Cómo se arma un stage: escenarios, plantillas de sala, qué puertas salen y con qué
## oleadas se pelea cada tipo de sala (GDD, Estructura de la partida y salas).

@export var stage_name: String = "Talinorthland"
## Nombre de cada escenario (X-1, X-2, X-3). El X-4 es el boss.
@export var scenario_names: Array[String] = []
@export var rooms_per_scenario: int = 3
## Plantillas de sala: escenas con rocas y lugares para vasijas, cofres y eventos.
@export var templates: Array[PackedScene] = []

@export_group("Puertas y premios")
## Qué hay detrás de una puerta (sorpresa), en el orden de RoomKind.Type: Combate, Élite,
## Tesoro (0: es escondido), Mimics, Colonia de presos, Cabaña (0: es escondida), Carreta,
## Laberinto, Barranco. Pedido del grupo: más eventos (45%).
@export var room_weights: Array[int] = [40, 15, 0, 9, 9, 0, 9, 9, 9]
## Premio que muestra cada puerta, en el orden de RoomKind.Reward: (nada), Mejora, Oro, Desafío.
@export var reward_weights: Array[int] = [0, 45, 35, 20]
## Premio de Oro: para cada jugador.
@export var gold_reward: Vector2i = Vector2i(15, 25)
## Desafío: la sala trae estos élites extra por oleada y más enemigos, y paga una mejora de 4.
@export var challenge_extra_elites: int = 1
@export var challenge_count_multiplier: float = 1.25
## Opciones al elegir mejora: normal y "mejorada" (élite, desafío o evento bien hecho).
@export var upgrade_options: int = 3
@export var upgrade_options_bonus: int = 4
## Chance de que una sala tenga una roca agrietada con un pasaje al Tesoro escondido.
@export var hidden_treasure_chance: float = 0.15
## Golpes para romper la roca agrietada.
@export var cracked_rock_hits: int = 3

@export_group("Oleadas")
@export var combat_waves: Array[RoomWaves] = []
@export var elite_waves: Array[RoomWaves] = []
@export var treasure_guard_waves: RoomWaves
@export var prisoner_waves: RoomWaves
## Enemigos comunes extra por escenario (0,15 = +15% en X-2 y +30% en X-3).
@export var count_bonus_per_scenario: float = 0.15

@export_group("Salas")
@export var vases_min: int = 2
@export var vases_max: int = 5
## Tesoro: chance de que el cofre tenga un guardia.
@export var treasure_guard_chance: float = 0.4
## Colonia de presos: cuántas jaulas, oro por preso y cuánto hay que mantener para abrir.
@export var prisoner_count: int = 4
@export var prisoner_gold: int = 4
@export var cage_open_time: float = 2.5
## Tiempo para liberarlos antes de que se los lleven.
@export var prisoner_time_limit: float = 35.0
## Escoltá la carreta: vida, velocidad (m/s; ~45 s de viaje si la empujan siempre), y cada
## cuánto llegan enemigos (de a cuántos, en Normal y 1 jugador) con un máximo vivos a la vez.
@export var cart_health: float = 500.0
@export var cart_speed: float = 0.45
@export var cart_spawn_interval: float = 5.5
@export var cart_spawn_group: int = 2
@export var cart_max_enemies: int = 10
## Laberinto de los Gronks: cuántos duermen, y a qué distancia los despierta el ruido (pegar o
## esquivar) o pasar pegado.
@export var maze_gronks: int = 5
@export var maze_noise_radius: float = 6.0
@export var maze_touch_radius: float = 2.2
## El barranco: daño al caer, cuánto aguanta una piedra pisada, cuánto tarda en volver y
## chance de piedras extra (además del camino seguro).
@export var chasm_fall_damage: float = 15.0
@export var chasm_crumble_delay: float = 0.9
@export var chasm_respawn_time: float = 4.0
@export var chasm_extra_tiles: float = 0.45
## En qué escenario puede aparecer el acertijo de Pipo (2 = X-3, el Bosque Tuerto).
@export var riddle_scenario: int = 2

@export_group("Torreta de Pipo")
## GDD: torreta de Pipo, 10 por tiro y 2 tiros por segundo.
@export var turret_damage: float = 10.0
@export var turret_shots_per_second: float = 2.0
@export var turret_range: float = 12.0
