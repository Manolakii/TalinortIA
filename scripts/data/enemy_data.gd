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

@export_group("Distancia y ritmo")
## Distancia que intenta mantener con su objetivo (0 = va al cuerpo a cuerpo).
@export var preferred_distance: float = 0.0
## Tiempo entre ataques (los de distancia).
@export var attack_interval: float = 2.0

@export_group("Proyectiles")
@export var projectile_speed: float = 16.0
@export var projectile_count: int = 1
@export var spread_deg: float = 0.0
@export var projectile_range: float = 14.0
## Piedras en parábola: tiempo de vuelo y radio del impacto.
@export var flight_time: float = 1.0
@export var impact_radius: float = 1.3

@export_group("Embestidas y cargas")
@export var dash_distance: float = 0.0
@export var charge_speed: float = 0.0
@export var charge_max_distance: float = 0.0
@export var charge_width: float = 1.6
## Aturdido si choca contra una pared.
@export var wall_stun: float = 0.0

@export_group("Zonas y auras")
@export var zone_radius: float = 0.0
@export var zone_dps: float = 0.0
@export var aura_radius: float = 0.0
## Velocidad extra que da a los cegados cercanos (0,2 = +20%).
@export var aura_speed_bonus: float = 0.0
## Al morir: aturde a los cegados cercanos este tiempo...
@export var death_stun: float = 0.0
## ...y esta parte de ellos despierta y huye.
@export var wake_chance: float = 0.0

@export_group("Grupo")
## Distancia que intentan mantener con otros enemigos.
@export var separation_radius: float = 1.1

@export_group("Placeholder")
@export var body_height: float = 1.7
@export var body_radius: float = 0.42
## Colores más apagados que los de los jugadores (GDD, Estilo visual).
@export var body_color: Color = Color(0.45, 0.38, 0.31)
