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
		if upgrade.character != character:
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
