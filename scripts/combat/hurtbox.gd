class_name Hurtbox
extends Node3D
## Zona donde se puede recibir daño: un cilindro de `radius` y `height` sobre el piso.
## Los ataques la encuentran con CombatQuery (círculo, sector o línea).

@export var team: DamageInfo.Team = DamageInfo.Team.ENEMIES
@export var radius: float = 0.5
@export var height: float = 1.8
## Objeto rompible (vasija): los ataques le pegan, pero el apuntado y las IA lo ignoran.
@export var is_prop: bool = false

## Quién recibe el golpe. Tiene que tener receive_hit(info) -> bool. Por defecto, el padre.
var receiver: Node


func _enter_tree() -> void:
	if receiver == null:
		receiver = get_parent()
	add_to_group(group_for(team))


func _exit_tree() -> void:
	remove_from_group(group_for(team))


static func group_for(which: DamageInfo.Team) -> StringName:
	return &"hurtbox_players" if which == DamageInfo.Team.PLAYERS else &"hurtbox_enemies"


func take_hit(info: DamageInfo) -> bool:
	return receiver.receive_hit(info)


func is_targetable() -> bool:
	if receiver != null and receiver.has_method("is_targetable"):
		return receiver.is_targetable()
	return true


func flat_position() -> Vector3:
	var p: Vector3 = global_position
	return Vector3(p.x, 0.0, p.z)
