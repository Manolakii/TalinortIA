extends State
## Quieto: frena y espera input de movimiento.


func physics_update(delta: float) -> void:
	var player := owner_body as PlayerCharacter
	player.apply_movement(Vector2.ZERO, delta)
	if player.get_move_input() != Vector2.ZERO:
		machine.transition_to(&"Move")
