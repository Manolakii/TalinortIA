class_name ChampakaKitData
extends Resource
## Números del Capitán Champaka (KITS_MVP, GDD).

@export_group("Pasiva")
## Recibe menos daño siempre (GDD: 15%).
@export var damage_reduction: float = 0.15
## Cada cuánto daño recibido brota un hongo, y cuánto cura.
@export var spores_per_mushroom: float = 100.0
@export var mushroom_heal: float = 5.0
## Papá del grupo: los aliados a esta distancia reciben menos daño.
@export var dad_radius: float = 3.0
@export var dad_reduction: float = 0.1

@export_group("Aplauso de Papá")
## Pedido del grupo (2026-11-15): en vez del combo de 3, un aplauso fuerte que recarga lento.
## Cada aplauso suma la onda en el piso que empuja.
@export var clap_damage: float = 45.0
@export var clap_interval: float = 1.25
@export var swipe_range: float = 2.7
@export var swipe_angle_deg: float = 140.0
@export var swipe_knockback: float = 5.0
## El tercero: onda corta en el piso.
@export var wave_radius: float = 3.0
@export var wave_knockback: float = 7.0

@export_group("Abrazo de Oso")
@export var hug_cooldown: float = 12.0
@export var hug_range: float = 2.8
@export var hug_damage: float = 80.0
@export var hug_hold: float = 1.0
@export var hug_hold_elite: float = 2.0
## Sobre Tali en Furia: le corta la Furia sin Resaca y le cura esta parte de la vida.
@export var hug_tali_heal: float = 0.2

@export_group("Panzazo")
@export var belly_distance: float = 4.0
@export var belly_duration: float = 0.38
@export var belly_recharge: float = 5.0
## No da invulnerabilidad: recibe menos daño durante el trayecto (GDD, Choques: 40%).
@export var belly_damage_reduction: float = 0.4
@export var belly_damage: float = 15.0
@export var belly_knockback: float = 8.0
@export var belly_heal: float = 8.0
@export var belly_heal_radius: float = 3.0

@export_group("Floración del Hongo")
@export var bloom_duration: float = 8.0
@export var bloom_radius: float = 6.0
@export var bloom_heal_per_second: float = 8.0
