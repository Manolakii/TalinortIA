class_name GenericItemList
extends Resource
## Todos los objetos genéricos que pueden salir al terminar un escenario.

@export var items: Array[GenericItem] = []


func get_item(id: StringName) -> GenericItem:
	for item: GenericItem in items:
		if item.id == id:
			return item
	return null
