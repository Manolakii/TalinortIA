class_name ShopConfig
extends Resource
## El Black Market de Yole Sajor (GDD; documento del grupo "Objetos, mejoras y reliquias",
## 2026-11-20). Reliquias generales, reliquias de personaje y la Mystery Box.

@export var items: Array[SpecialItem] = []
## Precio por rareza: Común, Rara, Legendaria (las malditas no se venden).
@export var rarity_prices: Array[int] = [75, 150, 550]
## Chance de cada rareza en el stock según la visita (común, rara, legendaria).
@export var visit_chances: Array[PackedFloat32Array] = []
## Reliquias generales en el stock de cada jugador.
@export var stock_size: int = 4
## Reliquias de personaje: la rara (las mejoras de tienda suaves) y la legendaria (cambian el kit).
@export var kit_upgrade_price: int = 150
@export var character_legendary_price: int = 550
## Mystery Box: vale lo que el oro inicial y da una reliquia al azar.
@export var mystery_box_price: int = 125
## Chances de la Mystery Box: maldita, rara, legendaria.
@export var mystery_box_odds: PackedFloat32Array = PackedFloat32Array([0.2, 0.72, 0.08])
## Volver a tirar el stock: cuesta esto, y sube esto cada vez (por jugador y por visita).
@export var reroll_base: int = 25
@export var reroll_step: int = 25


func get_item(id: StringName) -> SpecialItem:
	for item: SpecialItem in items:
		if item.id == id:
			return item
	return null


func price_of(item: SpecialItem) -> int:
	return rarity_prices[mini(item.rarity, rarity_prices.size() - 1)]


## Reliquias de esa rareza que el jugador no tiene.
func pool(rarity: int, owned: Array) -> Array[SpecialItem]:
	var result: Array[SpecialItem] = []
	for item: SpecialItem in items:
		if item.rarity == rarity and not owned.has(item.id):
			result.append(item)
	return result


## Stock de un jugador: `stock_size` reliquias distintas que no tenga (nunca malditas).
func roll_stock(owned: Array, visit: int, rng: RandomNumberGenerator) -> Array[SpecialItem]:
	var chances: PackedFloat32Array = visit_chances[clampi(visit, 0, visit_chances.size() - 1)]
	var result: Array[SpecialItem] = []
	for attempt: int in 40:
		if result.size() >= stock_size:
			break
		var rarity: int = _roll(chances, rng)
		var options: Array[SpecialItem] = pool(rarity, owned + result.map(func(i: SpecialItem) -> StringName: return i.id))
		if options.is_empty():
			continue
		result.append(options[rng.randi_range(0, options.size() - 1)])
	return result


## Qué sale de la Mystery Box: 0 maldita, 1 rara, 2 legendaria.
func roll_box(rng: RandomNumberGenerator) -> int:
	return [SpecialItem.Rarity.CURSED, SpecialItem.Rarity.RARE, SpecialItem.Rarity.LEGENDARY][_roll(mystery_box_odds, rng)]


static func _roll(chances: PackedFloat32Array, rng: RandomNumberGenerator) -> int:
	var roll: float = rng.randf()
	var accumulated: float = 0.0
	for r: int in chances.size():
		accumulated += chances[r]
		if roll < accumulated:
			return r
	return 0
