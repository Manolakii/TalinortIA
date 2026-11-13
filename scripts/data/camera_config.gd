class_name CameraConfig
extends Resource
## Configuración de la cámara compartida (GDD, Presentación > Cámara).

## Inclinación hacia abajo, en grados desde la horizontal.
@export var pitch_degrees: float = 55.0
## FOV vertical, en grados.
@export var fov_degrees: float = 32.0

@export_group("Tamaño en pantalla")
## Altura de referencia de un personaje, en metros.
@export var character_height_m: float = 1.8
## Profundidad del cuerpo, en metros. Desde arriba también se ve la parte de arriba
## del personaje, así que la silueta en pantalla es más alta que solo el alto proyectado.
@export var character_depth_m: float = 0.35
## Cuántos píxeles queremos que mida la silueta de ese personaje en pantalla (a 1080p).
@export var target_character_px: float = 75.0
@export var reference_viewport_height: float = 1080.0
## Si es mayor que 0, se usa esta distancia en lugar de calcularla.
@export var distance_override: float = 0.0

@export_group("Grupo")
## Cuánto se puede alejar como máximo cuando el grupo se separa (1.12 = 12%).
@export var max_zoom_out: float = 1.12
## Margen libre en los bordes de la pantalla, en píxeles a 1080p.
## El de abajo es más grande para dejar lugar a los paneles del HUD.
@export var margin_px_top: float = 70.0
@export var margin_px_bottom: float = 150.0
@export var margin_px_sides: float = 70.0

@export_group("Suavizado")
## Más alto = sigue más pegado al grupo.
@export var follow_speed: float = 6.0
@export var zoom_speed: float = 3.0


## Distancia de la cámara al punto que mira, para que un personaje mida target_character_px.
func get_base_distance() -> float:
	if distance_override > 0.0:
		return distance_override
	var visible_height_m: float = silhouette_height_m() * reference_viewport_height / target_character_px
	return visible_height_m / (2.0 * tan(deg_to_rad(fov_degrees) * 0.5))


## Alto de la silueta del personaje en el plano de la cámara: el alto se proyecta con
## cos(pitch) y la profundidad del cuerpo con sin(pitch).
func silhouette_height_m() -> float:
	var pitch: float = deg_to_rad(pitch_degrees)
	return character_height_m * cos(pitch) + character_depth_m * sin(pitch)
