class_name LightPreset
extends Resource
## Luz y posprocesado de un escenario (Fase 8: pasada de iluminación por sala).

@export var sun_color: Color = Color(1, 0.91, 0.78)
@export var sun_energy: float = 1.5
## Inclinación del sol en grados (más bajo = sombras más largas).
@export var sun_pitch_deg: float = -55.0
@export var ambient_energy: float = 0.75
@export var fog_color: Color = Color(0.74, 0.78, 0.8)
@export var fog_density: float = 0.0022
@export var saturation: float = 1.0
@export var contrast: float = 1.08
