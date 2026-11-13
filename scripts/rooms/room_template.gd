class_name RoomTemplate
extends Node3D
## Plantilla de sala: las rocas (RockProp) y marcadores para poblarla al azar.
## Hijos esperados (todos Marker3D adentro de su nodo):
##   VaseSpots: lugares posibles para vasijas.
##   ChestSpot: el cofre del Tesoro.
##   FeatureSpots: lugares para eventos (jaulas, cofres sospechosos). Al menos 4.
##   RiddleSpot: el cartel del acertijo de Pipo.
## Los jugadores entran por el sur y las puertas aparecen en el norte: dejar libre esa franja.

@export var template_name: String = ""


func vase_spots() -> Array[Vector3]:
	return _markers(&"VaseSpots")


func feature_spots() -> Array[Vector3]:
	return _markers(&"FeatureSpots")


func chest_spot() -> Vector3:
	var marker := get_node_or_null(^"ChestSpot") as Node3D
	return marker.global_position if marker != null else Vector3(0, 0, -4)


func riddle_spot() -> Vector3:
	var marker := get_node_or_null(^"RiddleSpot") as Node3D
	return marker.global_position if marker != null else Vector3(-6, 0, 4)


func _markers(group_name: StringName) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var parent: Node = get_node_or_null(NodePath(group_name))
	if parent == null:
		return result
	for child: Node in parent.get_children():
		if child is Node3D:
			result.append((child as Node3D).global_position)
	return result
