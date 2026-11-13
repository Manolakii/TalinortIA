class_name State
extends Node
## Un estado de una StateMachine. Se sobreescriben los métodos que hagan falta.

## El dueño de la máquina (por ejemplo, el PlayerCharacter). Lo asigna la StateMachine.
var owner_body: Node
var machine: StateMachine


func enter(_previous: StringName) -> void:
	pass


func exit() -> void:
	pass


func physics_update(_delta: float) -> void:
	pass
