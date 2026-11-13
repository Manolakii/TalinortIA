class_name EnemyData
extends Resource
## Datos de un enemigo (GDD, Enemigos). Valores de Normal con 1 jugador.

@export var id: StringName
@export var display_name: String = ""

@export_group("Estadísticas")
@export var max_health: float = 160.0
@export var damage: float = 10.0
## Metros por segundo.
@export var move_speed: float = 3.2
## Qué tan rápido gira (radianes por segundo). Bajo = torpe.
@export var turn_speed: float = 5.0
## Para el Revoleo de Tali: agarra al de mayor tamaño.
@export var size_rank: int = 1

@export_group("Ataque cuerpo a cuerpo")
## A qué distancia empieza a atacar.
@export var attack_range: float = 1.7
## Tiempo de aviso (naranja) antes de pegar.
@export var windup: float = 0.6
## Tiempo quieto después de pegar.
@export var recovery: float = 0.9
## Zona del golpe: sector de este radio y ángulo, hacia adelante.
@export var attack_radius: float = 2.0
@export var attack_angle_deg: float = 100.0
## Empuje que le da al jugador (m/s).
@export var attack_knockback: float = 4.0

@export_group("Grupo")
## Distancia que intentan mantener con otros enemigos.
@export var separation_radius: float = 1.1

@export_group("Placeholder")
@export var body_height: float = 1.7
@export var body_radius: float = 0.42
## Colores más apagados que los de los jugadores (GDD, Estilo visual).
@export var body_color: Color = Color(0.45, 0.38, 0.31)
