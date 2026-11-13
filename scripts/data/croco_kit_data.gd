class_name CrocoKitData
extends Resource
## Números del kit del Mercenario Croco (KITS_MVP.md). Los que no estaban en los docs
## están anotados en docs/DECISIONES.md.

@export_group("Arma Adaptativa")
## Hasta esta distancia al enemigo apuntado: escopeta.
@export var near_max_distance: float = 4.5
## Hasta esta distancia: pistola. Más lejos: rifle.
@export var mid_max_distance: float = 11.0
## Margen para no cambiar ida y vuelta en el límite: hay que pasarse este tanto.
@export var mode_hysteresis: float = 1.0
## Para elegir "el enemigo apuntado": cono alrededor de la mira y distancia máxima.
@export var target_cone_deg: float = 25.0
@export var target_max_distance: float = 26.0
## Opción A (DECISIONES 2026-11-13): el modo se elige al empezar a disparar y queda trabado
## mientras siga disparando. Se destraba si suelta el disparo este tiempo o muere el objetivo.
@export var lock_release_time: float = 0.3
## Aros en el piso que muestran dónde cambia cada arma.
@export var show_range_rings: bool = true
## El primer disparo después de cada cambio de modo hace este extra.
@export var mode_switch_bonus: float = 0.3
@export var bullet_radius: float = 0.2

@export_group("Escopeta (cerca)")
@export var shotgun_pellets: int = 7
@export var shotgun_damage: float = 10.0
@export var shotgun_interval: float = 1.0
@export var shotgun_spread_deg: float = 32.0
@export var shotgun_range: float = 7.0
@export var shotgun_speed: float = 32.0
@export var shotgun_knockback: float = 5.0

@export_group("Pistola (media), tipo revólver")
## Pedido del grupo: más lenta y que pegue más (antes 16 a 3,2 tiros/s).
@export var pistol_damage: float = 34.0
## 1,6 tiros por segundo.
@export var pistol_interval: float = 0.625
@export var pistol_knockback: float = 2.5
@export var pistol_range: float = 18.0
@export var pistol_speed: float = 38.0

@export_group("Rifle (lejos)")
@export var rifle_damage: float = 22.0
@export var rifle_burst: int = 3
@export var rifle_burst_gap: float = 0.08
@export var rifle_interval: float = 1.0
@export var rifle_range: float = 26.0
@export var rifle_speed: float = 48.0

@export_group("Tiro por Contrato")
@export var contract_cooldown: float = 10.0
## Carga completa en este tiempo.
@export var contract_full_charge: float = 1.5
## Si lo sigue manteniendo, dispara solo a este tiempo.
@export var contract_max_hold: float = 3.0
@export var contract_min_damage: float = 60.0
@export var contract_max_damage: float = 180.0
@export var contract_length: float = 26.0
@export var contract_width: float = 0.9
## Si mata, recupera esta parte del cooldown.
@export var contract_kill_refund: float = 0.4
## Daño extra acumulable por cada muerte, para toda la partida (0,002 = +0,2%).
@export var contract_stack_bonus: float = 0.002

@export_group("Ruta de Escape")
@export var dodge_distance: float = 4.2
@export var dodge_duration: float = 0.3
@export var dodge_charges: int = 2
@export var dodge_recharge: float = 4.0
@export var decoy_duration: float = 1.5
## Menos de 1: los enemigos lo prefieren antes que a un jugador a la misma distancia.
@export var decoy_priority: float = 0.35
@export var trail_duration: float = 2.0
@export var trail_width: float = 1.6
@export var haste_duration: float = 1.5

@export_group("Riel (definitiva)")
@export var rail_dps: float = 120.0
@export var rail_duration: float = 4.0
@export var rail_tick: float = 0.1
@export var rail_length: float = 24.0
@export var rail_width: float = 1.2
## Qué tan rápido sigue a la mira (grados por segundo): "gira lento".
@export var rail_turn_speed_deg: float = 50.0
@export var rail_move_multiplier: float = 0.25
## Después del Riel, solo pistola durante este tiempo.
@export var overheat_duration: float = 3.0
