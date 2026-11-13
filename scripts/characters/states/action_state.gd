extends State
## Haciendo algo (ataque, habilidad): se mueve más lento o como diga la acción.
## La esquiva lo cancela en cualquier momento.


func physics_update(delta: float) -> void:
	var player := owner_body as PlayerCharacter
	if not player.action_step(delta):
		machine.transition_to(&"Move" if player.get_move_input() != Vector2.ZERO else &"Idle")
