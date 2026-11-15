class_name PipoCabin
extends Node3D
## Cabaña del General Pipo (GDD, solo Stage 1): sin Pipo en el equipo, Pipo los echa, pero
## les deja una torreta aliada para la sala siguiente.
## Easter egg (LORE): si alguien juega con Pipo, el jugador Pipo abre la puerta y adentro está
## el Líder Supremo Talinorteano escondido. Charla un poco y le regala su corona.

signal resolved

const WOOD := Color(0.4, 0.27, 0.16)
const UNIFORM := Color(0.38, 0.42, 0.3)
const LINES: Array[String] = [
	"¿Quién anda ahí? ¡Esto es propiedad privada!",
	"Soy el General Pipo. Y no estoy escondido: estoy reposicionado.",
	"¿Adentro? Adentro no hay nadie. Nadie. Ni un Líder Supremo ni nada.",
	"Tomen esta torreta y váyanse. Y no le cuenten a nadie que estoy acá.",
]
const LEADER_LINES: Array[String] = [
	"¿Pipo? ¿Sos vos? Cerrá, cerrá que entra el frío.",
	"¿Ya terminó la guerra? ...¿No? Bueno, yo de acá no salgo.",
	"Te juro que era un chiste. UNO. Sobre la hermana. Ya sé, ya sé.",
	"Tomá, llevate la corona. Total, acá adentro no la uso para nada.",
	"Es mágica, eh: si te voltean, te levanta una vez. A mí acá nadie me pega.",
]
const GOLD := Color(1.0, 0.82, 0.3)
const LINE_TIME := 3.2
## El jugador Pipo abre la puerta a esta distancia.
const DOOR_DISTANCE := 3.2
## Empieza a hablar cuando alguien se acerca a esta distancia.
const TALK_DISTANCE := 8.0

var _speech: Label3D
var _pipo: Node3D
var _talking: bool = false
## Jugador que juega con Pipo (si hay): activa el easter egg.
var _pipo_player: PlayerCharacter
var _checked_party: bool = false
var _hinted: bool = false
var _door: MeshInstance3D
var _cabin: Node3D
var _leader: Node3D
var _leader_speech: Label3D

func _ready() -> void:
	var cabin := Node3D.new()
	cabin.position = Vector3(0, 0, -7)
	add_child(cabin)
	_cabin = cabin
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
	_door = door
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
	if not _checked_party:
		_checked_party = true
		_pipo_player = _find_pipo_player()
		if _pipo_player != null:
			_pipo.visible = false
	if _talking:
		return
	if _pipo_player != null:
		_easter_egg_tick()
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


func _find_pipo_player() -> PlayerCharacter:
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var player := node as PlayerCharacter
		if player != null and player.data != null and player.data.id == &"pipo":
			return player
	return null


# --- Easter egg: el Líder Supremo escondido ---

func _easter_egg_tick() -> void:
	if not is_instance_valid(_pipo_player):
		_pipo_player = null
		_pipo.visible = true
		return
	var door_at: Vector3 = _door.global_position
	if Vector2(_pipo_player.global_position.x - door_at.x, _pipo_player.global_position.z - door_at.z).length() <= DOOR_DISTANCE:
		open_secret_door()
		return
	# Los demás se acercan y la puerta no se abre: la llave la tiene el General.
	if _hinted:
		return
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var player := node as PlayerCharacter
		if player == null or player == _pipo_player:
			continue
		if Vector2(player.global_position.x - door_at.x, player.global_position.z - door_at.z).length() <= DOOR_DISTANCE:
			_hinted = true
			Events.floating_text_requested.emit(door_at + Vector3.UP * 2.6,
					"Cerrado. La llave la tiene el General...", Color(0.85, 1.0, 0.75))
			return


## El jugador Pipo abre la cabaña (también lo usan los tests).
func open_secret_door() -> void:
	if _talking:
		return
	_talking = true
	_door.visible = false
	_build_leader()
	if _pipo_player != null and _pipo_player.kit != null:
		_pipo_player.kit.say("¡Shh! Nadie tiene que saber que está acá.", Color(0.85, 1.0, 0.75), 1.0)
	var tween: Tween = create_tween()
	tween.tween_interval(1.2)
	for line: String in LEADER_LINES:
		tween.tween_callback(func() -> void: _leader_speech.text = line)
		tween.tween_interval(LINE_TIME)
	tween.tween_callback(give_crown)


## Premio del easter egg: la Corona del Líder Supremo para el jugador Pipo.
func give_crown() -> void:
	if _pipo_player != null and is_instance_valid(_pipo_player):
		var index: int = _pipo_player.slot.index
		if not RunState.has_special(index, &"corona_lider"):
			RunState.add_special(index, &"corona_lider")
			Events.floating_text_requested.emit(_pipo_player.global_position + Vector3.UP * 3.0,
					"¡Corona del Líder Supremo!
Si caés, te levanta una vez", GOLD)
		else:
			# Ya la tenía (de la tienda): se lleva la torreta de siempre.
			RunState.turret_pending = true
			Events.floating_text_requested.emit(_pipo_player.global_position + Vector3.UP * 3.0,
					"Torreta aliada para la próxima sala", GOLD)
	if _leader_speech != null:
		_leader_speech.text = "Y cerrá la puerta al salir."
	Sound.play("chest", -4.0, 0.0)
	resolved.emit()


func _build_leader() -> void:
	# Talinorteano bajito, medio triste, con la corona (placeholder).
	_leader = Node3D.new()
	_leader.position = Vector3(0, 0, 2.5)
	_cabin.add_child(_leader)
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.4
	body.mesh = capsule
	body.position.y = 0.7
	body.material_override = Fx.flat_material(Color(0.55, 0.5, 0.42))
	_leader.add_child(body)
	var crown := MeshInstance3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = 0.26
	ring.bottom_radius = 0.22
	ring.height = 0.22
	crown.mesh = ring
	crown.position.y = 1.5
	crown.material_override = Fx.flat_material(GOLD, 1.5)
	_leader.add_child(crown)
	_leader_speech = Label3D.new()
	_leader_speech.font_size = 48
	_leader_speech.pixel_size = 0.009
	_leader_speech.outline_size = 10
	_leader_speech.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_leader_speech.no_depth_test = true
	_leader_speech.width = 700.0
	_leader_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_leader_speech.modulate = GOLD.lightened(0.4)
	_leader_speech.position = Vector3(0, 2.3, 0)
	_leader_speech.text = "¡¿Quién es?!"
	_leader.add_child(_leader_speech)
	_leader.scale = Vector3(1, 0.1, 1)
	var tween: Tween = _leader.create_tween()
	tween.tween_property(_leader, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
