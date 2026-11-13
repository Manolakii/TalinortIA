class_name PipoRiddle
extends Node3D
## Acertijo para encontrar la Cabaña del General Pipo (GDD: está escondida y se llega con un
## acertijo simple). Un cartel pregunta qué le sacó el ojo al General, y hay tres tótems con
## respuestas. Se toca uno con Interactuar: la piedra (LORE: un Talinorteano revoleó una
## piedra sin apuntar) abre el camino. Una sola oportunidad.

signal solved
signal failed

const WOOD := Color(0.42, 0.28, 0.16)
const ANSWERS: Array[String] = ["Una piedra", "Una flecha", "Un Gronk"]
const CORRECT := "Una piedra"
const USE_RADIUS := 1.5

var _totems: Array[Node3D] = []
var _answers: Array[String] = []
var _done: bool = false


func setup(rng: RandomNumberGenerator) -> void:
	_answers = ANSWERS.duplicate()
	# Mezcla con la semilla de la sala.
	for i: int in range(_answers.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var temp: String = _answers[i]
		_answers[i] = _answers[j]
		_answers[j] = temp
	var post := _box(Vector3(0.15, 1.6, 0.15), Vector3(0, 0.8, -1.2))
	post.material_override = Fx.flat_material(WOOD)
	var board := _box(Vector3(2.4, 0.9, 0.1), Vector3(0, 1.7, -1.15))
	board.material_override = Fx.flat_material(WOOD.lightened(0.1))
	var question := _label("Bosque Tuerto\n¿Qué le sacó el ojo al General?", 34)
	question.position = Vector3(0, 2.6, -1.0)
	add_child(question)
	for i: int in 3:
		var totem := Node3D.new()
		totem.position = Vector3((i - 1) * 2.2, 0, 0.6)
		add_child(totem)
		var trunk := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.28
		cylinder.bottom_radius = 0.34
		cylinder.height = 1.2
		trunk.mesh = cylinder
		trunk.position.y = 0.6
		trunk.material_override = Fx.flat_material(WOOD.darkened(0.15))
		totem.add_child(trunk)
		var answer := _label(_answers[i], 30)
		answer.position = Vector3(0, 1.6, 0)
		totem.add_child(answer)
		_totems.append(totem)


func _physics_process(_delta: float) -> void:
	if _done:
		return
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var player := node as PlayerCharacter
		if player == null or player.health.is_dead or player.menu_locked:
			continue
		if not player.slot.input.just_pressed(PlayerInput.Action.INTERACT):
			continue
		for i: int in _totems.size():
			var offset: Vector3 = player.global_position - _totems[i].global_position
			if Vector2(offset.x, offset.z).length() <= USE_RADIUS:
				choose(i)
				return


## Elige la respuesta del tótem `index` (también lo usan los tests).
func choose(index: int) -> void:
	if _done:
		return
	_done = true
	var right: bool = _answers[index] == CORRECT
	var text: String = "Se escucha un clic entre los árboles..." if right else "Nada. Un pájaro se ríe de ustedes."
	Events.floating_text_requested.emit(_totems[index].global_position + Vector3.UP * 2.4, text,
			Color(1.0, 0.82, 0.3) if right else Color(0.8, 0.8, 0.85))
	for totem: Node3D in _totems:
		var sink: Tween = totem.create_tween()
		sink.tween_property(totem, "position:y", -1.6, 1.0)
	if right:
		solved.emit()
	else:
		failed.emit()


func correct_index() -> int:
	return _answers.find(CORRECT)


func _box(size: Vector3, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	add_child(node)
	return node


func _label(text: String, size: int) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.outline_size = 10
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	return label
