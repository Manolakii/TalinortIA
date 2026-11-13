class_name EscortCart
extends Combatant
## La carreta de Talinorteanos del evento "Escoltá la carreta" (idea del grupo). Avanza despacio
## hacia la salida solo si hay un jugador cerca empujando; los enemigos la atacan.
## Del lado de los jugadores: los enemigos la eligen como objetivo (y les gusta bastante).

signal arrived
signal destroyed

const WOOD := Color(0.45, 0.3, 0.17)
const PEOPLE := Color(0.62, 0.52, 0.4)

var path_from: Vector3
var path_to: Vector3
var speed: float = 0.45
var push_radius: float = 6.0
## Menos de 1: los enemigos la prefieren antes que a los jugadores a la misma distancia.
var priority: float = 0.7

var _progress: float = 0.0
var _talk_timer: float = 2.0
var _stopped_time: float = 0.0
var _complained: bool = false
var _hit_talk_cooldown: float = 0.0
var _done: bool = false
var _speech: Label3D
var _bar_fill: MeshInstance3D
var _visual: Node3D
var _wheels: Array[Node3D] = []


func setup(from: Vector3, to: Vector3, max_health: float, move_speed: float) -> void:
	path_from = from
	path_to = to
	speed = move_speed
	position = from
	_build()
	setup_combatant(DamageInfo.Team.PLAYERS, max_health, 1.3, 1.8, _visual)
	add_to_group(&"enemy_targets")
	health.died.connect(func(_info: DamageInfo) -> void: _break())


func can_be_targeted_by_enemies() -> bool:
	return is_targetable() and not _done


func target_priority() -> float:
	return priority


## No la empujan ni la aturden: es una carreta.
func _modify_incoming(info: DamageInfo) -> void:
	info.knockback = 0.0
	info.stun = 0.0


func _after_hit(_info: DamageInfo) -> void:
	_update_bar()
	if _hit_talk_cooldown <= 0.0:
		_hit_talk_cooldown = 4.0
		_say(Dialogue.line("carreta_golpe"), 1.8)


func _physics_process(delta: float) -> void:
	if _done or health.is_dead:
		return
	_hit_talk_cooldown -= delta
	_talk_timer -= delta
	var pushing: bool = _someone_near()
	if pushing:
		_stopped_time = 0.0
		_complained = false
		var length: float = path_from.distance_to(path_to)
		_progress = minf(_progress + speed * delta / maxf(length, 0.1), 1.0)
		global_position = path_from.lerp(path_to, _progress)
		for wheel: Node3D in _wheels:
			wheel.rotation.x -= delta * speed * 3.0
		if _progress >= 1.0:
			_done = true
			_say(Dialogue.line("carreta_llega"), 3.0)
			arrived.emit()
			return
	else:
		_stopped_time += delta
		if _stopped_time > 2.0 and not _complained:
			_complained = true
			_say(Dialogue.line("carreta_quieta"), 2.5)
	if _talk_timer <= 0.0:
		_talk_timer = randf_range(5.0, 8.0)
		_say(Dialogue.line("carreta"), 2.6)


func progress() -> float:
	return _progress


func _someone_near() -> bool:
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var player := node as PlayerCharacter
		if player == null or player.health.is_dead:
			continue
		var offset: Vector3 = player.global_position - global_position
		if Vector2(offset.x, offset.z).length() <= push_radius:
			return true
	return false


func _break() -> void:
	_done = true
	_say(Dialogue.line("carreta_rota"), 3.0)
	var tween: Tween = create_tween()
	tween.tween_property(_visual, "rotation:z", 0.5, 0.3)
	tween.tween_property(_visual, "position:y", -0.4, 0.4)
	destroyed.emit()


func _say(text: String, seconds: float) -> void:
	if text == "":
		return
	_speech.text = text
	_speech.modulate.a = 1.0
	var fade: Tween = _speech.create_tween()
	fade.tween_interval(seconds)
	fade.tween_property(_speech, "modulate:a", 0.0, 0.4)


func _update_bar() -> void:
	_bar_fill.scale.x = maxf(health.ratio(), 0.01)
	_bar_fill.position.x = -0.9 * (1.0 - health.ratio())


# --- Placeholder: carreta de madera con tres Talinorteanos arriba ---

func _build() -> void:
	collision_layer = 512
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.8, 1.2, 2.6)
	shape.shape = box
	shape.position.y = 0.6
	add_child(shape)
	_visual = Node3D.new()
	add_child(_visual)
	var bed := _box(Vector3(1.8, 0.4, 2.6), Vector3(0, 0.7, 0), Fx.flat_material(WOOD))
	_visual.add_child(bed)
	for side: float in [-1.0, 1.0]:
		var rail := _box(Vector3(0.1, 0.4, 2.6), Vector3(0.85 * side, 1.05, 0), Fx.flat_material(WOOD.darkened(0.2)))
		_visual.add_child(rail)
		for front: float in [-0.8, 0.8]:
			var wheel := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.42
			cylinder.bottom_radius = 0.42
			cylinder.height = 0.14
			wheel.mesh = cylinder
			wheel.rotation.z = PI * 0.5
			wheel.position = Vector3(0.98 * side, 0.42, front)
			wheel.material_override = Fx.flat_material(WOOD.darkened(0.35))
			_visual.add_child(wheel)
			_wheels.append(wheel)
	for i: int in 3:
		var person := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.28
		capsule.height = 1.0
		person.mesh = capsule
		person.position = Vector3(-0.5 + i * 0.5, 1.4, -0.5 + (i % 2) * 0.7)
		person.material_override = Fx.flat_material(PEOPLE)
		_visual.add_child(person)
	_speech = Label3D.new()
	_speech.font_size = 48
	_speech.pixel_size = 0.009
	_speech.outline_size = 12
	_speech.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_speech.no_depth_test = true
	_speech.width = 700.0
	_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speech.position.y = 3.2
	add_child(_speech)
	var bar_bg := _box(Vector3(1.8, 0.14, 0.05), Vector3(0, 2.5, 0), Fx.flat_material(Color(0.1, 0.1, 0.1)))
	add_child(bar_bg)
	_bar_fill = _box(Vector3(1.8, 0.12, 0.06), Vector3(0, 2.5, 0.01), Fx.flat_material(Color(0.95, 0.95, 0.9), 0.6))
	add_child(_bar_fill)


func _box(size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.material_override = material
	return node
