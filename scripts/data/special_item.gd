class_name SpecialItem
extends Resource
## Objeto especial (GDD, "Objetos especiales"): no sube números, agrega un efecto nuevo.
## Se compra en la tienda de Yole Sajor. Los efectos están en SpecialItemEffects.

enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

@export var id: StringName
@export var display_name: String = ""
@export var description: String = ""
@export var rarity: Rarity = Rarity.COMMON
