class_name HubInteractable
extends Node3D
## Algo de Birig Bamba con lo que se interactúa (NPC, fuente, nave): muestra el cartel cuando
## un jugador está cerca y avisa cuando aprieta E / X.

signal used(by: PlayerCharacter)

var prompt: String = "Hablar (E / X)"
var radius: float = 2.4
## Si está ocupado (alguien hablando), no se puede usar.
var busy: bool = false
var _prompt_label: Label3D


func setup(prompt_text: String, use_radius: float = 2.4, label_height: float = 2.6) -> void:
	prompt = prompt_text
	radius = use_radius
	_prompt_label = Label3D.new()
	_prompt_label.text = prompt
	_prompt_label.font_size = 52
	_prompt_label.pixel_size = 0.008
	_prompt_label.outline_size = 12
	_prompt_label.modulate = Color(1.0, 0.82, 0.3)
	_prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt_label.no_depth_test = true
	_prompt_label.position.y = label_height
	_prompt_label.visible = false
	add_child(_prompt_label)


func set_prompt(text: String) -> void:
	prompt = text
	if _prompt_label != null:
		_prompt_label.text = text


func _physics_process(_delta: float) -> void:
	if _prompt_label == null:
		return
	var near: PlayerCharacter = _nearest_player()
	_prompt_label.visible = near != null and not busy
	if near != null and not busy and near.slot.input.just_pressed(PlayerInput.Action.INTERACT):
		used.emit(near)


func _nearest_player() -> PlayerCharacter:
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var player := node as PlayerCharacter
		if player == null or player.health.is_dead or player.menu_locked:
			continue
		var offset: Vector3 = player.global_position - global_position
		if Vector2(offset.x, offset.z).length() <= radius:
			return player
	return null
