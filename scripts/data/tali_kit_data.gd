class_name TaliKitData
extends Resource
## Números del kit de Tali (KITS_MVP.md). Los que no estaban en los docs están
## anotados en docs/DECISIONES.md.

@export_group("Suerte y Furia")
## Chance de que un ataque enemigo falle solo, en Normal.
@export var luck_miss_chance: float = 0.2
@export var fury_per_damage_taken: float = 0.8
@export var fury_per_damage_dealt: float = 0.12
## Multiplicador si le pegan por la espalda o está rodeado.
@export var fury_bonus_multiplier: float = 2.0
@export var surrounded_count: int = 3
@export var surrounded_radius: float = 3.0
@export var fury_duration: float = 10.0
## Segundos extra de Furia si se entra con la definitiva (premio por usarla; pedido del grupo).
@export var ult_fury_bonus: float = 8.0
@export var fury_damage_taken_multiplier: float = 0.7
## Escala del cuerpo en Furia (placeholder).
@export var fury_body_scale: float = 1.3

@export_group("Resaca")
@export var exhausted_duration: float = 3.0
@export var exhausted_speed_multiplier: float = 0.5
## Desde que termina la Furia, la barra no se carga durante este tiempo.
@export var fury_lockout: float = 6.0

@export_group("Normal: Piedrazo")
@export var rock_damage: float = 18.0
@export var rock_interval: float = 0.8
@export var rock_spread_deg: float = 8.0
@export var rock_speed: float = 20.0
@export var rock_range: float = 13.0
@export var rock_radius: float = 0.3
@export var lucky_shot_chance: float = 0.1
@export var lucky_shot_stun: float = 1.0

@export_group("Normal: Llamado Salvaje")
@export var call_cooldown: float = 12.0
@export var call_weight_birds: float = 45.0
@export var call_weight_bugs: float = 45.0
@export var call_weight_gronk: float = 10.0
@export var birds_distance: float = 6.0
@export var birds_radius: float = 3.5
@export var birds_damage: float = 40.0
@export var birds_blind: float = 3.0
@export var bugs_length: float = 10.0
@export var bugs_width: float = 2.6
@export var bugs_damage: float = 25.0
@export var bugs_knockback: float = 13.0
@export var gronk_length: float = 16.0
@export var gronk_width: float = 2.2
@export var gronk_damage: float = 120.0
@export var gronk_stun: float = 1.5
@export var gronk_speed: float = 18.0

@export_group("Normal: Tropezón")
@export var stumble_distance: float = 2.8
@export var stumble_duration: float = 0.3
@export var dodge_charges: int = 2
@export var dodge_recharge: float = 4.0
@export var lucky_dodge_fury: float = 15.0
@export var lucky_dodge_unbalance: float = 1.0

@export_group("Furia: Zarpazos")
@export var claw_damage: Array[float] = [34.0, 34.0, 52.0]
## Un combo completo de 3 golpes dura esto.
@export var claw_combo_time: float = 1.3
@export var claw_range: float = 2.4
@export var claw_angle_deg: float = 120.0
@export var claw_third_stun: float = 0.5
## Velocidad de movimiento mientras pega (multiplicador).
@export var claw_move_multiplier: float = 0.45
## Si deja de pegar este tiempo, el combo vuelve al primer golpe.
@export var claw_combo_reset: float = 0.6

@export_group("Furia: Aplastón")
@export var slam_cooldown: float = 6.0
@export var slam_damage: float = 90.0
@export var slam_radius: float = 3.0
@export var slam_stun: float = 1.0
@export var slam_max_distance: float = 7.0
@export var slam_air_time: float = 0.45

@export_group("Furia: Embestida")
@export var charge_distance: float = 5.0
@export var charge_duration: float = 0.22
@export var charge_width: float = 1.8
@export var charge_knockdown: float = 1.0

@export_group("Definitiva")
@export var roar_radius: float = 5.0
@export var roar_knockback: float = 9.0
@export var roar_fear: float = 2.0
@export var toss_grab_range: float = 4.0
@export var toss_distance: float = 8.0
@export var toss_thrown_damage: float = 60.0
@export var toss_splash_damage: float = 60.0
@export var toss_splash_radius: float = 2.5
@export var toss_knockdown: float = 1.0
@export var toss_fury_extension: float = 4.0
