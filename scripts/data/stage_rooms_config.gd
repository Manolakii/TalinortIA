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

@export_group("Puertas")
## Peso de cada tipo de sala al elegir las dos puertas, en el orden de RoomKind.Type
## (Combate, Combate + mejora, Élite, Tesoro, Mimics, Colonia de presos). La Cabaña no sale así.
@export var door_weights: Array[int] = [40, 20, 15, 10, 8, 7]

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
@export var prisoner_gold: int = 6
@export var cage_open_time: float = 1.5
## En qué escenario puede aparecer el acertijo de Pipo (2 = X-3, el Bosque Tuerto).
@export var riddle_scenario: int = 2

@export_group("Torreta de Pipo")
## GDD: torreta de Pipo, 10 por tiro y 2 tiros por segundo.
@export var turret_damage: float = 10.0
@export var turret_shots_per_second: float = 2.0
@export var turret_range: float = 12.0
