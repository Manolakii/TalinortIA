class_name ChasmTile
extends Node3D
## Piedra del barranco: al pisarla tiembla, se derrumba al rato y vuelve después.

const STONE: Material = preload("res://assets/materials/rock_material.tres")

var size: Vector2 = Vector2(2.6, 3.0)
var crumble_delay: float = 0.9
var respawn_time: float = 4.0

var _state: int = 0  # 0 firme, 1 temblando, 2 caída
var _timer: float = 0.0
var _mesh: MeshInstance3D


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(size.x, 0.4, size.y)
	box.material = STONE
	_mesh.mesh = box
	_mesh.position.y = -0.1
	add_child(_mesh)


func is_solid() -> bool:
	return _state != 2


func contains(point: Vector3) -> bool:
	return absf(point.x - global_position.x) <= size.x * 0.5 \
			and absf(point.z - global_position.z) <= size.y * 0.5


## Alguien la pisó: empieza a temblar (si estaba firme).
func step_on() -> void:
	if _state == 0:
		_state = 1
		_timer = crumble_delay


func _physics_process(delta: float) -> void:
	if _state == 0:
		return
	_timer -= delta
	if _state == 1:
		_mesh.position.x = sin(Time.get_ticks_msec() * 0.06) * 0.06
		if _timer <= 0.0:
			_state = 2
			_timer = respawn_time
			var tween: Tween = create_tween()
			tween.tween_property(_mesh, "position:y", -3.0, 0.4).set_ease(Tween.EASE_IN)
			tween.parallel().tween_property(_mesh, "scale", Vector3.ONE * 0.6, 0.4)
	elif _timer <= 0.0:
		_state = 0
		_mesh.position = Vector3(0, -0.1, 0)
		_mesh.scale = Vector3.ONE * 0.2
		var back: Tween = create_tween()
		back.tween_property(_mesh, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK)
