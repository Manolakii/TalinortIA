class_name PrisonerCage
extends Node3D
## Jaula con un Talinorteano consciente (evento Colonia de presos). Se abre manteniendo
## Interactuar (E / X) cerca. El preso sale corriendo y suelta oro para cada jugador.

signal freed

const BODY_COLOR := Color(0.62, 0.52, 0.4)
const STEEL := Color(0.55, 0.57, 0.6)
const USE_RADIUS := 1.9
const SHOUTS: Array[String] = ["¡Sacame de acá!", "¡Eh, vos! ¡Abrí!", "¡No veo nada! Ah, no, sí veo.",
		"¡La llave la tiene el Agucci!", "¡Talinorthland libre!"]

var open_time: float = 1.5
var is_free: bool = false
var is_lost: bool = false
var _progress: float = 0.0
var _bar: MeshInstance3D
var _prisoner: Node3D
var _bars: Node3D
var _shout: Label3D
var _shout_timer: float = 0.0


func _ready() -> void:
	_prisoner = Node3D.new()
	add_child(_prisoner)
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.5
	body.mesh = capsule
	body.position.y = 0.75
	body.material_override = Fx.flat_material(BODY_COLOR)
	_prisoner.add_child(body)
	_bars = Node3D.new()
	add_child(_bars)
	for i: int in 10:
		var angle: float = TAU * i / 10.0
		var bar := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.04
		cylinder.bottom_radius = 0.04
		cylinder.height = 2.0
		bar.mesh = cylinder
		bar.position = Vector3(cos(angle) * 0.8, 1.0, sin(angle) * 0.8)
		bar.material_override = Fx.flat_material(STEEL)
		_bars.add_child(bar)
	for height: float in [0.05, 2.0]:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.74
		torus.outer_radius = 0.86
		ring.mesh = torus
		ring.position.y = height
		ring.material_override = Fx.flat_material(STEEL)
		_bars.add_child(ring)
	_bar = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.4, 0.12, 0.05)
	_bar.mesh = box
	_bar.position.y = 2.5
	_bar.material_override = Fx.flat_material(Color.WHITE, 1.0)
	_bar.scale.x = 0.0
	_bar.visible = false
	add_child(_bar)
	_shout = Label3D.new()
	_shout.font_size = 52
	_shout.outline_size = 10
	_shout.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_shout.position.y = 2.9
	add_child(_shout)
	_shout_timer = randf_range(0.5, 3.0)


func _physics_process(delta: float) -> void:
	if is_free or is_lost:
		return
	_shout_timer -= delta
	if _shout_timer <= 0.0:
		_shout_timer = randf_range(4.0, 7.0)
		_shout.text = SHOUTS.pick_random()
		_shout.modulate.a = 1.0
		var fade: Tween = _shout.create_tween()
		fade.tween_interval(1.6)
		fade.tween_property(_shout, "modulate:a", 0.0, 0.4)
	var opening: bool = false
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var player := node as PlayerCharacter
		if player == null or player.health.is_dead:
			continue
		var offset: Vector3 = player.global_position - global_position
		if Vector2(offset.x, offset.z).length() <= USE_RADIUS \
				and player.slot.input.is_held(PlayerInput.Action.INTERACT):
			opening = true
	_progress = clampf(_progress + (delta if opening else -delta * 0.5), 0.0, open_time)
	_bar.visible = _progress > 0.0
	_bar.scale.x = maxf(_progress / open_time, 0.01)
	if _progress >= open_time:
		free_prisoner()


func free_prisoner() -> void:
	if is_free or is_lost:
		return
	is_free = true
	_bar.visible = false
	freed.emit()
	_shout.text = "¡Gracias! ¡Viva Talinorthland!"
	_shout.modulate.a = 1.0
	var tween: Tween = create_tween()
	tween.tween_property(_bars, "position:y", -2.2, 0.4)
	tween.tween_property(_prisoner, "position", Vector3(0, 0, 14.0), 2.5)
	tween.tween_callback(_prisoner.queue_free)


## Terminó la pelea sin abrirla: se lo llevaron los Aguccis.
func lose() -> void:
	if is_free or is_lost:
		return
	is_lost = true
	_shout.text = "Se lo llevaron..."
	_shout.modulate = Color(0.75, 0.6, 0.9)
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector3(1, 0.01, 1), 0.8)
	tween.tween_callback(queue_free)
