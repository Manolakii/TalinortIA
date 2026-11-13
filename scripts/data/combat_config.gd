class_name CombatConfig
extends Resource
## Reglas generales de combate y de "feel" (respuesta, hitstop, sacudida de cámara).

@export_group("Reglas")
## Invulnerabilidad al inicio de la esquiva (GDD, Controles).
@export var dodge_invulnerability: float = 0.25
## Si apretás un botón un poquito antes de poder usarlo, se guarda este tiempo.
@export var input_buffer_time: float = 0.15
## Cómo se frena el empuje (knockback): más alto = frena antes.
@export var knockback_damping: float = 9.0
## Multiplicador de velocidad del estado "veloz" (rastro de Ruta de Escape del Croco).
@export var haste_multiplier: float = 1.3
## Multiplicador de velocidad del estado "lento" (charcos de sombra).
@export var slow_multiplier: float = 0.6

@export_group("Imán de apuntado (joystick)")
@export var aim_magnet_angle_deg: float = 22.0
@export var aim_magnet_range: float = 14.0
## 0 = sin imán, 1 = apunta justo al enemigo.
@export_range(0.0, 1.0) var aim_magnet_strength: float = 0.65

@export_group("Hitstop (congelado corto al pegar)")
@export var hitstop_light: float = 0.045
@export var hitstop_heavy: float = 0.09
## Se suma si el golpe es crítico.
@export var hitstop_crit_bonus: float = 0.025

@export_group("Sacudida de cámara (0 a 1)")
@export var shake_light: float = 0.08
@export var shake_heavy: float = 0.3
@export var shake_player_hurt: float = 0.22
## Desplazamiento máximo de la cámara con sacudida 1, en metros.
@export var shake_max_offset: float = 0.6
## Cuánto tarda en calmarse (unidades de "trauma" por segundo).
@export var shake_decay: float = 1.8

@export_group("Destello al recibir daño")
@export var flash_duration: float = 0.12
@export var flash_energy: float = 2.2
