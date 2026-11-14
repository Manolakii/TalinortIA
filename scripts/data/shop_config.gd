class_name ShopConfig
extends Resource
## La tienda de Yole Sajor (GDD, "Yole Sajor y Birig Bamba").

@export var items: Array[SpecialItem] = []
## Precio por rareza: Común, Raro, Épico, Legendario.
@export var rarity_prices: Array[int] = [70, 150, 250, 470]
@export var rarity_names: Array[String] = ["Común", "Raro", "Épico", "Legendario"]
## Chance de cada rareza según la visita (0 = antes del Stage 1, 1 = antes del 2, 2 = antes del 3).
@export var visit_chances: Array[PackedFloat32Array] = []
## Objetos especiales en el stock de cada jugador, y la mejora de kit.
@export var stock_size: int = 4
@export var kit_upgrade_price: int = 120
## Volver a tirar el stock: cuesta esto, y sube esto cada vez (por jugador y por visita).
@export var reroll_base: int = 25
@export var reroll_step: int = 25


func get_item(id: StringName) -> SpecialItem:
	for item: SpecialItem in items:
		if item.id == id:
			return item
	return null


func price_of(item: SpecialItem) -> int:
	return rarity_prices[item.rarity]


## Stock de un jugador: `stock_size` objetos distintos que no tenga, con la rareza de la visita.
func roll_stock(owned: Array, visit: int, rng: RandomNumberGenerator) -> Array[SpecialItem]:
	var chances: PackedFloat32Array = visit_chances[clampi(visit, 0, visit_chances.size() - 1)]
	var result: Array[SpecialItem] = []
	for attempt: int in 40:
		if result.size() >= stock_size:
			break
		var roll: float = rng.randf()
		var rarity: int = 0
		var accumulated: float = 0.0
		for r: int in chances.size():
			accumulated += chances[r]
			if roll < accumulated:
				rarity = r
				break
		var pool: Array[SpecialItem] = []
		for item: SpecialItem in items:
			if item.rarity == rarity and not owned.has(item.id) and not result.has(item):
				pool.append(item)
		if pool.is_empty():
			continue
		result.append(pool[rng.randi_range(0, pool.size() - 1)])
	return result
