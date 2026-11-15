class_name StageRoomsConfig
extends Resource
## Cómo se arma un stage: escenarios, plantillas de sala, qué puertas salen y con qué
## oleadas se pelea cada tipo de sala (GDD, Estructura de la partida y salas).

@export var stage_name: String = "Talinorthland"
## Nombre de cada escenario (X-1, X-2, X-3). El X-4 es el boss.
@export var scenario_names: Array[String] = []
@export var rooms_per_scenario: int = 3
## Luz de cada escenario (X-1, X-2, X-3) y la del boss.
@export var scenario_lights: Array[LightPreset] = []
@export var boss_light: LightPreset
## El X-4: una sola sala, la del boss.
@export var boss_scenario_name: String = "1-4 · Gronk Gigante"
## Plantillas de sala: escenas con rocas y lugares para vasijas, cofres y eventos.
@export var templates: Array[PackedScene] = []

@export_group("Puertas y premios")
## Qué hay detrás de una puerta (sorpresa), en el orden de RoomKind.Type: Combate, Élite,
## Tesoro, Mimics, Presos, Cabaña, Carreta, Laberinto, Estampida, Boss, Aguante.
## Pedido del grupo: se avanza solo por salas de combate (normal, élite o aguante); los eventos
## salen como desafíos de ida y vuelta.
@export var room_weights: Array[int] = [50, 25, 0, 0, 0, 0, 0, 0, 0, 0, 25]
## Premio que muestra cada puerta, en el orden de RoomKind.Reward: (nada), Mejora, Oro, Desafío
## (el Desafío ya no es un premio de puerta: es su propia puerta, ver abajo).
@export var reward_weights: Array[int] = [0, 55, 45, 0]
## Premio de Oro: para cada jugador.
@export var gold_reward: Vector2i = Vector2i(15, 25)

@export_group("Desafíos (de ida y vuelta, como una grieta)")
## Chance de que, al terminar una sala, aparezca la puerta de Desafío además de las otras.
@export var challenge_door_chance: float = 0.45
## Qué desafío sale, en el orden de RoomKind.Type (solo cuentan los eventos).
@export var challenge_weights: Array[int] = [0, 0, 0, 20, 20, 0, 20, 20, 20, 0, 0]

@export_group("Sala de aguante")
## Oleada de cada tanda (se repiten en orden). Formato de RoomWaves.
@export var survival_waves: RoomWaves
## Cuánto hay que aguantar.
@export var survival_time: float = 40.0
## Cada cuánto llega una tanda (se acorta hasta 60% hacia el final).
@export var survival_spawn_interval: float = 2.2
## Máximo de enemigos vivos a la vez (con 1 jugador; +25% por cada jugador más).
@export var survival_max_alive: int = 12
## Vienen muchos: cada uno suelta oro con menos chance.
@export var survival_gold_factor: float = 0.3
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
@export var cage_open_time: float = 1.5
## Tiempo para liberarlos antes de que se los lleven.
@export var prisoner_time_limit: float = 45.0
## Distancia mínima entre jaulas (pedido del grupo: bien separadas, en distintos lugares).
@export var cage_spacing: float = 14.0
## Pedido del grupo: liberados todos, hay que defenderse de una súper oleada durante este tiempo
## y recién ahí se gana. Arranca con `prisoner_defense_burst` de golpe y después siguen
## llegando tandas de `prisoner_waves` cada `prisoner_defense_interval` s.
@export var prisoner_defense_time: float = 20.0
@export var prisoner_defense_burst: String = "soldado_agucci:5, tirador_agucci:3, chaman_sombra:1"
@export var prisoner_defense_interval: float = 2.5
@export var prisoner_defense_max_alive: int = 16
## Escoltá la carreta: vida, velocidad (m/s; ~45 s de viaje si la empujan siempre), y cada
## cuánto llegan enemigos (de a cuántos, en Normal y 1 jugador) con un máximo vivos a la vez.
@export var cart_health: float = 500.0
@export var cart_speed: float = 0.45
@export var cart_spawn_interval: float = 5.5
@export var cart_spawn_group: int = 2
@export var cart_max_enemies: int = 10
## Chance de que un enemigo vaya por la carreta (si no, va por los jugadores). Se re-decide cada 4 a 8 s.
@export var cart_focus_chance: float = 0.4
## Laberinto de los Gronks: cuántos duermen, y a qué distancia los despierta el ruido (pegar o
## esquivar) o pasar pegado.
@export var maze_gronks: int = 5
@export var maze_noise_radius: float = 6.0
@export var maze_touch_radius: float = 2.2
## Laberinto: si se despiertan más Gronks que esto, se comen el cofre y se pierde el evento.
@export var maze_max_woken: int = 2
## Trampas del laberinto: guillotinas en pasillos, pinchos en celdas, y su daño (en Normal).
@export var maze_guillotines: int = 6
@export var maze_spikes: int = 4
@export var maze_trap_damage: float = 25.0
## La estampida: cuánto dura, cada cuánto pasa una manada (al principio y al final),
## velocidad, ancho del carril y daño (en Normal). Pedido del grupo (2026-11-15): sin aviso
## naranja (aparecen directo corriendo), más Gronks por manada, más manadas dobles y carriles
## que cubren toda la sala (antes las esquinas eran un refugio).
@export var stampede_duration: float = 40.0
@export var stampede_interval_start: float = 2.4
@export var stampede_interval_end: float = 1.0
@export var stampede_speed: float = 22.0
@export var stampede_width: float = 3.2
@export var stampede_damage: float = 30.0
## Gronks por manada, chance de que salga otra manada a la vez, y chance de que el carril
## pase justo por donde está un jugador.
@export var stampede_herd_size: int = 5
@export var stampede_double_chance: float = 0.45
@export var stampede_aim_chance: float = 0.45
## Cuánto antes de entrar a la sala arranca la manada (se escucha y tiembla antes de verla).
@export var stampede_lead: float = 8.0
## En qué escenario puede aparecer el acertijo de Pipo (2 = X-3, el Bosque Tuerto).
@export var riddle_scenario: int = 2

@export_group("Torreta de Pipo")
## GDD: torreta de Pipo, 10 por tiro y 2 tiros por segundo.
@export var turret_damage: float = 10.0
@export var turret_shots_per_second: float = 2.0
@export var turret_range: float = 12.0
