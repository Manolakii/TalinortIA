class_name CharacterData
extends Resource
## Datos base de un personaje jugable.
## Valores de referencia del GDD: Stage 1, Normal, 1 jugador, sin objetos.

@export var id: StringName
@export var display_name: String = ""
## Texto corto que se muestra en la pantalla de unión.
@export_multiline var blurb: String = ""

@export_group("Estadísticas")
@export var max_health: float = 100.0
## Metros por segundo.
@export var move_speed: float = 5.6
## 0.05 = 5%.
@export var crit_chance: float = 0.05
## 1.5 = 150% de daño.
@export var crit_multiplier: float = 1.5

@export_group("Movimiento (feel)")
## Qué tan rápido llega a la velocidad máxima (m/s²). Alto = respuesta inmediata.
@export var acceleration: float = 90.0
## Qué tan rápido frena al soltar el stick (m/s²).
@export var deceleration: float = 120.0
## Velocidad de giro hacia donde apunta (radianes por segundo).
@export var turn_speed: float = 22.0

@export_group("Placeholder")
## Alto y radio de la cápsula mientras no hay modelo final.
@export var placeholder_height: float = 1.8
@export var placeholder_radius: float = 0.4
