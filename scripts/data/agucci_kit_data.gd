class_name AgucciKitData
extends Resource
## Números del kit de Agucci (KITS_MVP.md y GDD, Posesión). Los que no estaban en los
## docs están anotados en docs/DECISIONES.md.

@export_group("Hambre")
## Lucidez: de 0 a este valor (ataques por la espalda = crítico garantizado).
@export var lucidity_max: float = 30.0
## En la zona de Hambre: +1% de daño por punto.
@export var hunger_damage_per_point: float = 0.01
## Cada golpe común que conecta baja el Hambre esto.
@export var hunger_drop_per_basic_hit: float = 1.5
## Cerca de Tali, el Hambre baja sola.
@export var tali_synergy_radius: float = 6.0
@export var tali_synergy_decay: float = 3.0

@export_group("Katana y Plomo")
@export var cut_damage: Array[float] = [20.0, 20.0, 24.0]
@export var kick_damage: float = 14.0
@export var uzi_bullets: int = 5
@export var uzi_damage: float = 6.0
## Duración de cada paso del combo: 3 cortes, patada y UZI (suman ~1,4 s).
@export var step_durations: Array[float] = [0.2, 0.2, 0.2, 0.3, 0.5]
@export var cut_range: float = 2.2
@export var cut_angle_deg: float = 110.0
@export var kick_range: float = 1.9
@export var kick_angle_deg: float = 80.0
@export var kick_knockback: float = 6.0
@export var uzi_spread_deg: float = 40.0
@export var uzi_speed: float = 30.0
@export var uzi_range: float = 10.0
@export var uzi_gap: float = 0.08
@export var combo_reset: float = 0.6

@export_group("Paso de Sombra")
@export var step_cooldown: float = 8.0
@export var step_hunger: float = 20.0
@export var kunai_damage: float = 40.0
@export var kunai_speed: float = 30.0
@export var kunai_range: float = 12.0
## Tiempo para reactivar (viajar al kunai) antes de que desaparezca.
@export var kunai_window: float = 4.0
@export var dash_damage: float = 110.0
@export var dash_width: float = 1.8
@export var dash_time: float = 0.15
## Si mata con el corte, recupera esta parte del cooldown.
@export var dash_kill_refund: float = 0.5

@export_group("Disolverse")
@export var dissolve_distance: float = 4.5
@export var dissolve_duration: float = 0.25
@export var dissolve_charges: int = 2
@export var dissolve_recharge: float = 4.0

@export_group("Noche del Valle sin Luz")
@export var night_duration: float = 8.0
@export var night_hunger: float = 50.0
## La sombra repite cada golpe este tiempo después.
@export var night_echo_delay: float = 0.12
## Si no ataca durante este tiempo, los enemigos lo pierden de vista.
@export var night_hide_after: float = 0.6

@export_group("Posesión")
@export var possession_duration: float = 6.0
## Si entra en Posesión al lado de Tali, dura esta parte.
@export var possession_tali_multiplier: float = 0.5
@export var possession_damage_multiplier: float = 1.6
@export var possession_speed_multiplier: float = 1.4
@export var possession_auto_radius: float = 2.2
@export var possession_auto_damage: float = 30.0
@export var possession_auto_interval: float = 0.5
## Robo de vida del ataque automático.
@export var possession_lifesteal: float = 0.2
## Sin enemigos a la vista, la sombra le saca esta parte de la vida máxima por segundo.
@export var possession_self_drain: float = 0.02
## Las habilidades de la Posesión cuestan esta parte de la vida actual...
@export var possession_skill_cost: float = 0.05
## ...y si conectan, curan esta parte del daño que hacen.
@export var possession_skill_heal: float = 0.08
@export var bite_distance: float = 5.0
@export var bite_damage: float = 35.0
@export var bite_hits: int = 2
@export var bite_width: float = 1.6
@export var bite_time: float = 0.18
@export var bite_cooldown: float = 3.0
@export var embrace_radius: float = 5.0
## Daño total por enemigo durante el Abrazo.
@export var embrace_damage: float = 40.0
@export var embrace_duration: float = 1.0
@export var embrace_pull_speed: float = 6.0
@export var embrace_cooldown: float = 4.0
