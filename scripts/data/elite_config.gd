class_name EliteConfig
extends Resource
## Élites (GDD, Enemigos): 2,5 veces la vida, un poco más grandes y con afijos.

@export var health_multiplier: float = 2.5
@export var scale: float = 1.25
@export_group("Blindado")
## Recibe esta parte del daño que viene de frente (0,5 = 50% menos).
@export var armored_front_damage: float = 0.5
## "De frente" = dentro de este ángulo total.
@export var armored_front_angle_deg: float = 140.0
@export_group("Veloz")
@export var fast_speed_multiplier: float = 1.4
@export_group("Sombrío")
## Cada cuánto deja un charco que ralentiza.
@export var puddle_interval: float = 1.5
@export var puddle_duration: float = 4.0
@export var puddle_radius: float = 1.4
@export_group("Explosivo")
@export var explosion_radius: float = 3.0
## Aviso antes de explotar.
@export var explosion_delay: float = 0.8
@export var explosion_damage: float = 20.0
