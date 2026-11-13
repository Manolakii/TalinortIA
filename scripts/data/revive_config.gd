class_name ReviveConfig
extends Resource
## Muerte y revivir (GDD, Co-op local > Muerte y revivir).

## Tiempo para levantarlo según la caída: la 1.ª, la 2.ª, la 3.ª y de la 4.ª en adelante.
@export var down_times: Array[float] = [25.0, 19.0, 13.0, 8.0]
## Un compañero mantiene interactuar este tiempo al lado del caído.
@export var revive_hold: float = 3.8
@export var revive_radius: float = 2.3
## Si el que revive deja de hacerlo un instante (lo empujan, un golpe), el progreso espera
## este tiempo antes de empezar a bajar.
@export var progress_grace: float = 0.5
## Vida con la que se levanta (parte de la máxima).
@export var revive_health: float = 0.4
@export var revive_invulnerability: float = 1.5
## El caído se arrastra solo, despacio (m/s).
@export var crawl_speed: float = 1.2
## Si sueltan el botón, el progreso baja este tanto más rápido de lo que sube.
@export var progress_decay: float = 1.5
