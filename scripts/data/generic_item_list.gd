class_name GenericItemList
extends Resource
## Todos los objetos de sala y cómo se ofrecen (pedido del grupo, 2026-11-20): cada opción tira
## la rareza (60% común, 32% raro, 8% legendario) y elige un objeto de esa rareza que el jugador
## pueda subir (si ya lo tiene, se ofrece el nivel siguiente; al máximo no aparece).

@export var items: Array[GenericItem] = []
## Chance de cada rareza en cada opción: común, raro, legendario.
@export var rarity_weights: PackedFloat32Array = PackedFloat32Array([0.6, 0.32, 0.08])


func get_item(id: StringName) -> GenericItem:
	for item: GenericItem in items:
		if item.id == id:
			return item
	return null


## Nivel que tiene de cada objeto (los ids repetidos en la lista = el nivel).
static func level_of(owned: Array, id: StringName) -> int:
	return owned.count(id)


## Objetos que todavía se pueden ofrecer (no están al nivel máximo).
func available(owned: Array) -> Array[GenericItem]:
	var result: Array[GenericItem] = []
	for item: GenericItem in items:
		if level_of(owned, item.id) < item.max_level():
			result.append(item)
	return result


## `count` opciones distintas, cada una con su rareza tirada al azar.
func offer(owned: Array, rng: RandomNumberGenerator, count: int) -> Array[GenericItem]:
	var pool: Array[GenericItem] = available(owned)
	var result: Array[GenericItem] = []
	while result.size() < count and not pool.is_empty():
		var rarity: int = roll_rarity(rng)
		var of_rarity: Array[GenericItem] = []
		# Si no queda ninguno de esa rareza, prueba la de abajo (y después cualquiera).
		for r: int in range(rarity, -1, -1):
			for item: GenericItem in pool:
				if item.rarity == r:
					of_rarity.append(item)
			if not of_rarity.is_empty():
				break
		if of_rarity.is_empty():
			of_rarity = pool.duplicate()
		var chosen: GenericItem = of_rarity[rng.randi_range(0, of_rarity.size() - 1)]
		result.append(chosen)
		pool.erase(chosen)
	return result


func roll_rarity(rng: RandomNumberGenerator) -> int:
	var roll: float = rng.randf()
	var accumulated: float = 0.0
	for r: int in rarity_weights.size():
		accumulated += rarity_weights[r]
		if roll < accumulated:
			return r
	return 0
