class_name PipoCabin
extends Node3D
## Cabaña del General Pipo (GDD, solo Stage 1): sin Pipo en el equipo, Pipo los echa, pero
## les deja una torreta aliada para la sala siguiente. (Pipo no es jugable en el MVP.)

signal resolved

const WOOD := Color(0.4, 0.27, 0.16)
const UNIFORM := Color(0.38, 0.42, 0.3)
const LINES: Array[String] = [
	"¿Quién anda ahí? ¡Esto es propiedad privada!",
	"Soy el General Pipo. Y no estoy escondido: estoy reposicionado.",
	"¿Adentro? Adentro no hay nadie. Nadie. Ni un Líder Supremo ni nada.",
	"Tomen esta torreta y váyanse. Y no le cuenten a nadie que estoy acá.",
]
const LINE_TIME := 3.2
## Empieza a hablar cuando alguien se acerca a esta distancia.
const TALK_DISTANCE := 8.0

var _speech: Label3D
var _pipo: Node3D
var _talking: bool = false


func _ready() -> void:
	var cabin := Node3D.new()
	cabin.position = Vector3(0, 0, -7)
	add_child(cabin)
	var walls := _box(Vector3(6.0, 2.8, 4.0), Vector3(0, 1.4, 0), cabin)
	walls.material_override = Fx.flat_material(WOOD)
	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(7.0, 1.8, 4.6)
	roof.mesh = prism
	roof.position.y = 3.7
	roof.material_override = Fx.flat_material(Color(0.28, 0.34, 0.2))
	cabin.add_child(roof)
	var door := _box(Vector3(1.1, 2.0, 0.1), Vector3(0, 1.0, 2.02), cabin)
	door.material_override = Fx.flat_material(Color(0.12, 0.08, 0.05))
	var window := _box(Vector3(0.8, 0.6, 0.1), Vector3(1.9, 1.7, 2.02), cabin)
	window.material_override = Fx.flat_material(Color(1.0, 0.85, 0.5), 1.2)
	var body := StaticBody3D.new()
	body.collision_layer = 512
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6.0, 2.8, 4.0)
	shape.shape = box
	shape.position.y = 1.4
	body.add_child(shape)
	cabin.add_child(body)
	# Pipo: militar y tuerto.
	_pipo = Node3D.new()
	_pipo.position = Vector3(-2.2, 0, -3.8)
	add_child(_pipo)
	var pipo_body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.42
	capsule.height = 1.75
	pipo_body.mesh = capsule
	pipo_body.position.y = 0.88
	pipo_body.material_override = Fx.flat_material(UNIFORM)
	_pipo.add_child(pipo_body)
	var patch := _box(Vector3(0.18, 0.14, 0.06), Vector3(0.14, 1.45, 0.4), _pipo)
	patch.material_override = Fx.flat_material(Color(0.05, 0.05, 0.05))
	var cap := _box(Vector3(0.7, 0.14, 0.7), Vector3(0, 1.8, 0), _pipo)
	cap.material_override = Fx.flat_material(UNIFORM.darkened(0.3))
	_speech = Label3D.new()
	_speech.font_size = 48
	_speech.pixel_size = 0.009
	_speech.outline_size = 10
	_speech.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_speech.no_depth_test = true
	_speech.width = 700.0
	_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speech.position = Vector3(0, 2.7, 0)
	_pipo.add_child(_speech)
	_speech.text = "¿Eh?"


func _physics_process(_delta: float) -> void:
	if _talking:
		return
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var player := node as Node3D
		if player != null and player.global_position.distance_to(_pipo.global_position) <= TALK_DISTANCE:
			_talk()
			return


func _talk() -> void:
	if _talking:
		return
	_talking = true
	var tween: Tween = create_tween()
	for line: String in LINES:
		tween.tween_callback(func() -> void: _speech.text = line)
		tween.tween_interval(LINE_TIME)
	tween.tween_callback(_give_turret)


func _give_turret() -> void:
	RunState.turret_pending = true
	_speech.text = "¡Rompan filas!"
	Events.floating_text_requested.emit(_pipo.global_position + Vector3.UP * 3.4,
			"Torreta aliada para la próxima sala", Color(1.0, 0.82, 0.3))
	resolved.emit()


func _box(size: Vector3, at: Vector3, parent: Node3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	parent.add_child(node)
	return node
