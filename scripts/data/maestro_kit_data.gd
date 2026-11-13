class_name MaestroKitData
extends Resource
## Números del dúo Maestro Uwey y Stewie (KITS_MVP.md). Los que no estaban en los docs
## están anotados en docs/DECISIONES.md.

@export_group("Maestro")
@export var maestro_max_health: float = 110.0
@export var maestro_move_speed: float = 5.6
@export var maestro_height: float = 1.75
@export var maestro_radius: float = 0.4
@export var staff_damage: Array[float] = [18.0, 18.0, 34.0]
## Duración de cada golpe del combo (suman 1,4 s).
@export var staff_step_durations: Array[float] = [0.4, 0.4, 0.6]
@export var staff_range: float = 2.3
@export var staff_angle_deg: float = 100.0
## El tercer golpe planta el bastón y suelta una onda corta.
@export var staff_wave_length: float = 3.5
@export var staff_wave_width: float = 1.4
@export var bastonazo_cooldown: float = 10.0
@export var bastonazo_full_charge: float = 1.0
@export var bastonazo_max_hold: float = 2.0
@export var bastonazo_min_damage: float = 60.0
@export var bastonazo_max_damage: float = 120.0
@export var bastonazo_length: float = 9.0
@export var bastonazo_width: float = 1.6
@export var pole_distance: float = 4.5
@export var pole_duration: float = 0.4
@export var pole_charges: int = 2
@export var pole_recharge: float = 4.0

@export_group("Stewie")
## Vida según la forma: Cría, Joven, Sabia.
@export var stewie_health_by_form: Array[float] = [80.0, 110.0, 140.0]
## Cambia de forma con esta cantidad de mejoras (3 y 6).
@export var stewie_upgrades_per_form: int = 3
@export var stewie_move_speed: float = 5.8
@export var stewie_height: float = 0.9
@export var stewie_radius: float = 0.5
@export var headbutt_damage: float = 14.0
@export var headbutt_interval: float = 0.9
@export var headbutt_range: float = 1.6
@export var headbutt_angle_deg: float = 90.0
@export var headbutt_knockback: float = 3.0
@export var refuge_cooldown: float = 10.0
@export var refuge_duration: float = 2.0
@export var roll_distance: float = 4.0
@export var roll_duration: float = 0.3
@export var roll_charges: int = 2
@export var roll_recharge: float = 4.0

@export_group("Dúo")
@export var bond_distance: float = 8.0
## +10% de daño y de resistencia dentro del Vínculo.
@export var bond_bonus: float = 0.1
## Más lejos que esto, el que maneja la IA vuelve hacia el otro.
@export var leash_distance: float = 10.0
## Más lejos que esto (por ejemplo, después de un Cambio), aparece al lado.
@export var teleport_distance: float = 18.0
@export var follow_distance: float = 2.5
## La IA ataca a lo último que golpeó el jugador, si está a esta distancia del jugador.
@export var companion_target_range: float = 6.0

@export_group("Compañero (IA)")
## Mientras lo maneja la IA, recibe esta parte del daño (0,6 = 40% menos).
@export var companion_damage_taken: float = 0.6
## Más de 1: los enemigos prefieren a los jugadores antes que al compañero.
@export var companion_target_priority: float = 1.6
## Con menos de esta vida se repliega al lado del jugador y deja de pelear...
@export var companion_retreat_health: float = 0.4
## ...hasta recuperar esta.
@export var companion_recover_health: float = 0.7
## Mientras se repliega sin enemigos cerca, recupera esta parte de su vida máxima por segundo.
@export var companion_regen: float = 0.03
## "Sin enemigos cerca" = ninguno a esta distancia.
@export var companion_safe_radius: float = 4.0
## El Maestro (IA) tira el Bastonazo si en la línea hay al menos esta cantidad de enemigos...
@export var companion_bastonazo_min_targets: int = 2
## ...cargándolo este tiempo (0,6 s = 96 de daño).
@export var companion_bastonazo_charge: float = 0.6
## Stewie (IA) rueda hacia el objetivo si está más lejos que esto.
@export var companion_roll_min_distance: float = 4.0
@export var fallen_revive_time: float = 15.0
@export var fallen_revive_health: float = 0.5
@export var switch_cooldown: float = 6.0

@export_group("Relevo Total (base)")
@export var relay_duration: float = 8.0
@export var ancestral_scale: float = 2.0
@export var ancestral_damage_bonus: float = 0.5
@export var ancestral_health_bonus: float = 0.5
