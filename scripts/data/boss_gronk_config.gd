class_name BossGronkConfig
extends Resource
## Números del Gronk Gigante (GDD, Bosses: Gronk Gigante 1-4). Los de vida, daño base y
## movimiento están en data/enemies/gronk_gigante.tres.

@export_group("Fases")
## La fase 2 empieza con esta proporción de vida, y la 3 con esta.
@export var phase_two_at: float = 0.66
@export var phase_three_at: float = 0.33
## Rugido de cambio de fase (invulnerable mientras tanto).
@export var phase_roar_time: float = 1.6

@export_group("Carga")
@export var charge_windup: float = 1.0
@export var charge_speed: float = 20.0
@export var charge_max_distance: float = 30.0
@export var charge_width: float = 3.2
@export var charge_damage: float = 35.0
## Contra una columna: aturdido y recibe más daño (GDD: 3 s y +50%).
@export var column_stun: float = 3.0
@export var vulnerable_multiplier: float = 1.5
## Contra una pared: solo un porrazo corto.
@export var wall_stun: float = 1.0
## Cargas seguidas en cada fase (GDD: 1, 2 y 3).
@export var charges_per_phase: Array[int] = [1, 2, 3]

@export_group("Pisotón y rugido")
@export var stomp_radius: float = 5.0
## Pedido del grupo: el aplastamiento sale más rápido (era 0,9 y se esquivaba fácil).
@export var stomp_windup: float = 0.55
@export var stomp_damage: float = 30.0
## Espera entre pisotones (si no, pelear cuerpo a cuerpo era imposible).
@export var stomp_cooldown: float = 4.0
## Cada cuánto ruge y llama Talinorteanos cegados, y cuántos (+1 con 3 o más jugadores).
## Pedido del grupo: llama en todas las fases, más seguido y más; desde la fase 2 también
## vienen Honderos. No llama si ya hay `summon_max_alive` enemigos chicos.
@export var roar_interval: float = 12.0
@export var summon_count: int = 4
@export var summon_max_alive: int = 8
@export var summon_ids_phase_two: Array[StringName] = [&"talinorteano_cegado", &"talinorteano_cegado", &"hondero_cegado"]

@export_group("Sombra (fase 2 en adelante)")
## Rocas con círculo de aviso: cada cuánto, daño, radio y tiempo de vuelo.
@export var rocks_interval: float = 7.0
@export var rocks_damage: float = 22.0
@export var rocks_radius: float = 2.0
@export var rocks_flight: float = 1.2
## Charcos de sombra que deja al cargar (ralentizan).
@export var puddle_radius: float = 3.0
@export var puddle_duration: float = 8.0

@export_group("Onda de sombra (fase 3)")
@export var wave_interval: float = 11.0
@export var wave_windup: float = 1.2
@export var wave_speed: float = 10.0
@export var wave_damage: float = 30.0
@export var wave_gap_deg: float = 60.0

@export_group("Cristal de sombra (fase 3)")
## Pedido del grupo: en la fase 3 aparece un cristal que cura al boss hasta que lo rompen.
## Cura `crystal_heal_ratio` de la vida máxima por segundo, sin pasar de `crystal_heal_cap` de la
## vida (no vuelve de fase). Pedido del grupo: que romperlo sea casi obligatorio. Como es una
## parte de la vida máxima, escala sola con los jugadores (6.000 de vida: 72 por segundo).
@export var crystal_health: float = 500.0
@export var crystal_heal_ratio: float = 0.012
@export var crystal_heal_cap: float = 0.5
## Dónde aparece (el más lejos del boss de estos lugares).
@export var crystal_spots: Array[Vector3] = [Vector3(-15, 0, -9), Vector3(15, 0, -9), Vector3(-15, 0, 9), Vector3(15, 0, 9)]

@export_group("Otros")
## Pausa entre ataques (se acorta en Difícil con el ritmo de ataque).
@export var idle_time: float = 1.4
## El Llamado Salvaje de Tali lo hace dudar: aturdido este tiempo, con este cooldown.
@export var wild_call_stun: float = 2.5
@export var wild_call_cooldown: float = 12.0
