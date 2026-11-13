extends State
## Caminando: acelera casi al instante hacia donde apunta el stick o WASD.


func physics_update(delta: float) -> void:
	var player := owner_body as PlayerCharacter
	var move: Vector2 = player.slot.input.move
	player.apply_movement(move, delta)
	if move == Vector2.ZERO:
		machine.transition_to(&"Idle")
