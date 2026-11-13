extends Node3D
## Objetivo de prueba para los tests de CombatQuery.

var targetable: bool = true
var hits: Array[DamageInfo] = []


func receive_hit(info: DamageInfo) -> bool:
	hits.append(info)
	return true


func is_targetable() -> bool:
	return targetable
