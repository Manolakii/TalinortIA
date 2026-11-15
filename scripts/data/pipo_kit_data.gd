class_name PipoKitData
extends Resource
## Números del General Pipo (KITS_MVP, GDD).

@export_group("Pasiva: Un Ojo Basta")
## Cono angosto adelante (grados de cada lado) donde la chance de crítico es mayor.
@export var cone_half_deg: float = 12.0
@export var cone_crit_chance: float = 0.20
## Punto ciego: desde su izquierda le pegan más.
@export var blind_spot_damage: float = 0.15

@export_group("Pasiva: Racha de Cuartel")
## Cada básico seguido que acierta suma este bonus de daño al básico; si uno falla, vuelve a 0.
@export var streak_per_hit: float = 0.05
## Tope del bonus (50% del daño base); las mejoras lo suben.
@export var streak_cap: float = 0.5

@export_group("Bláster Reglamentario")
@export var blaster_damage: float = 24.0
@export var blaster_interval: float = 0.7
@export var blaster_speed: float = 34.0
@export var blaster_range: float = 17.0

@export_group("Despliegue de Chatarra")
## Pedido del grupo (2026-11-15): cada torreta dura más que dos recargas, así se llega a
## tener 2 (y 3 con la mejora "Otra torreta") a la vez.
@export var turret_cooldown: float = 12.0
@export var turret_max: int = 2
@export var turret_duration: float = 26.0
@export var turret_health: float = 60.0
@export var turret_damage: float = 7.0
@export var turret_shots_per_second: float = 2.0
@export var turret_range: float = 12.0

@export_group("Repliegue Ordenado")
@export var retreat_distance: float = 4.5
@export var retreat_duration: float = 0.3
@export var retreat_cooldown: float = 3.0
@export var mine_damage: float = 50.0
@export var mine_radius: float = 2.5
@export var mine_trigger: float = 1.6
@export var mine_lifetime: float = 15.0

@export_group("Fuego de la Nave Insignia")
@export var bomb_range: float = 14.0
@export var bomb_radius: float = 7.0
@export var bomb_delay: float = 1.5
@export var bomb_impacts: int = 6
@export var bomb_damage: float = 90.0
@export var bomb_impact_radius: float = 2.5
