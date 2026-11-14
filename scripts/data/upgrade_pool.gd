class_name UpgradePool
extends Resource
## Todas las mejoras de personaje. Ofrece 3 al azar de las que el jugador todavía puede tomar.

@export var upgrades: Array[CharacterUpgrade] = []


func get_upgrade(id: StringName) -> CharacterUpgrade:
	for upgrade: CharacterUpgrade in upgrades:
		if upgrade.id == id:
			return upgrade
	return null


## Las que todavía puede tomar este jugador (no llegó al máximo, y para las Sendas,
## el hueco no tiene otra Senda distinta).
func available_for(character: StringName, owned: Array) -> Array[CharacterUpgrade]:
	var result: Array[CharacterUpgrade] = []
	for upgrade: CharacterUpgrade in upgrades:
		if upgrade.character != character or upgrade.shop_only:
			continue
		if owned.count(upgrade.id) >= upgrade.max_stacks:
			continue
		if upgrade.senda_slot != &"" and _slot_taken_by_other(upgrade, owned):
			continue
		result.append(upgrade)
	return result


## Ofrece hasta `count` mejoras distintas, con el generador de la partida.
func offer(character: StringName, owned: Array, rng: RandomNumberGenerator,
		count: int = 3) -> Array[CharacterUpgrade]:
	var pool: Array[CharacterUpgrade] = available_for(character, owned)
	var result: Array[CharacterUpgrade] = []
	while not pool.is_empty() and result.size() < count:
		var index: int = rng.randi_range(0, pool.size() - 1)
		result.append(pool[index])
		pool.remove_at(index)
	return result


func _slot_taken_by_other(upgrade: CharacterUpgrade, owned: Array) -> bool:
	for owned_id: Variant in owned:
		var other: CharacterUpgrade = get_upgrade(owned_id)
		if other != null and other != upgrade and other.senda_body == upgrade.senda_body \
				and other.senda_slot == upgrade.senda_slot:
			return true
	return false


## La mejora de tienda de un personaje que todavía puede comprar (o null). Si tiene variantes
## (exclusive_group), sale una al azar y desaparecen todas cuando compra una.
func shop_upgrade_for(character: StringName, owned: Array, rng: RandomNumberGenerator) -> CharacterUpgrade:
	var options: Array[CharacterUpgrade] = []
	for upgrade: CharacterUpgrade in upgrades:
		if upgrade.character != character or not upgrade.shop_only:
			continue
		if owned.has(upgrade.id) or _group_owned(upgrade, owned):
			continue
		options.append(upgrade)
	return options[rng.randi_range(0, options.size() - 1)] if not options.is_empty() else null


func _group_owned(upgrade: CharacterUpgrade, owned: Array) -> bool:
	if upgrade.exclusive_group == &"":
		return false
	for owned_id: Variant in owned:
		var other: CharacterUpgrade = get_upgrade(owned_id)
		if other != null and other.exclusive_group == upgrade.exclusive_group:
			return true
	return false
