class_name PlayerSlotsConfig
extends Resource
## Colores y nombres de los 4 lugares de jugador (P1 a P4). El color es del jugador, no del personaje.

@export var colors: Array[Color] = []
@export var labels: Array[String] = ["P1", "P2", "P3", "P4"]
@export var max_players: int = 4
