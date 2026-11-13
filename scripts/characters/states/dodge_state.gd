extends State
## Esquiva: movimiento rápido en una dirección fija. Los primeros 0,25 s son invulnerables
## (lo pone PlayerCharacter.start_dodge).


func physics_update(delta: float) -> void:
	var player := owner_body as PlayerCharacter
	if not player.dodge_step(delta):
		machine.transition_to(&"Move" if player.slot.input.move != Vector2.ZERO else &"Idle")
