@tool
class_name RockProp
extends StaticBody3D
## Roca de las plantillas de sala: se ajusta el tamaño desde el editor y arma su malla y colisión.

const ROCK_MATERIAL: Material = preload("res://assets/materials/rock_material.tres")

## Ancho (x), alto (y) y fondo (z) en metros.
@export var size: Vector3 = Vector3(2.0, 1.4, 2.0):
	set(value):
		size = value
		if is_inside_tree():
			_rebuild()


func _ready() -> void:
	collision_layer = 512
	collision_mask = 0
	_rebuild()


func _rebuild() -> void:
	for child: Node in get_children():
		if child.has_meta(&"generated"):
			child.free()
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	sphere.material = ROCK_MATERIAL
	mesh_instance.mesh = sphere
	mesh_instance.scale = Vector3(size.x * 0.5, size.y * 0.5, size.z * 0.5)
	mesh_instance.position.y = size.y * 0.2
	mesh_instance.set_meta(&"generated", true)
	add_child(mesh_instance)
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = maxf(size.x, size.z) * 0.45
	cylinder.height = size.y * 1.4
	shape.shape = cylinder
	shape.position.y = size.y * 0.3
	shape.set_meta(&"generated", true)
	add_child(shape)
