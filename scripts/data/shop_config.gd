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
## La Mystery Box sale de un "mazo" de boletos por jugador (con las chances de arriba: de 25,
## 5 malditas, 18 raras y 2 legendarias) que se mezcla y se vuelve a armar al vaciarse. Así las
## chances se cumplen de verdad (2026-11-20: el grupo tiró varias y nunca salió una maldita).
@export var mystery_box_bag_size: int = 25
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


const BOX_RARITIES: Array[int] = [SpecialItem.Rarity.CURSED, SpecialItem.Rarity.RARE, SpecialItem.Rarity.LEGENDARY]


## Qué sale de la Mystery Box (una rareza de SpecialItem), sacando un boleto del mazo `bag`.
## Si el mazo está vacío, lo arma de nuevo y lo mezcla.
func draw_box(bag: Array, rng: RandomNumberGenerator) -> int:
	if bag.is_empty():
		bag.append_array(new_box_bag(rng))
	return bag.pop_back()


func new_box_bag(rng: RandomNumberGenerator) -> Array[int]:
	var bag: Array[int] = []
	for i: int in mystery_box_odds.size():
		for n: int in roundi(mystery_box_odds[i] * mystery_box_bag_size):
			bag.append(BOX_RARITIES[i])
	# Mezcla con el generador de la partida (la misma semilla, la misma suerte).
	for i: int in range(bag.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: int = bag[i]
		bag[i] = bag[j]
		bag[j] = swap
	return bag


## Una tirada suelta (sin mazo), con las chances de la Mystery Box.
func roll_box(rng: RandomNumberGenerator) -> int:
	return BOX_RARITIES[_roll(mystery_box_odds, rng)]


static func _roll(chances: PackedFloat32Array, rng: RandomNumberGenerator) -> int:
	var roll: float = rng.randf()
	var accumulated: float = 0.0
	for r: int in chances.size():
		accumulated += chances[r]
		if roll < accumulated:
			return r
	return 0
